from flask import Blueprint, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import COMMENT_SCHEMA, POST_CREATE_SCHEMA, POST_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase
from fbla.api_utils import api_ok, api_error


bp = Blueprint("posts", __name__)


@bp.route("/posts", methods=["GET", "POST"])
@require_auth
def posts_collection():
    supabase = get_supabase()
    if request.method == "GET":
        auth_user = (g.get("auth") or {}).get("user") or {}
        user_id = auth_user.get("id")
        is_admin = auth_user.get("role") == "admin"
        if is_admin:
            query = supabase.table("posts").select("*")
        else:
            query = supabase.table("posts").select("*").or_(
                f"visibility.eq.public,visibility.eq.members,user_id.eq.{user_id}"
            )
        result = query.order("created_at", desc=True).execute()
        return api_ok(data={"posts": result.data})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, POST_CREATE_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    user_id = (g.get("auth") or {}).get("user", {}).get("id")
    if "visibility" not in cleaned:
        cleaned["visibility"] = "public"
    cleaned["user_id"] = user_id
    result = supabase.table("posts").insert(cleaned).execute()
    return api_ok(data={"post": result.data[0] if result.data else cleaned}, status=201)


@bp.route("/posts/<post_id>", methods=["GET", "PATCH", "DELETE"])
@require_auth
def posts_detail(post_id):
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"

    if request.method == "GET":
        result = supabase.table("posts").select("*").eq("id", post_id).limit(1).execute()
        post = result.data[0] if result.data else None
        if not post:
            return api_ok(data={"post": None}, status=200)
        if (
            not is_admin
            and post.get("visibility") not in ("public", "members")
            and post.get("user_id") != user_id
        ):
            return api_error("forbidden", status=403)
        return api_ok(data={"post": post})

    if request.method == "DELETE":
        if not is_admin:
            owned = (
                supabase.table("posts")
                .select("id")
                .eq("id", post_id)
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
            if not owned.data:
                return api_error("forbidden", status=403)
        supabase.table("posts").delete().eq("id", post_id).execute()
        return api_ok(data={"deleted": True}, status=200)

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, POST_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)
    if not is_admin:
        owned = (
            supabase.table("posts")
            .select("id")
            .eq("id", post_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not owned.data:
            return api_error("forbidden", status=403)
    result = supabase.table("posts").update(cleaned).eq("id", post_id).execute()
    return api_ok(data={"post": result.data[0] if result.data else cleaned}, status=200)


@bp.route("/posts/<post_id>/like", methods=["POST"])
@require_auth
def posts_like(post_id):
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"
    post = supabase.table("posts").select("user_id,visibility").eq("id", post_id).limit(1).execute()
    if not post.data:
        return api_error("not_found", status=404)
    if (
        not is_admin
        and post.data[0].get("visibility") not in ("public", "members")
        and post.data[0].get("user_id") != user_id
    ):
        return api_error("forbidden", status=403)
    payload = {"post_id": post_id, "user_id": user_id}
    result = supabase.table("post_likes").insert(payload).execute()
    return api_ok(data={"like": result.data[0] if result.data else payload}, status=201)


@bp.route("/posts/<post_id>/comment", methods=["POST"])
@require_auth
def posts_comment(post_id):
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, COMMENT_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"
    post = supabase.table("posts").select("user_id,visibility").eq("id", post_id).limit(1).execute()
    if not post.data:
        return api_error("not_found", status=404)
    if (
        not is_admin
        and post.data[0].get("visibility") not in ("public", "members")
        and post.data[0].get("user_id") != user_id
    ):
        return api_error("forbidden", status=403)
    cleaned.update({"post_id": post_id, "user_id": user_id})
    result = supabase.table("comments").insert(cleaned).execute()
    return api_ok(data={"comment": result.data[0] if result.data else cleaned}, status=201)
