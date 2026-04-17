import uuid
import mimetypes
import logging

from flask import current_app

from fbla.services.supabase_client import get_supabase

logger = logging.getLogger(__name__)

_bucket_ensured = False

# ── Upload allowlists ──────────────────────────────────────────────────────
# Keep these tight. Any extension not in the list is rejected, regardless
# of what the client claims the MIME type is. This prevents users from
# uploading executables, HTML (XSS-via-storage), SVG (XSS), or arbitrary
# binaries to the public bucket.
ALLOWED_EXTENSIONS = {
    # images
    "jpg", "jpeg", "png", "gif", "webp", "heic", "heif",
    # video (short clips for stories / posts)
    "mp4", "mov", "m4v", "webm",
    # audio
    "mp3", "m4a", "wav", "ogg",
    # documents (resources / hub items)
    "pdf",
}

# Hard ceiling — defence-in-depth on top of MAX_CONTENT_LENGTH at the
# Flask layer. Some hosts forward the body before Flask checks the limit,
# so we re-check after read.
MAX_UPLOAD_BYTES = 25 * 1024 * 1024  # 25 MiB

# Magic-byte sniffing for the most common attack vectors. We don't trust
# the client-supplied content_type for security-relevant decisions.
def _sniff_content_type(raw: bytes, ext: str) -> str:
    head = raw[:16]
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if head[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    if head[:4] == b"%PDF":
        return "application/pdf"
    # MP4 family — "ftyp" box at offset 4
    if raw[4:8] == b"ftyp":
        return "video/mp4"
    # Fall back to extension-based mapping (we already validated ext).
    return mimetypes.types_map.get("." + ext, "application/octet-stream")


def _ensure_bucket(supabase, bucket):
    """Ensure the storage bucket exists. Cached after first successful check."""
    global _bucket_ensured
    if _bucket_ensured:
        return
    try:
        existing = supabase.storage.list_buckets()
        names = [b.name if hasattr(b, "name") else b.get("name") for b in (existing or [])]
        if bucket not in names:
            try:
                supabase.storage.create_bucket(bucket, options={"public": True})
                logger.info("Created storage bucket: %s", bucket)
            except Exception as e:
                # Race or already exists — ignore "duplicate" errors
                if "already exists" not in str(e).lower():
                    logger.warning("Could not create bucket %s: %s", bucket, e)
        _bucket_ensured = True
    except Exception as e:
        logger.warning("Could not verify storage bucket %s: %s", bucket, e)


def upload_file(file_obj, folder="uploads"):
    """Upload a file to Supabase Storage and return its path + public URL.

    Args:
        file_obj: A Flask FileStorage object from request.files.
        folder: Sub-folder within the bucket (e.g. "posts", "hub").

    Returns:
        dict with 'path' (storage path) and 'url' (public URL).

    Raises:
        Exception on upload failure.
    """
    supabase = get_supabase()
    bucket = current_app.config.get("SUPABASE_STORAGE_BUCKET", "media")
    supabase_url = current_app.config.get("SUPABASE_URL", "")

    _ensure_bucket(supabase, bucket)

    # Extension allowlist — reject anything we don't explicitly support
    # before reading the body. Filename without an extension is rejected
    # too (we have no safe content-type to assign).
    raw_name = (file_obj.filename or "").strip()
    if "." not in raw_name:
        raise ValueError("invalid_file_extension")
    ext_lc = raw_name.rsplit(".", 1)[-1].lower()
    if ext_lc not in ALLOWED_EXTENSIONS:
        raise ValueError("disallowed_file_type")
    ext = "." + ext_lc

    # Random storage path — never trust the user-supplied filename for
    # the on-disk name (path traversal, collision, info leak).
    filename = f"{folder}/{uuid.uuid4().hex}{ext}"
    content = file_obj.read()

    if not content:
        raise ValueError("empty_file_payload")

    # Hard size cap (Flask MAX_CONTENT_LENGTH is the primary gate but
    # some hosts/proxies bypass it on streaming uploads).
    if len(content) > MAX_UPLOAD_BYTES:
        raise ValueError("file_too_large")

    # Magic-byte sniffing — never trust the client-supplied content_type
    # for security-relevant decisions. Browsers will render whatever the
    # bucket serves with the stored content-type, so a PNG with
    # `text/html` would be a stored XSS.
    sniffed = _sniff_content_type(content, ext_lc)

    # Cross-check: the sniffed type must agree with the extension family.
    # If a file is named `.png` but the bytes are actually HTML, reject.
    EXT_TO_FAMILY = {
        "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
        "gif": "image/gif", "webp": "image/webp", "heic": "image/heic",
        "heif": "image/heif", "mp4": "video/mp4", "mov": "video/quicktime",
        "m4v": "video/x-m4v", "webm": "video/webm",
        "mp3": "audio/mpeg", "m4a": "audio/mp4", "wav": "audio/wav",
        "ogg": "audio/ogg", "pdf": "application/pdf",
    }
    expected = EXT_TO_FAMILY.get(ext_lc)
    # Only enforce strict matching for image/pdf where misdetection ==
    # XSS or content-confusion risk; for video/audio we accept the
    # extension-mapped type without sniffing every container variant.
    if expected and expected.startswith(("image/", "application/pdf")):
        if sniffed != expected:
            raise ValueError("file_content_mismatch")

    # Final stored content-type — sniffed-or-mapped, never user-supplied.
    content_type = sniffed if sniffed != "application/octet-stream" else (expected or "application/octet-stream")

    def _do_upload():
        # supabase-py v2: file_options must use string values for content-type
        return supabase.storage.from_(bucket).upload(
            path=filename,
            file=content,
            file_options={"content-type": content_type, "upsert": "true"},
        )

    try:
        _do_upload()
    except Exception as e:
        error_str = str(e).lower()
        # If bucket missing despite ensure, try creating + retry
        if "not found" in error_str or "does not exist" in error_str or "bucket" in error_str:
            try:
                supabase.storage.create_bucket(bucket, options={"public": True})
                _do_upload()
            except Exception as e2:
                logger.exception("Storage upload failed after bucket creation")
                raise Exception(f"bucket_or_upload_error: {e2}") from e2
        elif "already exists" in error_str or "duplicate" in error_str:
            # File somehow already exists — still return its URL
            pass
        else:
            logger.exception("Storage upload failed")
            raise Exception(f"storage_error: {e}") from e

    # Construct public URL
    public_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{filename}"

    return {"path": filename, "url": public_url}
