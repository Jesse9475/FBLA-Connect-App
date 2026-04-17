import traceback

from flask import Blueprint, current_app, request

from fbla.extensions import limiter
from fbla.services.supabase_auth import require_auth
from fbla.services.storage import upload_file
from fbla.api_utils import api_ok, api_error


bp = Blueprint("uploads", __name__)


# Folder allowlist — anything outside this set falls back to "uploads".
# This stops a caller from writing into arbitrary, security-sensitive
# bucket prefixes (e.g. /private/, /admin/) by passing a crafted folder.
_ALLOWED_FOLDERS = {
    "uploads", "posts", "hub", "events", "stories",
    "avatars", "messages", "competitive_events", "announcements",
}


@bp.route("/uploads", methods=["POST"])
@require_auth
@limiter.limit("60 per hour;500 per day")
def upload():
    if "file" not in request.files:
        current_app.logger.warning("Upload missing 'file' field. Files=%s Form=%s",
                                   list(request.files.keys()), list(request.form.keys()))
        return api_error("missing_file", status=400)

    file_obj = request.files["file"]
    if not file_obj.filename or len(file_obj.filename) > 255:
        return api_error("invalid_filename", status=400)

    # Reject path-traversal attempts in the filename. Storage uses a
    # random UUID name, but defence-in-depth: we should never let a
    # filename containing slashes or NULs reach the storage layer.
    if any(ch in file_obj.filename for ch in ("/", "\\", "\x00")):
        return api_error("invalid_filename", status=400)

    # Increase default upload limit to 25 MB if not configured
    limit = current_app.config.get("MAX_CONTENT_LENGTH") or (25 * 1024 * 1024)
    max_size = request.content_length
    if max_size is not None and max_size > limit:
        return api_error(f"file_too_large (max {limit} bytes)", status=413)

    # Folder from form data, validated against allowlist.
    folder = (request.form.get("folder") or "uploads").strip().lower()
    if folder not in _ALLOWED_FOLDERS:
        folder = "uploads"

    try:
        result = upload_file(file_obj, folder=folder)
        return api_ok(data={"upload": result}, status=201)
    except ValueError as e:
        # Client-side errors from storage validation (extension/size/
        # mime mismatch). Surface the specific code; safe to share.
        return api_error(str(e), status=400)
    except Exception as e:
        tb = traceback.format_exc()
        current_app.logger.error(
            "Upload failed for %s (folder=%s): %s\n%s",
            file_obj.filename, folder, e, tb,
        )
        # Don't leak server internals — log full traceback above, but
        # return a generic error to the client.
        if current_app.config.get("DEBUG"):
            return api_error(f"upload_failed: {str(e)[:200]}", status=500)
        return api_error("upload_failed", status=500)
