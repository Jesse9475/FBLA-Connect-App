from flask import current_app

try:
    from supabase import create_client
except ImportError:  # pragma: no cover - handled at runtime
    create_client = None


_client = None


def get_supabase():
    global _client
    if _client is not None:
        return _client

    if create_client is None:
        raise RuntimeError("supabase package not installed. Run `pip install supabase`.")

    url = current_app.config.get("SUPABASE_URL")
    key = current_app.config.get("SUPABASE_SERVICE_KEY")
    if not key:
        keys = current_app.config.get("SUPABASE_SERVICE_KEYS") or ""
        key = keys.split(",")[0].strip() if keys else None

    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set.")

    _client = create_client(url, key)
    return _client
