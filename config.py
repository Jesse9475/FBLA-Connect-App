import os


def _get_bool(value, default=False):
    if value is None:
        return default
    return value.lower() in ("1", "true", "yes", "on")


class Config:
    # Always set a real secret in production (do NOT hard-code).
    SECRET_KEY = os.environ.get("SECRET_KEY")
    DEBUG = _get_bool(os.environ.get("FLASK_DEBUG"), default=True)

    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    # Support key rotation by allowing a comma-delimited list.
    SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
    SUPABASE_SERVICE_KEYS = os.environ.get("SUPABASE_SERVICE_KEYS")
    SUPABASE_STORAGE_BUCKET = os.environ.get("SUPABASE_STORAGE_BUCKET", "media")

    SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
    SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY")

    # Security hardening defaults.
    MAX_CONTENT_LENGTH = int(os.environ.get("MAX_CONTENT_LENGTH", 10 * 1024 * 1024))
    RATELIMIT_STORAGE_URI = os.environ.get("RATELIMIT_STORAGE_URI", "memory://")
