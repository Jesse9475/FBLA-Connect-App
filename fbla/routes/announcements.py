from flask import Blueprint, g, jsonify, request

from fbla.extensions import limiter
from fbla.schemas.common import validate_payload, is_valid_uuid
from fbla.schemas.payloads import ANNOUNCEMENT_CREATE_SCHEMA, ANNOUNCEMENT_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("announcements", __name__)


def _is_advisor_or_admin(user):
    return user.get("role") in ("advisor", "admin")


def _validate_scope(payload):
    scope = payload.get("scope")
    if scope == "district" and not payload.get("district_id"):
        return False, {"error": "missing_district_id"}
    if scope == "chapter" and not payload.get("chapter_id"):
        return False, {"error": "missing_chapter_id"}
    if scope == "national":
        payload["district_id"] = None
        payload["chapter_id"] = None
    return True, payload


@bp.route("/announcements", methods=["GET", "POST"])
@limiter.limit("120 per minute")
@require_auth
def announcements_collection():
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"

    if request.method == "GET":
        if is_admin:
            result = supabase_retry(lambda: supabase.table("announcements").select("*").order("created_at", desc=True).execute())
            return api_ok(data={"announcements": result.data or []})

        user = supabase_retry(lambda: supabase.table("users").select("district_id,chapter_id").eq("id", user_id).limit(1).execute())
        user_row = user.data[0] if user.data else {}
        district_id = user_row.get("district_id")
        chapter_id = user_row.get("chapter_id")

        filters = ["scope.eq.national"]
        if district_id and is_valid_uuid(district_id):
            filters.append(f"and(scope.eq.district,district_id.eq.{district_id})")
        if chapter_id and is_valid_uuid(chapter_id):
            filters.append(f"and(scope.eq.chapter,chapter_id.eq.{chapter_id})")
        query = supabase.table("announcements").select("*").or_(",".join(filters))
        result = supabase_retry(lambda: query.order("created_at", desc=True).execute())
        return api_ok(data={"announcements": result.data or []})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, ANNOUNCEMENT_CREATE_SCHEMA)
    from flask import current_app
    current_app.logger.info(
        "[announcements.POST] user=%s role=%s chapter_id=%s district_id=%s payload_keys=%s ok=%s",
        user_id, auth_user.get("role"), auth_user.get("chapter_id"),
        auth_user.get("district_id"), list(payload.keys()), ok,
    )
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    if not _is_advisor_or_admin(auth_user):
        return api_error("forbidden", status=403)

    role = auth_user.get("role", "member")
    if role == "advisor":
        # Advisors always post to their own chapter — ignore any client-supplied scope.
        cleaned["scope"]       = "chapter"
        cleaned["chapter_id"]  = auth_user.get("chapter_id")
        cleaned["district_id"] = auth_user.get("district_id")
    else:
        # Admins may specify scope; default to national if omitted.
        if "scope" not in cleaned:
            cleaned["scope"] = "national"
        ok, cleaned = _validate_scope(cleaned)
        if not ok:
            return api_error(cleaned.get("error", "invalid_scope"), status=400, data=cleaned)

    cleaned["created_by"] = user_id
    result = supabase_retry(lambda: supabase.table("announcements").insert(cleaned).execute())
    return api_ok(data={"announcement": result.data[0] if result.data else cleaned}, status=201)


@bp.route("/announcements/<announcement_id>", methods=["PATCH", "DELETE"])
@limiter.limit("30 per minute; 10 per minute")
@require_auth
def announcements_detail(announcement_id):
    supabase = get_supabase()
    auth_user = (g.get("auth") or {}).get("user") or {}
    user_id = auth_user.get("id")
    is_admin = auth_user.get("role") == "admin"

    if request.method == "DELETE":
        if not is_admin:
            owned = (
                supabase.table("announcements")
                .select("id")
                .eq("id", announcement_id)
                .eq("created_by", user_id)
                .limit(1)
                .execute()
            )
            if not owned.data:
                return api_error("forbidden", status=403)
        supabase.table("announcements").delete().eq("id", announcement_id).execute()
        return api_ok(data={"deleted": True}, status=200)

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, ANNOUNCEMENT_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    if not is_admin:
        owned = (
            supabase.table("announcements")
            .select("id")
            .eq("id", announcement_id)
            .eq("created_by", user_id)
            .limit(1)
            .execute()
        )
        if not owned.data:
            return api_error("forbidden", status=403)

    ok, cleaned = _validate_scope(cleaned)
    if not ok:
        return api_error(cleaned.get("error", "invalid_scope"), status=400, data=cleaned)

    result = supabase_retry(lambda: supabase.table("announcements").update(cleaned).eq("id", announcement_id).execute())
    return api_ok(data={"announcement": result.data[0] if result.data else cleaned}, status=200)
