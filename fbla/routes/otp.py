"""
OTP (One-Time Password) endpoints.

POST /api/auth/otp/request  — issue a 6-digit code for the given email
POST /api/auth/otp/verify   — verify the code entered by the user

Rate limits are intentionally very strict to prevent brute-force:
  • /request  → 3 requests per 15 minutes per IP
  • /verify   → 5 attempts per 15 minutes per IP

In DEBUG mode the generated code is included in the response payload so
the app can surface it in a dev overlay (no email service required).
"""

from flask import Blueprint, current_app, request

from fbla.api_utils import api_error, api_ok
from fbla.extensions import limiter
from fbla.services.email_service import send_otp_email
from fbla.services.otp import generate_otp, verify_otp
from fbla.services.supabase_client import confirm_supabase_email

bp = Blueprint("otp", __name__)

# ── Helpers ──────────────────────────────────────────────────────────────────

def _validate_email(email: str) -> bool:
    return bool(email) and "@" in email and "." in email.split("@", 1)[-1]


# ── Routes ───────────────────────────────────────────────────────────────────

@bp.route("/auth/otp/request", methods=["POST"])
@limiter.limit("3 per 15 minutes")
def otp_request():
    """
    Request an OTP for the given email address.

    Body: { "email": "user@example.com" }

    Response (200):
      { "status": "sent" }
      In DEBUG mode an extra ``dev_code`` field is included so the demo
      works without a live email service.

    Response (429): rate limit exceeded
    Response (400): invalid email
    Response (429): cooldown — re-send attempted too soon
    """
    payload = request.get_json(silent=True) or {}
    email = (payload.get("email") or "").strip().lower()

    if not _validate_email(email):
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

    # Send the OTP via email. send_otp_email returns False if SMTP is not
    # configured — fall through gracefully so the dev overlay still works.
    email_sent = send_otp_email(email, code)

    data: dict = {
        "status": "sent",
        "message": f"A 6-digit code has been sent to {email}.",
        "email_sent": email_sent,
    }

    if current_app.config.get("DEBUG"):
        # Expose code only in dev mode — NEVER in production
        data["dev_code"] = code
        current_app.logger.info("[DEV] OTP for %s → %s (email_sent=%s)", email, code, email_sent)

    return api_ok(data=data, status=200)


@bp.route("/auth/otp/verify", methods=["POST"])
@limiter.limit("5 per 15 minutes")
def otp_verify():
    """
    Verify the OTP the user entered.

    Body: { "email": "user@example.com", "code": "123456" }

    Response (200): { "status": "verified" }
    Response (400): invalid_otp | otp_expired | otp_already_used | too_many_attempts
    Response (429): rate limit exceeded
    """
    payload = request.get_json(silent=True) or {}
    email = (payload.get("email") or "").strip().lower()
    code  = (payload.get("code")  or "").strip()

    if not _validate_email(email):
        return api_error("invalid_email", status=400)
    if not code:
        return api_error("missing_code", status=400)
    if not code.isdigit() or len(code) != 6:
        return api_error("invalid_otp_format", status=400)

    result = verify_otp(email, code)

    if not result["success"]:
        error     = result.get("error", "invalid_otp")
        remaining = result.get("remaining", 0)
        status    = 400

        if error == "too_many_attempts":
            status = 429

        return api_error(error, status=status,
                         data={"remaining_attempts": remaining})

    # OTP is valid — auto-confirm the email in Supabase so the user can
    # sign in immediately without a separate confirmation link.
    try:
        confirm_supabase_email(email)
    except Exception:
        pass  # Non-fatal: user can still try to sign in; log is written inside helper

    return api_ok(data={"status": "verified"}, status=200)
