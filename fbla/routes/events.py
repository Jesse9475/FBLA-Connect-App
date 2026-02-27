from flask import Blueprint, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import EVENT_CREATE_SCHEMA, EVENT_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase


bp = Blueprint("events", __name__)


@bp.route("/events", methods=["GET", "POST"])
@require_auth
def events_collection():
    supabase = get_supabase()
    if request.method == "GET":
        auth_user = (g.get("auth") or {}).get("user") or {}
        user_id = auth_user.get("id")
        is_admin = auth_user.get("role") == "admin"
        if is_admin:
            query = supabase.table("events").select("*")
        else:
            query = supabase.table("events").select("*").or_(
                f"visibility.eq.public,visibility.eq.members,created_by.eq.{user_id}"
            )
        result = query.order("start_at", desc=True).execute()
        return jsonify({"events": result.data})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, EVENT_CREATE_SCHEMA)
    if not ok:
        return jsonify(cleaned), 400

    user_id = (g.get("auth") or {}).get("user", {}).get("id")
    if "visibility" not in cleaned:
        cleaned["visibility"] = "public"
    cleaned["created_by"] = user_id
    result = supabase.table("events").insert(cleaned).execute()
    return jsonify({"event": result.data[0] if result.data else cleaned}), 201


@bp.route("/events/<event_id>", methods=["GET", "PATCH", "DELETE"])
@require_auth
def events_detail(event_id):
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"

    if request.method == "GET":
        result = supabase.table("events").select("*").eq("id", event_id).limit(1).execute()
        event = result.data[0] if result.data else None
        if not event:
            return jsonify({"event": None})
        if (
            not is_admin
            and event.get("visibility") not in ("public", "members")
            and event.get("created_by") != user_id
        ):
            return jsonify({"error": "forbidden"}), 403
        return jsonify({"event": event})

    if request.method == "DELETE":
        if not is_admin:
            owned = (
                supabase.table("events")
                .select("id")
                .eq("id", event_id)
                .eq("created_by", user_id)
                .limit(1)
                .execute()
            )
            if not owned.data:
                return jsonify({"error": "forbidden"}), 403
        supabase.table("events").delete().eq("id", event_id).execute()
        return jsonify({"deleted": True})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, EVENT_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return jsonify(cleaned), 400
    if not is_admin:
        owned = (
            supabase.table("events")
            .select("id")
            .eq("id", event_id)
            .eq("created_by", user_id)
            .limit(1)
            .execute()
        )
        if not owned.data:
            return jsonify({"error": "forbidden"}), 403
    result = supabase.table("events").update(cleaned).eq("id", event_id).execute()
    return jsonify({"event": result.data[0] if result.data else cleaned})
