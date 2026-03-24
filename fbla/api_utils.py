from typing import Any, Dict, Optional

from flask import jsonify


def api_response(data: Any = None, error: Optional[str] = None, status: int = 200):
    """
    Return a JSON API response in the shared shape: {"data": ..., "error": ...}.
    """
    body: Dict[str, Any] = {"data": data, "error": error}
    return jsonify(body), status


def api_ok(data: Any = None, status: int = 200):
    """
    Convenience helper for successful responses.
    """
    return api_response(data=data, error=None, status=status)


def api_error(message: str, status: int = 400, data: Any = None):
    """
    Convenience helper for error responses.
    """
    return api_response(data=data, error=message, status=status)

