from functools import wraps

import jwt
from flask import current_app, g, request

from fbla.api_utils import api_error
from fbla.services.supabase_client import get_supabase
from fbla.services.users import get_or_create_user


def _decode_jwt(token):
    secret = current_app.config.get("SUPABASE_JWT_SECRET")
    if not secret:
        return None
    # Verify signature + expiry (both on by default in PyJWT).  We skip
    # audience verification because Supabase's `aud` claim has varied
    # across token format versions — requiring a specific audience would
    # lock out legitimately-issued sessions.  Signature + `exp` alone
    # are enough to prove the token came from Supabase and isn't stale.
    try:
        decoded = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
    except Exception:
        # Wrong secret, expired, or malformed — fall through to the
        # Supabase Auth API fallback in verify_supabase_token.
        return None
    # Refuse a token that lacks a subject — without `sub` we can't
    # identify the user even if the signature checks out.
    if not decoded.get("sub"):
        return None
    return decoded


def verify_supabase_token(access_token):
    decoded = _decode_jwt(access_token)
    if decoded:
        return decoded

    # Fallback: verify with Supabase Auth API when JWT secret isn't provided.
    supabase = get_supabase()
    user_response = supabase.auth.get_user(access_token)
    user = user_response.user if hasattr(user_response, "user") else None
    if not user:
        raise ValueError("invalid_token")
    return {
        "sub": user.id,
        "email": user.email,
        "user_metadata": user.user_metadata or {},
    }


def require_auth(view_func):
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            current_app.logger.warning("[AUTH] missing_bearer_token on %s %s", request.method, request.path)
            return api_error("missing_bearer_token", status=401)

        token = header.split(" ", 1)[1].strip()
        try:
            decoded = verify_supabase_token(token)
        except Exception as exc:
            # Log the *actual* reason the token was rejected so we can
            # tell the difference between a bad signature, an expired
            # token, and an unreachable Supabase auth API.
            current_app.logger.warning(
                "[AUTH] invalid_token on %s %s — %s: %s "
                "(jwt_secret_set=%s, token_len=%s, token_prefix=%s)",
                request.method, request.path,
                type(exc).__name__, str(exc)[:200],
                bool(current_app.config.get("SUPABASE_JWT_SECRET")),
                len(token),
                token[:12] + "…" if len(token) > 12 else token,
            )
            return api_error("invalid_token", status=401)

        user_id = decoded.get("sub")
        if not user_id:
            current_app.logger.warning("[AUTH] token decoded but no sub claim")
            return api_error("invalid_token", status=401)

        metadata = decoded.get("user_metadata") or {}
        email = decoded.get("email")
        name = metadata.get("name") or metadata.get("full_name")

        user = get_or_create_user(user_id, email=email, display_name=name)
        g.auth = {"user_id": user_id, "claims": decoded, "user": user}

        return view_func(*args, **kwargs)

    return wrapper
