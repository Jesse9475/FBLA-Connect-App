import os


def _get_bool(value, default=False):
    if value is None:
        return default
    return value.lower() in ("1", "true", "yes", "on")


class Config:
    # Always set a real secret in production (do NOT hard-code).
    SECRET_KEY = os.environ.get("SECRET_KEY")
    # Default to PROD-safe (DEBUG=False). Local devs opt in by exporting
    # FLASK_DEBUG=true. This prevents accidental prod deploys with debug
    # mode enabled (which would expose tracebacks, OTP codes, admin codes).
    DEBUG = _get_bool(os.environ.get("FLASK_DEBUG"), default=False)

    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    # Support key rotation by allowing a comma-delimited list.
    SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
    SUPABASE_SERVICE_KEYS = os.environ.get("SUPABASE_SERVICE_KEYS")
    SUPABASE_STORAGE_BUCKET = os.environ.get("SUPABASE_STORAGE_BUCKET", "media")

    SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
    SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY")

    # ── Email / SMTP ──────────────────────────────────────────────────────
    SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT = os.environ.get("SMTP_PORT", "587")
    SMTP_USER = os.environ.get("SMTP_USER")
    SMTP_PASS = os.environ.get("SMTP_PASS")
    SMTP_FROM = os.environ.get("SMTP_FROM")

    # ── Testing / demo codes ──────────────────────────────────────────────
    # These codes ONLY work when DEBUG=True and are for local testing only.
    # No fallback default — must be explicitly set via env var, otherwise
    # the admin-verify endpoint will reject every code (safe-by-default).
    ADMIN_TEST_CODE = os.environ.get("ADMIN_TEST_CODE", "")

    # Security hardening defaults.
    MAX_CONTENT_LENGTH = int(os.environ.get("MAX_CONTENT_LENGTH", 10 * 1024 * 1024))
    RATELIMIT_STORAGE_URI = os.environ.get("RATELIMIT_STORAGE_URI", "memory://")
