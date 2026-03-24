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
    return jwt.decode(
        token,
        secret,
        algorithms=["HS256"],
        options={"verify_aud": False},
    )


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
            return api_error("missing_bearer_token", status=401)

        token = header.split(" ", 1)[1].strip()
        try:
            decoded = verify_supabase_token(token)
        except Exception:
            return api_error("invalid_token", status=401)

        user_id = decoded.get("sub")
        if not user_id:
            return api_error("invalid_token", status=401)

        metadata = decoded.get("user_metadata") or {}
        email = decoded.get("email")
        name = metadata.get("name") or metadata.get("full_name")

        user = get_or_create_user(user_id, email=email, display_name=name)
        g.auth = {"user_id": user_id, "claims": decoded, "user": user}

        return view_func(*args, **kwargs)

    return wrapper
