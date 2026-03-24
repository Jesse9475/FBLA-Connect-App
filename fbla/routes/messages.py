from flask import Blueprint, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import MESSAGE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase
from fbla.api_utils import api_ok, api_error


bp = Blueprint("messages", __name__)


@bp.route("/threads", methods=["GET", "POST"])
@require_auth
def threads_collection():
    supabase = get_supabase()
    if request.method == "GET":
        auth_user = (g.get("auth") or {}).get("user") or {}
        user_id = auth_user.get("id")
        is_admin = auth_user.get("role") == "admin"
        if is_admin:
            result = supabase.table("threads").select("*").order("created_at", desc=True).execute()
            return api_ok(data={"threads": result.data})
        memberships = (
            supabase.table("thread_members")
            .select("thread_id")
            .eq("user_id", user_id)
            .execute()
        )
        thread_ids = [item["thread_id"] for item in memberships.data] if memberships.data else []
        if not thread_ids:
            return api_ok(data={"threads": []})
        result = (
            supabase.table("threads")
            .select("*")
            .in_("id", thread_ids)
            .order("created_at", desc=True)
            .execute()
        )
        return api_ok(data={"threads": result.data})

    result = supabase.table("threads").insert({}).execute()
    thread = result.data[0] if result.data else {}
    user_id = (g.get("auth") or {}).get("user", {}).get("id")
    if thread.get("id"):
        supabase.table("thread_members").insert({"thread_id": thread["id"], "user_id": user_id}).execute()
    return api_ok(data={"thread": thread}, status=201)


@bp.route("/threads/<thread_id>/messages", methods=["GET", "POST"])
@require_auth
def thread_messages(thread_id):
    supabase = get_supabase()
    if request.method == "GET":
        auth_user = (g.get("auth") or {}).get("user") or {}
        user_id = auth_user.get("id")
        is_admin = auth_user.get("role") == "admin"
        if not is_admin:
            member = (
                supabase.table("thread_members")
                .select("thread_id")
                .eq("thread_id", thread_id)
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
            if not member.data:
                return api_error("forbidden", status=403)
        result = (
            supabase.table("messages")
            .select("*")
            .eq("thread_id", thread_id)
            .order("created_at", desc=False)
            .execute()
        )
        return api_ok(data={"messages": result.data})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, MESSAGE_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"
    if not is_admin:
        member = (
            supabase.table("thread_members")
            .select("thread_id")
            .eq("thread_id", thread_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not member.data:
            return api_error("forbidden", status=403)
    cleaned.update({"thread_id": thread_id, "user_id": user_id})
    result = supabase.table("messages").insert(cleaned).execute()
    return api_ok(data={"message": result.data[0] if result.data else cleaned}, status=201)
