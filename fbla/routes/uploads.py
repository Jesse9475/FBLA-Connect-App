from flask import Blueprint, current_app, jsonify, request

from fbla.services.supabase_auth import require_auth
from fbla.services.storage import upload_file
from fbla.api_utils import api_ok, api_error


bp = Blueprint("uploads", __name__)


@bp.route("/uploads", methods=["POST"])
@require_auth
def upload():
    if "file" not in request.files:
        return api_error("missing_file", status=400)

    file_obj = request.files["file"]
    if not file_obj.filename or len(file_obj.filename) > 255:
        return api_error("invalid_filename", status=400)

    max_size = request.content_length
    if max_size is not None and max_size > current_app.config.get("MAX_CONTENT_LENGTH", 0):
        return api_error("file_too_large", status=413)

    result = upload_file(file_obj)
    return api_ok(data={"upload": result}, status=201)
