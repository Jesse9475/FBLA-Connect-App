from flask import Blueprint, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import AUTH_SESSION_SCHEMA, ADVISOR_INVITE_SCHEMA, ADVISOR_VERIFY_SCHEMA
from fbla.services.permissions import require_admin
from fbla.services.supabase_auth import require_auth, verify_supabase_token
from fbla.services.supabase_client import get_supabase
from fbla.services.users import get_or_create_user
from fbla.services.invites import consume_invite_code, create_invite_code
from fbla.api_utils import api_ok, api_error


bp = Blueprint("auth", __name__)


@bp.route("/auth/session", methods=["POST"])
def create_session():
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, AUTH_SESSION_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)
    token = cleaned["token"]

    try:
        decoded = verify_supabase_token(token)
    except Exception:
        return api_error("invalid_token", status=401)

    user = get_or_create_user(
        decoded.get("sub"),
        email=decoded.get("email"),
        display_name=(decoded.get("user_metadata") or {}).get("name")
        or (decoded.get("user_metadata") or {}).get("full_name"),
    )
    session_payload = {
        "user": user,
        "claims": decoded,
        # Echo the Supabase access token so the mobile app can store and reuse it.
        "token": token,
    }
    return api_ok(data=session_payload, status=200)


@bp.route("/advisor/invite", methods=["POST"])
@require_auth
@require_admin
def advisor_invite():
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, ADVISOR_INVITE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    expires_in_days = cleaned.get("expires_in_days", 7)
    invite = create_invite_code(expires_in_days=expires_in_days)
    return api_ok(data={"invite": invite}, status=201)


@bp.route("/advisor/verify", methods=["POST"])
@require_auth
def advisor_verify():
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, ADVISOR_VERIFY_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    supabase = get_supabase()
    user_id = (g.get("auth") or {}).get("user", {}).get("id")
    if not user_id:
        return api_error("invalid_user", status=400)
    result = consume_invite_code(cleaned["code"], user_id)
    if not result.get("success"):
        return api_error(result.get("error", "invalid_code"), status=400)

    supabase.table("users").update({"role": "advisor"}).eq("id", result["user_id"]).execute()
    return api_ok(data={"status": "advisor_verified"}, status=200)
