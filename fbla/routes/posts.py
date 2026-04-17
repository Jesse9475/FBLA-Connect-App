from flask import Blueprint, g, request

from fbla.extensions import limiter
from fbla.schemas.common import validate_payload, is_valid_uuid
from fbla.schemas.payloads import COMMENT_SCHEMA, POST_CREATE_SCHEMA, POST_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("posts", __name__)


def _auth_user():
    return (g.get("auth") or {}).get("user") or {}


def _visible_posts_query(supabase, auth_user):
    """
    Build a visibility-scoped query for the posts table.

    All posts are org-scoped (no public posts). Visibility rules:
    - Admins see everything.
    - Chapter members/advisors see posts from their own chapter.
    - District advisors additionally see district-wide posts (chapter_id IS NULL).
    - National posts (both NULL) are only visible to admins.
    - Users always see their own posts.
    """
    user_id     = auth_user.get("id")
    role        = auth_user.get("role", "member")
    chapter_id  = auth_user.get("chapter_id")
    district_id = auth_user.get("district_id")
    is_admin    = role == "admin"

    if is_admin:
        return supabase.table("posts").select("*")

    filters = []
    if user_id and is_valid_uuid(user_id):
        # Always see your own posts
        filters.append(f"user_id.eq.{user_id}")
    if chapter_id and is_valid_uuid(chapter_id):
        # Posts scoped to this exact chapter
        filters.append(f"chapter_id.eq.{chapter_id}")
    if district_id and is_valid_uuid(district_id):
        # District-wide posts (no chapter restriction) for district advisors
        filters.append(
            f"and(district_id.eq.{district_id},chapter_id.is.null)"
        )

    if not filters:
        # No chapter/district assigned — return nothing except own posts
        if user_id and is_valid_uuid(user_id):
            return supabase.table("posts").select("*").eq("user_id", user_id)
        return supabase.table("posts").select("*").eq("id", "00000000-0000-0000-0000-000000000000")

    return supabase.table("posts").select("*").or_(",".join(filters))


@bp.route("/posts", methods=["GET", "POST"])
@limiter.limit("120 per minute", key_func=lambda: None)
@require_auth
def posts_collection():
    supabase  = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")

    if request.method == "GET":
        query  = _visible_posts_query(supabase, auth_user)
        result = supabase_retry(lambda: query.order("created_at", desc=True).execute())
        return api_ok(data={"posts": result.data or []})

    # POST — create a new post
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, POST_CREATE_SCHEMA)
    if not ok:
        from flask import current_app
        current_app.logger.warning(
            "[posts.POST] invalid_request user=%s payload_keys=%s errors=%s",
            user_id, list(payload.keys()), cleaned,
        )
        return api_error("invalid_request", status=400, data=cleaned)

    role = auth_user.get("role", "member")
    from flask import current_app
    current_app.logger.info(
        "[posts.POST] user=%s role=%s chapter_id=%s district_id=%s",
        user_id, role, auth_user.get("chapter_id"), auth_user.get("district_id"),
    )

    # All posts are org-scoped; no public posting.
    cleaned["visibility"] = "members"
    cleaned["user_id"] = user_id

    if role == "admin":
        # Admins post nationally — no chapter/district restriction
        cleaned.setdefault("chapter_id", None)
        cleaned.setdefault("district_id", None)
    else:
        # Everyone else (members, advisors) scopes to their own chapter/district
        cleaned["chapter_id"]  = auth_user.get("chapter_id")
        cleaned["district_id"] = auth_user.get("district_id")

    result = supabase_retry(lambda: supabase.table("posts").insert(cleaned).execute())
    return api_ok(data={"post": result.data[0] if result.data else cleaned}, status=201)


@bp.route("/posts/<post_id>", methods=["GET", "PATCH", "DELETE"])
@require_auth
def posts_detail(post_id):
    supabase  = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")
    is_admin  = auth_user.get("role") == "admin"

    if request.method == "GET":
        result = supabase_retry(lambda: supabase.table("posts").select("*").eq("id", post_id).limit(1).execute())
        post   = result.data[0] if result.data else None
        if not post:
            return api_ok(data={"post": None})
        if (not is_admin
                and post.get("visibility") not in ("public", "members")
                and post.get("user_id") != user_id):
            return api_error("forbidden", status=403)
        return api_ok(data={"post": post})

    if request.method == "DELETE":
        if not is_admin:
            owned = (supabase.table("posts").select("id")
                     .eq("id", post_id).eq("user_id", user_id).limit(1).execute())
            if not owned.data:
                return api_error("forbidden", status=403)
        supabase.table("posts").delete().eq("id", post_id).execute()
        return api_ok(data={"deleted": True})

    # PATCH
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, POST_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)
    if not is_admin:
        owned = (supabase.table("posts").select("id")
                 .eq("id", post_id).eq("user_id", user_id).limit(1).execute())
        if not owned.data:
            return api_error("forbidden", status=403)
    result = supabase_retry(lambda: supabase.table("posts").update(cleaned).eq("id", post_id).execute())
    return api_ok(data={"post": result.data[0] if result.data else cleaned})


@bp.route("/posts/<post_id>/like", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def posts_like(post_id):
    supabase  = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")
    is_admin  = auth_user.get("role") == "admin"

    post = supabase_retry(lambda: supabase.table("posts").select("user_id,visibility").eq("id", post_id).limit(1).execute())
    if not post.data:
        return api_error("not_found", status=404)
    p = post.data[0]
    if (not is_admin
            and p.get("visibility") not in ("public", "members")
            and p.get("user_id") != user_id):
        return api_error("forbidden", status=403)
    payload = {"post_id": post_id, "user_id": user_id}
    result = supabase.table("post_likes").insert(payload).execute()
    return api_ok(data={"like": result.data[0] if result.data else payload}, status=201)


@bp.route("/posts/<post_id>/comment", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def posts_comment(post_id):
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, COMMENT_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    supabase  = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")
    is_admin  = auth_user.get("role") == "admin"

    post = supabase_retry(lambda: supabase.table("posts").select("user_id,visibility").eq("id", post_id).limit(1).execute())
    if not post.data:
        return api_error("not_found", status=404)
    p = post.data[0]
    if (not is_admin
            and p.get("visibility") not in ("public", "members")
            and p.get("user_id") != user_id):
        return api_error("forbidden", status=403)

    cleaned.update({"post_id": post_id, "user_id": user_id})
    result = supabase.table("comments").insert(cleaned).execute()
    return api_ok(data={"comment": result.data[0] if result.data else cleaned}, status=201)
