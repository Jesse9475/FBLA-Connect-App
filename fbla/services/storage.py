import uuid

from flask import current_app

from fbla.services.supabase_client import get_supabase


def upload_file(file_obj, folder="uploads"):
    supabase = get_supabase()
    bucket = current_app.config.get("SUPABASE_STORAGE_BUCKET", "media")

    ext = ""
    if file_obj.filename and "." in file_obj.filename:
        ext = "." + file_obj.filename.rsplit(".", 1)[-1].lower()

    filename = f"{folder}/{uuid.uuid4().hex}{ext}"
    content = file_obj.read()

    result = supabase.storage.from_(bucket).upload(filename, content)
    return {"path": filename, "result": result}
