import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from fbla.services.supabase_client import get_supabase


def _hash_code(code):
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def create_invite_code(expires_in_days=7):
    code = secrets.token_urlsafe(8)
    code_hash = _hash_code(code)
    expires_at = datetime.now(timezone.utc) + timedelta(days=expires_in_days)

    supabase = get_supabase()
    payload = {"code_hash": code_hash, "expires_at": expires_at.isoformat()}
    result = supabase.table("advisor_invites").insert(payload).execute()
    invite = result.data[0] if result.data else payload
    return {
        "id": invite.get("id"),
        "code": code,
        "expires_at": invite.get("expires_at"),
    }


def consume_invite_code(code, user_id):
    supabase = get_supabase()
    code_hash = _hash_code(code)

    existing = (
        supabase.table("advisor_invites")
        .select("*")
        .eq("code_hash", code_hash)
        .limit(1)
        .execute()
    )
    if not existing.data:
        return {"success": False, "error": "invalid_code"}

    invite = existing.data[0]
    if invite.get("used_at"):
        return {"success": False, "error": "code_already_used"}

    if invite.get("expires_at"):
        expires_at = datetime.fromisoformat(invite["expires_at"].replace("Z", "+00:00"))
        if expires_at < datetime.now(timezone.utc):
            return {"success": False, "error": "code_expired"}

    updated = (
        supabase.table("advisor_invites")
        .update({"used_by": user_id, "used_at": datetime.now(timezone.utc).isoformat()})
        .eq("id", invite["id"])
        .execute()
    )
    return {"success": True, "user_id": user_id, "invite": updated.data[0] if updated.data else invite}
