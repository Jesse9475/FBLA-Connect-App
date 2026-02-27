def sanitize_text(value):
    if value is None:
        return None
    value = value.replace("\x00", "")
    return value.strip()


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

        allowed = rules.get("allowed")
        if allowed and value not in allowed:
            return False, {"error": "invalid_value", "field": field}

        cleaned[field] = value

    if missing:
        return False, {"error": "missing_fields", "fields": missing}

    return True, cleaned
