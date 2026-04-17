import urllib.request
import urllib.parse
import json
import logging
import time

from flask import current_app

try:
    from supabase import create_client
except ImportError:  # pragma: no cover - handled at runtime
    create_client = None

logger = logging.getLogger(__name__)

_client = None


def _build_client():
    """Create a fresh Supabase client from app config."""
    if create_client is None:
        raise RuntimeError("supabase package not installed. Run `pip install supabase`.")

    url = current_app.config.get("SUPABASE_URL")
    key = current_app.config.get("SUPABASE_SERVICE_KEY")
    if not key:
        keys = current_app.config.get("SUPABASE_SERVICE_KEYS") or ""
        key = keys.split(",")[0].strip() if keys else None

    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set.")

    return create_client(url, key)


def get_supabase():
    global _client
    if _client is not None:
        return _client
    _client = _build_client()
    return _client


def reset_supabase():
    """Drop the cached client so the next call to get_supabase() creates a
    fresh one. Used by supabase_retry() when the HTTP/2 connection goes stale."""
    global _client
    _client = None


def supabase_retry(fn, *, retries=2, delay=0.3):
    """Execute *fn* (which should call Supabase via the SDK) and retry on
    transient httpx / httpcore errors like ``[Errno 35] Resource temporarily
    unavailable``.  On each retry, the cached Supabase client is recreated
    so we get a fresh HTTP connection pool.

    Usage in a route::

        result = supabase_retry(
            lambda: get_supabase().table("posts").select("*").execute()
        )
    """
    last_exc = None
    for attempt in range(1 + retries):
        try:
            return fn()
        except Exception as exc:
            exc_str = str(exc).lower()
            is_transient = any(s in exc_str for s in [
                "resource temporarily unavailable",
                "readerror",
                "connection reset",
                "broken pipe",
            ])
            if not is_transient or attempt >= retries:
                raise
            last_exc = exc
            logger.warning(
                "Supabase transient error (attempt %d/%d): %s — retrying",
                attempt + 1, retries + 1, exc,
            )
            reset_supabase()
            time.sleep(delay * (attempt + 1))
    raise last_exc  # unreachable but keeps type-checkers happy


def _get_service_key():
    key = current_app.config.get("SUPABASE_SERVICE_KEY")
    if not key:
        keys = current_app.config.get("SUPABASE_SERVICE_KEYS") or ""
        key = keys.split(",")[0].strip() if keys else None
    return key


def _supabase_admin_request(method: str, path: str, body: dict | None = None) -> dict:
    """Make a direct HTTP request to the Supabase Auth Admin API."""
    url = current_app.config.get("SUPABASE_URL")
    service_key = _get_service_key()
    if not url or not service_key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set.")

    full_url = f"{url.rstrip('/')}/auth/v1{path}"
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(full_url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err_body = e.read().decode(errors="replace")
        logger.warning("Supabase admin API %s %s → %s: %s", method, path, e.code, err_body)
        raise


def confirm_supabase_email(email: str) -> bool:
    """
    Use the Supabase Admin API to confirm the email of the user with the
    given email address.  Returns True on success, False if user not found.

    This is called after our custom OTP is verified so the user can
    immediately sign in without waiting for Supabase's own confirmation link.
    """
    try:
        # 1. Find the user by email
        encoded = urllib.parse.quote(email)
        data = _supabase_admin_request("GET", f"/admin/users?email={encoded}&per_page=1")
        users = data.get("users") or []
        if not users:
            logger.warning("confirm_supabase_email: no user found for %s", email)
            return False

        user_id = users[0].get("id")
        if not user_id:
            return False

        # 2. Confirm the email
        _supabase_admin_request("PUT", f"/admin/users/{user_id}", {"email_confirm": True})
        logger.info("confirm_supabase_email: confirmed email for user %s", user_id)
        return True

    except Exception as exc:
        logger.error("confirm_supabase_email failed for %s: %s", email, exc)
        return False
