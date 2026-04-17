import re
from urllib.parse import urlparse


def sanitize_text(value):
    if value is None:
        return None
    value = value.replace("\x00", "")
    return value.strip()


def is_valid_uuid(value):
    """Validate UUID format using regex pattern."""
    if not isinstance(value, str):
        return False
    pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    return re.match(pattern, value) is not None


def validate_url(value):
    """
    Validate that a URL has a safe scheme (http or https only).
    Blocks javascript:, data:, file:, ftp:, and other dangerous schemes.

    Returns (is_valid, error_msg) tuple.
    """
    if not isinstance(value, str):
        return False, "url_not_string"

    try:
        parsed = urlparse(value)
        scheme = parsed.scheme.lower()

        # Only allow http and https schemes
        if scheme not in ('http', 'https'):
            return False, "invalid_url_scheme"

        # Require a netloc (domain/host)
        if not parsed.netloc:
            return False, "invalid_url_format"

        return True, None
    except Exception:
        return False, "invalid_url"


def validate_payload(payload, schema, allow_partial=False):
    if not isinstance(payload, dict):
        return False, {"error": "invalid_payload"}

    unexpected = [field for field in payload if field not in schema]
    if unexpected:
        return False, {"error": "unexpected_fields", "fields": unexpected}

    missing = []
    cleaned = {}

    for field, rules in schema.items():
        if field not in payload:
            if rules.get("required") and not allow_partial:
                missing.append(field)
            continue

        value = payload[field]
        if value is None:
            if not rules.get("nullable", False):
                return False, {"error": "invalid_field", "field": field}
            cleaned[field] = None
            continue

        expected_type = rules.get("type")
        if expected_type and not isinstance(value, expected_type):
            return False, {"error": "invalid_type", "field": field}

        if isinstance(value, (int, float)):
            min_value = rules.get("min_value")
            max_value = rules.get("max_value")
            if min_value is not None and value < min_value:
                return False, {"error": "too_small", "field": field}
            if max_value is not None and value > max_value:
                return False, {"error": "too_large", "field": field}

        if isinstance(value, str):
            value = sanitize_text(value)
            min_len = rules.get("min_length")
            max_len = rules.get("max_length")
            if min_len is not None and len(value) < min_len:
                return False, {"error": "too_short", "field": field}
            if max_len is not None and len(value) > max_len:
                return False, {"error": "too_long", "field": field}

            # URL validation for fields ending with _url or named url
            if field.endswith("_url") or field == "url":
                is_valid, error_msg = validate_url(value)
                if not is_valid:
                    return False, {"error": error_msg or "invalid_url", "field": field}

        # Lists (e.g. profile interests): cap count to prevent abuse and
        # normalize each item to a trimmed, non-empty string. Drops
        # nullish entries silently so the caller doesn't need to pre-filter.
        if isinstance(value, list):
            max_items = rules.get("max_items")
            if max_items is not None and len(value) > max_items:
                return False, {"error": "too_many_items", "field": field}
            normalized = []
            for item in value:
                if isinstance(item, str):
                    item = sanitize_text(item)
                    if item:
                        normalized.append(item)
                elif item is None:
                    continue
                else:
                    return False, {"error": "invalid_item_type", "field": field}
            value = normalized

        allowed = rules.get("allowed")
        if allowed and value not in allowed:
            return False, {"error": "invalid_value", "field": field}

        cleaned[field] = value

    if missing:
        return False, {"error": "missing_fields", "fields": missing}

    return True, cleaned
