from functools import wraps

from flask import g

from fbla.api_utils import api_error


def require_admin(view_func):
    """
    Gate a view behind admin role.

    Returns the shared `{"data": ..., "error": ...}` envelope on failure so
    the Flutter client's ApiService parser doesn't choke on a bare
    `{"error": "..."}` shape.
    """
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        user = (g.get("auth") or {}).get("user") or {}
        if user.get("role") != "admin":
            return api_error("forbidden", status=403)
        return view_func(*args, **kwargs)

    return wrapper
