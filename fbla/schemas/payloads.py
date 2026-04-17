AUTH_SESSION_SCHEMA = {
    "token": {"type": str, "required": True, "min_length": 10, "max_length": 5000},
}

USER_UPDATE_SCHEMA = {
    "display_name": {"type": str, "required": False, "max_length": 80},
    "first_name": {"type": str, "required": False, "max_length": 80},
    "last_name": {"type": str, "required": False, "max_length": 80},
    "username": {"type": str, "required": False, "max_length": 30},
    "email": {"type": str, "required": False, "max_length": 120},
    "chapter_id": {"type": str, "required": False, "max_length": 36},
    "district_id": {"type": str, "required": False, "max_length": 36},
}

PROFILE_SCHEMA = {
    "bio": {"type": str, "required": False, "max_length": 500},
    "avatar_url": {"type": str, "required": False, "max_length": 500},
    "grade": {"type": str, "required": False, "max_length": 20},
    "school": {"type": str, "required": False, "max_length": 120},
    "location": {"type": str, "required": False, "max_length": 120},
    # Interests captured during signup. Optional list of category labels
    # ("Accounting", "Finance", etc.) that the user has self-identified
    # with. Stored as a text[] in Postgres.
    "interests": {"type": list, "required": False, "max_items": 30},
}

POST_CREATE_SCHEMA = {
    "caption":   {"type": str, "required": True,  "max_length": 2000},
    "media_url": {"type": str, "required": False, "max_length": 500},
    # Optional free-text location the author attaches to a post
    # (e.g. "Conference Hall A"). Capped to keep feed cards tidy.
    "location":  {"type": str, "required": False, "max_length": 120},
    # visibility is no longer user-controlled — always auto-set server-side
}

POST_UPDATE_SCHEMA = {
    "caption":   {"type": str, "required": False, "max_length": 2000},
    "media_url": {"type": str, "required": False, "max_length": 500},
    "location":  {"type": str, "required": False, "max_length": 120},
}

COMMENT_SCHEMA = {
    "body": {"type": str, "required": True, "max_length": 2000},
}

MESSAGE_SCHEMA = {
    "body": {"type": str, "required": True, "max_length": 4000},
    "media_url": {"type": str, "required": False, "max_length": 500},
}

EVENT_CREATE_SCHEMA = {
    "title": {"type": str, "required": True, "max_length": 200},
    "body": {"type": str, "required": False, "max_length": 4000},
    "start_at": {"type": str, "required": True, "max_length": 64},
    "end_at": {"type": str, "required": False, "max_length": 64},
    "location": {"type": str, "required": False, "max_length": 200},
    "location_image_url": {"type": str, "required": False, "max_length": 500},
    "place_id": {"type": str, "required": False, "max_length": 200},
    "registration_deadline": {"type": str, "required": False, "max_length": 64},
    # Enhanced customization
    "category":     {"type": str,  "required": False, "max_length": 40},
    "accent_color": {"type": str,  "required": False, "max_length": 16},
    "capacity":     {"type": int,  "required": False, "min_value": 1, "max_value": 100000},
    "tags":         {"type": list, "required": False, "max_items": 10},
    # visibility auto-set server-side
}

EVENT_UPDATE_SCHEMA = {
    "title": {"type": str, "required": False, "max_length": 200},
    "body": {"type": str, "required": False, "max_length": 4000},
    "start_at": {"type": str, "required": False, "max_length": 64},
    "end_at": {"type": str, "required": False, "max_length": 64},
    "location": {"type": str, "required": False, "max_length": 200},
    "location_image_url": {"type": str, "required": False, "max_length": 500},
    "place_id": {"type": str, "required": False, "max_length": 200},
    "registration_deadline": {"type": str, "required": False, "max_length": 64},
    "category":     {"type": str,  "required": False, "max_length": 40},
    "accent_color": {"type": str,  "required": False, "max_length": 16},
    "capacity":     {"type": int,  "required": False, "min_value": 1, "max_value": 100000},
    "tags":         {"type": list, "required": False, "max_items": 10},
}

HUB_CREATE_SCHEMA = {
    "title": {"type": str, "required": True, "max_length": 200},
    "body": {"type": str, "required": True, "max_length": 6000},
    "category": {"type": str, "required": False, "max_length": 80},
    "file_path": {"type": str, "required": False, "max_length": 500},
    "url":           {"type": str,  "required": False, "max_length": 500},
    "resource_type": {"type": str,  "required": False,
                       "allowed": ["document", "link", "video",
                                   "study_guide", "sample_test", "template"]},
    "tags":          {"type": list, "required": False, "max_items": 10},
}

HUB_UPDATE_SCHEMA = {
    "title": {"type": str, "required": False, "max_length": 200},
    "body": {"type": str, "required": False, "max_length": 6000},
    "category": {"type": str, "required": False, "max_length": 80},
    "file_path": {"type": str, "required": False, "max_length": 500},
    "url":           {"type": str,  "required": False, "max_length": 500},
    "resource_type": {"type": str,  "required": False,
                       "allowed": ["document", "link", "video",
                                   "study_guide", "sample_test", "template"]},
    "tags":          {"type": list, "required": False, "max_items": 10},
}

REPORT_SCHEMA = {
    "target_type": {"type": str, "required": True, "max_length": 40},
    "target_id": {"type": str, "required": True, "max_length": 80},
    "reason": {"type": str, "required": True, "max_length": 400},
}

ADVISOR_INVITE_SCHEMA = {
    "expires_in_days": {"type": int, "required": False, "min_value": 1, "max_value": 30},
}

ADVISOR_VERIFY_SCHEMA = {
    "code": {"type": str, "required": True, "min_length": 6, "max_length": 200},
}

ANNOUNCEMENT_CREATE_SCHEMA = {
    "title": {"type": str, "required": True, "max_length": 200},
    "body": {"type": str, "required": True, "max_length": 6000},
    # scope, district_id, chapter_id auto-set server-side for advisors;
    # admins may still pass them explicitly.
    "scope": {"type": str, "required": False, "allowed": ["national", "district", "chapter"]},
    "district_id": {"type": str, "required": False, "max_length": 36},
    "chapter_id": {"type": str, "required": False, "max_length": 36},
}

ANNOUNCEMENT_UPDATE_SCHEMA = {
    "title": {"type": str, "required": False, "max_length": 200},
    "body": {"type": str, "required": False, "max_length": 6000},
    "scope": {"type": str, "required": False, "allowed": ["national", "district", "chapter"]},
    "district_id": {"type": str, "required": False, "max_length": 36},
    "chapter_id": {"type": str, "required": False, "max_length": 36},
}
