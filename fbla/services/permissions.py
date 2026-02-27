from functools import wraps

from flask import g, jsonify


def require_admin(view_func):
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        user = (g.get("auth") or {}).get("user") or {}
        if user.get("role") != "admin":
            return jsonify({"error": "forbidden"}), 403
        return view_func(*args, **kwargs)

    return wrapper
