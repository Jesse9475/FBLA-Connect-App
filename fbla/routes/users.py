from flask import Blueprint, g, jsonify, request

from fbla.extensions import limiter
from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import PROFILE_SCHEMA, USER_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("users", __name__)


@bp.route("/users", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def users_list():
    """Return a list of all users (id + display_name + role) for DM picker.

    Paginated to prevent loading the entire users table in one request.
    Defaults to 50 results; clamps to a hard ceiling of 200 to bound
    response size and DB load.
    """
    try:
        limit = int(request.args.get("limit", 50))
    except (TypeError, ValueError):
        limit = 50
    try:
        offset = int(request.args.get("offset", 0))
    except (TypeError, ValueError):
        offset = 0
    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    supabase = get_supabase()
    query = (
        supabase.table("users")
        .select("id, display_name, role, chapter_id")
        .order("display_name")
        .range(offset, offset + limit - 1)
    )

    # Optional case-insensitive search on display_name to make the DM
    # picker scale beyond the first page once the user starts typing.
    search = (request.args.get("q") or "").strip()
    if search:
        # Escape PostgREST wildcard chars in the user-supplied query
        # so they're treated literally (not as user-controlled patterns).
        safe = search.replace("%", r"\%").replace("_", r"\_")
        query = query.ilike("display_name", f"%{safe}%")

    result = supabase_retry(lambda: query.execute())
    return api_ok(data={"users": result.data or [], "limit": limit, "offset": offset})


def _can_access_user(user_id):
    auth_user = (g.get("auth") or {}).get("user") or {}
    if auth_user.get("role") == "admin":
        return True
    return str(auth_user.get("id")) == str(user_id)


@bp.route("/users/<user_id>", methods=["GET", "PATCH"])
@limiter.limit("60 per minute; 30 per minute")
@require_auth
def users_detail(user_id):
    if not _can_access_user(user_id):
        return api_error("forbidden", status=403)

    supabase = get_supabase()
    if request.method == "GET":
        result = supabase_retry(lambda: supabase.table("users").select("*").eq("id", user_id).limit(1).execute())
        return api_ok(data={"user": result.data[0] if result.data else None})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, USER_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    # Defense-in-depth: even if the schema accidentally allows it, never
    # let a non-admin caller mutate role-bearing fields. Privilege
    # escalation via PATCH /users would let any logged-in user promote
    # themselves to admin or advisor.
    #
    # Note: chapter_id and district_id are NOT privileged here because a
    # member must be able to set their own chapter during signup. We
    # already restricted the route to self-or-admin via _can_access_user,
    # so a member can only pick their own chapter — not someone else's.
    auth_user = (g.get("auth") or {}).get("user") or {}
    is_admin = auth_user.get("role") == "admin"
    PRIVILEGED_FIELDS = {"role", "is_advisor", "is_admin"}
    if not is_admin:
        leaked = PRIVILEGED_FIELDS.intersection(cleaned.keys())
        if leaked:
            return api_error(
                "forbidden_field",
                status=403,
                data={"fields": sorted(leaked)},
            )

    if not cleaned:
        # Nothing to update — short-circuit instead of issuing an empty
        # UPDATE that would otherwise be a no-op round trip.
        result = supabase_retry(lambda: supabase.table("users").select("*").eq("id", user_id).limit(1).execute())
        return api_ok(data={"user": result.data[0] if result.data else None}, status=200)

    result = supabase_retry(lambda: supabase.table("users").update(cleaned).eq("id", user_id).execute())
    return api_ok(data={"user": result.data[0] if result.data else cleaned}, status=200)


@bp.route("/profiles/<user_id>", methods=["GET", "PATCH"])
@limiter.limit("60 per minute; 30 per minute")
@require_auth
def profiles_detail(user_id):
    if not _can_access_user(user_id):
        return api_error("forbidden", status=403)

    supabase = get_supabase()
    if request.method == "GET":
        result = supabase_retry(lambda: supabase.table("profiles").select("*").eq("user_id", user_id).limit(1).execute())
        return api_ok(data={"profile": result.data[0] if result.data else None})

    payload = request.get_json(silent=True) or {}
    existing = supabase_retry(lambda: supabase.table("profiles").select("*").eq("user_id", user_id).limit(1).execute())
    ok, cleaned = validate_payload(payload, PROFILE_SCHEMA, allow_partial=bool(existing.data))
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)
    if existing.data:
        result = supabase_retry(lambda: supabase.table("profiles").update(cleaned).eq("user_id", user_id).execute())
    else:
        result = supabase_retry(lambda: supabase.table("profiles").insert({"user_id": user_id, **cleaned}).execute())

    return api_ok(data={"profile": result.data[0] if result.data else cleaned}, status=200)
