from flask import Blueprint, g, jsonify, request

from fbla.extensions import limiter
from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import HUB_CREATE_SCHEMA, HUB_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("hub", __name__)


@bp.route("/hub", methods=["GET", "POST"])
@limiter.limit("120 per minute")
@require_auth
def hub_collection():
    supabase = get_supabase()
    if request.method == "GET":
        auth_user = (g.get("auth") or {}).get("user") or {}
        user_id = auth_user.get("id")
        is_admin = auth_user.get("role") == "admin"
        if is_admin:
            query = supabase.table("hub_items").select("*")
        else:
            query = supabase.table("hub_items").select("*").or_(
                f"visibility.eq.public,visibility.eq.members,created_by.eq.{user_id}"
            )
        result = supabase_retry(lambda: query.order("created_at", desc=True).execute())
        return api_ok(data={"hub_items": result.data or []})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, HUB_CREATE_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    if "visibility" not in cleaned:
        cleaned["visibility"] = "public"
    cleaned["created_by"] = (g.get("auth") or {}).get("user", {}).get("id")
    result = supabase_retry(lambda: supabase.table("hub_items").insert(cleaned).execute())
    return api_ok(data={"hub_item": result.data[0] if result.data else cleaned}, status=201)


@bp.route("/hub/<item_id>", methods=["GET", "PATCH", "DELETE"])
@limiter.limit("60 per minute; 30 per minute; 10 per minute")
@require_auth
def hub_detail(item_id):
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"

    if request.method == "GET":
        result = supabase_retry(lambda: supabase.table("hub_items").select("*").eq("id", item_id).limit(1).execute())
        item = result.data[0] if result.data else None
        if not item:
            return api_ok(data={"hub_item": None}, status=200)
        if (
            not is_admin
            and item.get("visibility") not in ("public", "members")
            and item.get("created_by") != user_id
        ):
            return api_error("forbidden", status=403)
        return api_ok(data={"hub_item": item})

    if request.method == "DELETE":
        if not is_admin:
            owned = (
                supabase.table("hub_items")
                .select("id")
                .eq("id", item_id)
                .eq("created_by", user_id)
                .limit(1)
                .execute()
            )
            if not owned.data:
                return api_error("forbidden", status=403)
        supabase.table("hub_items").delete().eq("id", item_id).execute()
        return api_ok(data={"deleted": True}, status=200)

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, HUB_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)
    if not is_admin:
        owned = (
            supabase.table("hub_items")
            .select("id")
            .eq("id", item_id)
            .eq("created_by", user_id)
            .limit(1)
            .execute()
        )
        if not owned.data:
            return api_error("forbidden", status=403)
    result = supabase_retry(lambda: supabase.table("hub_items").update(cleaned).eq("id", item_id).execute())
    return api_ok(data={"hub_item": result.data[0] if result.data else cleaned}, status=200)
