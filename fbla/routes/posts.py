from flask import Blueprint, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import COMMENT_SCHEMA, POST_CREATE_SCHEMA, POST_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase


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
        return jsonify({"posts": result.data})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, POST_CREATE_SCHEMA)
    if not ok:
        return jsonify(cleaned), 400

    user_id = (g.get("auth") or {}).get("user", {}).get("id")
    if "visibility" not in cleaned:
        cleaned["visibility"] = "public"
    cleaned["user_id"] = user_id
    result = supabase.table("posts").insert(cleaned).execute()
    return jsonify({"post": result.data[0] if result.data else cleaned}), 201


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
            return jsonify({"post": None})
        if (
            not is_admin
            and post.get("visibility") not in ("public", "members")
            and post.get("user_id") != user_id
        ):
            return jsonify({"error": "forbidden"}), 403
        return jsonify({"post": post})

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
                return jsonify({"error": "forbidden"}), 403
        supabase.table("posts").delete().eq("id", post_id).execute()
        return jsonify({"deleted": True})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, POST_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return jsonify(cleaned), 400
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
            return jsonify({"error": "forbidden"}), 403
    result = supabase.table("posts").update(cleaned).eq("id", post_id).execute()
    return jsonify({"post": result.data[0] if result.data else cleaned})


@bp.route("/posts/<post_id>/like", methods=["POST"])
@require_auth
def posts_like(post_id):
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"
    post = supabase.table("posts").select("user_id,visibility").eq("id", post_id).limit(1).execute()
    if not post.data:
        return jsonify({"error": "not_found"}), 404
    if (
        not is_admin
        and post.data[0].get("visibility") not in ("public", "members")
        and post.data[0].get("user_id") != user_id
    ):
        return jsonify({"error": "forbidden"}), 403
    payload = {"post_id": post_id, "user_id": user_id}
    result = supabase.table("post_likes").insert(payload).execute()
    return jsonify({"like": result.data[0] if result.data else payload}), 201


@bp.route("/posts/<post_id>/comment", methods=["POST"])
@require_auth
def posts_comment(post_id):
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, COMMENT_SCHEMA)
    if not ok:
        return jsonify(cleaned), 400

    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"
    post = supabase.table("posts").select("user_id,visibility").eq("id", post_id).limit(1).execute()
    if not post.data:
        return jsonify({"error": "not_found"}), 404
    if (
        not is_admin
        and post.data[0].get("visibility") not in ("public", "members")
        and post.data[0].get("user_id") != user_id
    ):
        return jsonify({"error": "forbidden"}), 403
    cleaned.update({"post_id": post_id, "user_id": user_id})
    result = supabase.table("comments").insert(cleaned).execute()
    return jsonify({"comment": result.data[0] if result.data else cleaned}), 201
