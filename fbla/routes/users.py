from flask import Blueprint, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import PROFILE_SCHEMA, USER_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase


bp = Blueprint("users", __name__)


def _can_access_user(user_id):
    auth_user = (g.get("auth") or {}).get("user") or {}
    if auth_user.get("role") == "admin":
        return True
    return str(auth_user.get("id")) == str(user_id)


@bp.route("/users/<user_id>", methods=["GET", "PATCH"])
@require_auth
def users_detail(user_id):
    if not _can_access_user(user_id):
        return jsonify({"error": "forbidden"}), 403

    supabase = get_supabase()
    if request.method == "GET":
        result = supabase.table("users").select("*").eq("id", user_id).limit(1).execute()
        return jsonify({"user": result.data[0] if result.data else None})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, USER_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return jsonify(cleaned), 400

    result = supabase.table("users").update(cleaned).eq("id", user_id).execute()
    return jsonify({"user": result.data[0] if result.data else cleaned})


@bp.route("/profiles/<user_id>", methods=["GET", "PATCH"])
@require_auth
def profiles_detail(user_id):
    if not _can_access_user(user_id):
        return jsonify({"error": "forbidden"}), 403

    supabase = get_supabase()
    if request.method == "GET":
        result = supabase.table("profiles").select("*").eq("user_id", user_id).limit(1).execute()
        return jsonify({"profile": result.data[0] if result.data else None})

    payload = request.get_json(silent=True) or {}
    existing = supabase.table("profiles").select("*").eq("user_id", user_id).limit(1).execute()
    ok, cleaned = validate_payload(payload, PROFILE_SCHEMA, allow_partial=bool(existing.data))
    if not ok:
        return jsonify(cleaned), 400
    if existing.data:
        result = supabase.table("profiles").update(cleaned).eq("user_id", user_id).execute()
    else:
        result = supabase.table("profiles").insert({"user_id": user_id, **cleaned}).execute()

    return jsonify({"profile": result.data[0] if result.data else cleaned})
