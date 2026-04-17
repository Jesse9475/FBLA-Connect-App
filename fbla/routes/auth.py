from flask import Blueprint, current_app, g, jsonify, request

from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import AUTH_SESSION_SCHEMA, ADVISOR_INVITE_SCHEMA, ADVISOR_VERIFY_SCHEMA
from fbla.services.permissions import require_admin
from fbla.services.supabase_auth import require_auth, verify_supabase_token
from fbla.services.email_service import send_otp_email
from fbla.services.supabase_client import get_supabase, confirm_supabase_email
from fbla.services.users import get_or_create_user
from fbla.services.invites import consume_invite_code, create_invite_code
from fbla.api_utils import api_ok, api_error
from fbla.extensions import limiter


bp = Blueprint("auth", __name__)


@bp.route("/auth/session", methods=["POST"])
@limiter.limit("10 per minute; 30 per hour")
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
@limiter.limit("20 per hour")
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
@limiter.limit("5 per 15 minutes")
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

    # Build the user update — always promote to advisor, and carry over
    # the chapter/district that was pre-linked to the invite code.
    invite_row = result.get("invite", {})
    user_update = {"role": "advisor"}
    if invite_row.get("chapter_id"):
        user_update["chapter_id"] = invite_row["chapter_id"]
    if invite_row.get("district_id"):
        user_update["district_id"] = invite_row["district_id"]

    supabase.table("users").update(user_update).eq("id", result["user_id"]).execute()
    return api_ok(data={"status": "advisor_verified", "chapter_id": invite_row.get("chapter_id"), "district_id": invite_row.get("district_id")}, status=200)


@bp.route("/admin/verify", methods=["POST"])
@require_auth
@limiter.limit("5 per 15 minutes")
def admin_verify():
    """
    DEBUG-ONLY endpoint — upgrades the authenticated user to 'admin' when they
    provide the ADMIN_TEST_CODE from config.  This endpoint returns 404 in
    production (DEBUG=False) so the code can never be exploited in the wild.
    """
    if not current_app.config.get("DEBUG", False):
        return api_error("not_found", status=404)

    payload = request.get_json(silent=True) or {}
    code = (payload.get("code") or "").strip()
    if not code:
        return api_error("invalid_request", status=400)

    expected = current_app.config.get("ADMIN_TEST_CODE", "")
    if code != expected:
        return api_error("invalid_code", status=400)

    supabase = get_supabase()
    user_id = (g.get("auth") or {}).get("user", {}).get("id")
    if not user_id:
        return api_error("invalid_user", status=400)

    supabase.table("users").update({"role": "admin"}).eq("id", user_id).execute()
    return api_ok(data={"status": "admin_verified"}, status=200)


@bp.route("/auth/resend-verification", methods=["POST"])
@limiter.limit("3 per 15 minutes")
def resend_verification():
    """
    Resend a verification OTP for an existing unconfirmed account.

    Body: { "email": "user@example.com" }

    This is used by the login screen when a user's email is unconfirmed.
    It triggers a new OTP via /auth/otp/request on the backend.
    The OTP verify step will then auto-confirm the Supabase email.
    """
    from fbla.services.otp import generate_otp

    payload = request.get_json(silent=True) or {}
    email = (payload.get("email") or "").strip().lower()

    if not email or "@" not in email:
        return api_error("invalid_email", status=400)

    result = generate_otp(email)

    if result["cooldown"]:
        retry = result.get("retry_after", 60)
        return api_error(
            "otp_cooldown",
            status=429,
            data={"retry_after": retry,
                  "message": f"Please wait {retry}s before requesting another code."},
        )

    code = result["code"]
    email_sent = send_otp_email(email, code)

    data: dict = {
        "status": "sent",
        "message": f"A verification code has been sent to {email}.",
        "email_sent": email_sent,
    }

    if current_app.config.get("DEBUG"):
        data["dev_code"] = code
        current_app.logger.info("[DEV] Resend OTP for %s → %s (email_sent=%s)", email, code, email_sent)

    return api_ok(data=data, status=200)
