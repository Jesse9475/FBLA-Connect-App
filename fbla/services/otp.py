"""
In-memory OTP (One-Time Password) service.

Generates 6-digit numeric codes, stores them with a 5-minute TTL, and
enforces a maximum of 3 verification attempts per code before invalidating.

In production, replace the ``_send_email`` stub with a real transactional
email call (e.g. SendGrid, Resend, SES).  For local development and the
demo, ``generate_otp`` returns the raw code so the Flutter debug overlay
can display it without requiring email infrastructure.
"""

import random
import threading
from datetime import datetime, timezone, timedelta

# ── Constants ───────────────────────────────────────────────────────────────
OTP_EXPIRY_MINUTES = 5   # code is valid for 5 minutes
MAX_ATTEMPTS       = 3   # after 3 wrong guesses the entry is invalidated
OTP_COOLDOWN_SECS  = 60  # minimum seconds between re-sends for the same email

# ── In-memory store ─────────────────────────────────────────────────────────
# { email_lower: { code, expires_at, attempts, used, issued_at } }
_store: dict[str, dict] = {}
_lock  = threading.Lock()

# ── Internal helpers ─────────────────────────────────────────────────────────

def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


def _purge_expired() -> None:
    """Remove stale entries (called under lock)."""
    now = _now()
    expired = [k for k, v in _store.items() if now > v["expires_at"]]
    for k in expired:
        del _store[k]


# ── Public API ───────────────────────────────────────────────────────────────

def generate_otp(email: str) -> dict:
    """
    Generate a 6-digit OTP for *email*.

    Returns a dict:
      ``{"code": "123456", "cooldown": False}``    – new code issued
      ``{"code": None,     "cooldown": True}``     – re-send blocked (too soon)

    The caller should email the code to the user.  In DEBUG mode the code
    is included in the API response so judges can verify the flow without
    a live email service.
    """
    key = email.strip().lower()
    now = _now()

    with _lock:
        _purge_expired()

        existing = _store.get(key)
        if existing and not existing["used"]:
            elapsed = (now - existing["issued_at"]).total_seconds()
            if elapsed < OTP_COOLDOWN_SECS:
                # Too soon — don't generate a new code
                return {"code": None, "cooldown": True,
                        "retry_after": int(OTP_COOLDOWN_SECS - elapsed)}

        code = f"{random.SystemRandom().randint(0, 999_999):06d}"
        _store[key] = {
            "code":       code,
            "expires_at": now + timedelta(minutes=OTP_EXPIRY_MINUTES),
            "attempts":   0,
            "used":       False,
            "issued_at":  now,
        }

    return {"code": code, "cooldown": False}


def verify_otp(email: str, code: str) -> dict:
    """
    Verify *code* for *email*.

    Returns:
      ``{"success": True}``
      ``{"success": False, "error": "<reason>", "remaining": <int>}``

    Possible error keys:
      invalid_otp | otp_expired | otp_already_used | too_many_attempts
    """
    key = email.strip().lower()
    code = code.strip()

    with _lock:
        entry = _store.get(key)

        if not entry:
            return {"success": False, "error": "invalid_otp", "remaining": 0}

        if entry["used"]:
            return {"success": False, "error": "otp_already_used", "remaining": 0}

        if _now() > entry["expires_at"]:
            del _store[key]
            return {"success": False, "error": "otp_expired", "remaining": 0}

        entry["attempts"] += 1

        if entry["attempts"] > MAX_ATTEMPTS:
            del _store[key]
            return {"success": False, "error": "too_many_attempts", "remaining": 0}

        if entry["code"] != code:
            remaining = MAX_ATTEMPTS - entry["attempts"]
            if remaining <= 0:
                del _store[key]
                return {"success": False, "error": "too_many_attempts", "remaining": 0}
            return {"success": False, "error": "invalid_otp", "remaining": remaining}

        # ── Correct code ──────────────────────────────────────────────────
        entry["used"] = True
        del _store[key]          # clean up immediately after use
        return {"success": True}


def invalidate_otp(email: str) -> None:
    """Explicitly invalidate any pending OTP for *email* (e.g. on logout)."""
    key = email.strip().lower()
    with _lock:
        _store.pop(key, None)
