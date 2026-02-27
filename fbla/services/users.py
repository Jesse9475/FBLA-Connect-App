from fbla.services.supabase_client import get_supabase


def get_or_create_user(auth_user_id, email=None, display_name=None):
    supabase = get_supabase()
    existing = supabase.table("users").select("*").eq("id", auth_user_id).limit(1).execute()
    if existing.data:
        return existing.data[0]

    payload = {
        "id": auth_user_id,
        "email": email,
        "display_name": display_name,
        "role": "member",
    }
    created = supabase.table("users").insert(payload).execute()
    return created.data[0] if created.data else payload
