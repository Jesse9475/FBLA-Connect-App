"""
Messaging routes — DMs, group chats, chapter groups, and moderation reports.

Endpoints
---------
GET  /threads                       — list all conversations for current user
POST /threads                       — create DM or group chat
GET  /threads/<id>                  — get single thread details + members
PATCH /threads/<id>                 — update group name / icon (owner only)
GET  /threads/<id>/messages         — paginated message history
POST /threads/<id>/messages         — send a message
GET  /threads/<id>/members          — list members
POST /threads/<id>/members          — add member to group (owner only)
DELETE /threads/<id>/members/<uid>  — remove member / leave group
GET  /threads/chapter/<chapter_id>  — get-or-create chapter group chat
POST /messages/<msg_id>/report      — report a message
GET  /reports                       — list moderation reports (advisor/admin)
PATCH /reports/<report_id>          — update report status (advisor/admin)
"""

from flask import Blueprint, g, request

from fbla.extensions import limiter
from fbla.api_utils import api_error, api_ok
from fbla.services.profanity_filter import censor as _censor_profanity
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry

bp = Blueprint("messages", __name__)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _current_user():
    auth = g.get("auth") or {}
    return auth.get("user") or {}


def _is_thread_member(supabase, thread_id, user_id):
    res = (
        supabase.table("thread_members")
        .select("id")
        .eq("thread_id", thread_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    return bool(res.data)


def _is_thread_owner(supabase, thread_id, user_id):
    res = (
        supabase.table("thread_members")
        .select("id")
        .eq("thread_id", thread_id)
        .eq("user_id", user_id)
        .eq("member_role", "owner")
        .limit(1)
        .execute()
    )
    return bool(res.data)


def _enrich_threads(supabase, threads, current_user_id):
    """Attach display names, last message, and unread indicator to each thread."""
    if not threads:
        return []

    thread_ids = [t["id"] for t in threads]

    # All memberships for these threads
    mem_res = (
        supabase.table("thread_members")
        .select("thread_id, user_id, member_role")
        .in_("thread_id", thread_ids)
        .execute()
    )
    memberships = mem_res.data or []

    # Unique user IDs (excluding self) for display-name lookup
    other_ids = list({
        m["user_id"] for m in memberships
        if m["user_id"] != current_user_id
    })
    name_map = {}
    if other_ids:
        u_res = (
            supabase.table("users")
            .select("id, display_name, role")
            .in_("id", other_ids)
            .execute()
        )
        name_map = {u["id"]: u.get("display_name") or "Member"
                    for u in (u_res.data or [])}

    # thread_id → list of other participant names
    thread_others: dict = {}
    for m in memberships:
        if m["user_id"] == current_user_id:
            continue
        tid = m["thread_id"]
        thread_others.setdefault(tid, []).append(
            name_map.get(m["user_id"], "Member")
        )

    # Last message per thread
    last_msg: dict = {}
    last_ts: dict = {}
    for tid in thread_ids:
        msg_res = (
            supabase.table("messages")
            .select("body, created_at")
            .eq("thread_id", tid)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if msg_res.data:
            last_msg[tid] = msg_res.data[0].get("body", "")
            last_ts[tid] = msg_res.data[0].get("created_at", "")

    enriched = []
    for t in threads:
        tid = t["id"]
        t_type = t.get("type", "direct")

        # For DMs use the other person's name; for groups use stored name
        if t_type == "direct":
            others = thread_others.get(tid, [])
            t["display_name"] = others[0] if others else "Chat"
        else:
            t["display_name"] = t.get("name") or "Group Chat"

        t["other_display_name"] = t.get("display_name")  # compat alias
        t["last_message"] = last_msg.get(tid, "")
        t["last_message_at"] = last_ts.get(tid, t.get("created_at", ""))
        t["member_count"] = sum(
            1 for m in memberships if m["thread_id"] == tid
        )
        enriched.append(t)

    # Sort by last activity descending
    enriched.sort(
        key=lambda x: x.get("last_message_at") or x.get("created_at") or "",
        reverse=True,
    )
    return enriched


# ─────────────────────────────────────────────────────────────────────────────
# GET / POST  /threads
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/threads", methods=["GET", "POST"])
@limiter.limit("120 per minute")
@require_auth
def threads_collection():
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    is_admin = user.get("role") == "admin"

    # ── GET ───────────────────────────────────────────────────────────────────
    if request.method == "GET":
        # Pagination — bound the response so an admin (or a user in many
        # group threads) doesn't pull the entire threads table at once.
        try:
            limit = int(request.args.get("limit", 50))
        except (TypeError, ValueError):
            limit = 50
        try:
            offset = int(request.args.get("offset", 0))
        except (TypeError, ValueError):
            offset = 0
        limit = max(1, min(limit, 100))
        offset = max(0, offset)

        if is_admin:
            res = (
                supabase.table("threads")
                .select("*")
                .order("created_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
            return api_ok(data={
                "threads": _enrich_threads(supabase, res.data or [], user_id),
                "limit": limit,
                "offset": offset,
            })

        # Fetch all thread IDs the user belongs to
        mem_res = (
            supabase.table("thread_members")
            .select("thread_id")
            .eq("user_id", user_id)
            .execute()
        )
        thread_ids = [m["thread_id"] for m in (mem_res.data or [])]
        if not thread_ids:
            return api_ok(data={"threads": [], "limit": limit, "offset": offset})

        res = (
            supabase.table("threads")
            .select("*")
            .in_("id", thread_ids)
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return api_ok(data={
            "threads": _enrich_threads(supabase, res.data or [], user_id),
            "limit": limit,
            "offset": offset,
        })

    # ── POST — create DM or group ─────────────────────────────────────────────
    payload = request.get_json(silent=True) or {}
    thread_type = payload.get("type", "direct")  # 'direct' | 'group'

    if thread_type == "direct":
        recipient_id = payload.get("recipient_id")
        if not recipient_id or recipient_id == user_id:
            return api_error("invalid_request", status=400)

        # Check for existing DM between these two users
        my_threads_res = (
            supabase.table("thread_members")
            .select("thread_id")
            .eq("user_id", user_id)
            .execute()
        )
        my_ids = {m["thread_id"] for m in (my_threads_res.data or [])}
        their_threads_res = (
            supabase.table("thread_members")
            .select("thread_id")
            .eq("user_id", recipient_id)
            .execute()
        )
        their_ids = {m["thread_id"] for m in (their_threads_res.data or [])}
        shared = my_ids & their_ids
        if shared:
            # Return the existing DM thread
            for tid in shared:
                t_res = (
                    supabase.table("threads")
                    .select("*")
                    .eq("id", tid)
                    .eq("type", "direct")
                    .limit(1)
                    .execute()
                )
                if t_res.data:
                    return api_ok(data={"thread": t_res.data[0]}, status=200)

        # Create new DM thread
        t_res = (
            supabase.table("threads")
            .insert({"type": "direct", "created_by": user_id})
            .execute()
        )
        thread = t_res.data[0] if t_res.data else {}
        if thread.get("id"):
            supabase.table("thread_members").insert([
                {"thread_id": thread["id"], "user_id": user_id,         "member_role": "member"},
                {"thread_id": thread["id"], "user_id": recipient_id,    "member_role": "member"},
            ]).execute()
        return api_ok(data={"thread": thread}, status=201)

    else:  # group
        name = (payload.get("name") or "").strip()
        icon = payload.get("icon_emoji", "💬")
        member_ids = payload.get("member_ids") or []
        if not name:
            return api_error("invalid_request", status=400)

        t_res = (
            supabase.table("threads")
            .insert({
                "type": "group",
                "name": name,
                "icon_emoji": icon,
                "created_by": user_id,
            })
            .execute()
        )
        thread = t_res.data[0] if t_res.data else {}
        if thread.get("id"):
            members = [
                {"thread_id": thread["id"], "user_id": user_id, "member_role": "owner"}
            ]
            for mid in member_ids:
                if mid and mid != user_id:
                    members.append({"thread_id": thread["id"], "user_id": mid, "member_role": "member"})
            supabase.table("thread_members").insert(members).execute()
        return api_ok(data={"thread": thread}, status=201)


# ─────────────────────────────────────────────────────────────────────────────
# GET /threads/chapter/<chapter_id>  — get-or-create chapter group chat
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/threads/chapter/<chapter_id>", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def chapter_thread(chapter_id):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")

    # Look up the chapter
    ch_res = (
        supabase.table("chapters")
        .select("id, name, thread_id")
        .eq("id", chapter_id)
        .limit(1)
        .execute()
    )
    if not ch_res.data:
        return api_error("not_found", status=404)

    chapter = ch_res.data[0]
    thread_id = chapter.get("thread_id")

    if thread_id:
        # Fetch existing thread
        t_res = (
            supabase.table("threads")
            .select("*")
            .eq("id", thread_id)
            .limit(1)
            .execute()
        )
        thread = t_res.data[0] if t_res.data else None
    else:
        thread = None

    if not thread:
        # Create chapter group thread
        t_res = (
            supabase.table("threads")
            .insert({
                "type": "group",
                "name": chapter["name"],
                "icon_emoji": "🏫",
                "chapter_id": chapter_id,
                "created_by": user_id,
            })
            .execute()
        )
        thread = t_res.data[0] if t_res.data else {}
        if thread.get("id"):
            # Link back to chapter
            supabase.table("chapters").update({"thread_id": thread["id"]}).eq("id", chapter_id).execute()

    # Ensure the requesting user is a member
    if thread and thread.get("id"):
        if not _is_thread_member(supabase, thread["id"], user_id):
            supabase.table("thread_members").insert({
                "thread_id": thread["id"],
                "user_id": user_id,
                "member_role": "member",
            }).execute()

    return api_ok(data={"thread": thread})


# ─────────────────────────────────────────────────────────────────────────────
# GET / PATCH  /threads/<id>
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/threads/<thread_id>", methods=["GET", "PATCH"])
@limiter.limit("60 per minute; 30 per minute")
@require_auth
def thread_detail(thread_id):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    is_admin = user.get("role") == "admin"

    if not is_admin and not _is_thread_member(supabase, thread_id, user_id):
        return api_error("forbidden", status=403)

    if request.method == "GET":
        t_res = supabase.table("threads").select("*").eq("id", thread_id).limit(1).execute()
        if not t_res.data:
            return api_error("not_found", status=404)
        thread = t_res.data[0]

        # Attach members with display names
        mem_res = (
            supabase.table("thread_members")
            .select("user_id, member_role, created_at")
            .eq("thread_id", thread_id)
            .execute()
        )
        members = mem_res.data or []
        uids = [m["user_id"] for m in members]
        if uids:
            u_res = supabase.table("users").select("id, display_name, role").in_("id", uids).execute()
            name_map = {u["id"]: u for u in (u_res.data or [])}
            for m in members:
                u = name_map.get(m["user_id"], {})
                m["display_name"] = u.get("display_name") or "Member"
                m["role"] = u.get("role", "member")
        thread["members"] = members
        return api_ok(data={"thread": thread})

    # PATCH — update name / icon (owner or admin only)
    if not is_admin and not _is_thread_owner(supabase, thread_id, user_id):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    updates = {}
    if "name" in payload:
        updates["name"] = (payload["name"] or "").strip() or None
    if "icon_emoji" in payload:
        updates["icon_emoji"] = payload["icon_emoji"] or "💬"
    if not updates:
        return api_error("invalid_request", status=400)

    res = supabase.table("threads").update(updates).eq("id", thread_id).execute()
    return api_ok(data={"thread": res.data[0] if res.data else {}})


# ─────────────────────────────────────────────────────────────────────────────
# GET / POST  /threads/<id>/messages
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/threads/<thread_id>/messages", methods=["GET", "POST"])
@limiter.limit("120 per minute; 60 per minute")
@require_auth
def thread_messages(thread_id):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    is_admin = user.get("role") == "admin"

    # Access check
    if not is_admin and not _is_thread_member(supabase, thread_id, user_id):
        return api_error("forbidden", status=403)

    if request.method == "GET":
        # Bounded pagination — `int()` on user input would crash (and
        # leak a 500) on a non-numeric value. Catch and clamp.
        try:
            limit = int(request.args.get("limit", 50))
        except (TypeError, ValueError):
            limit = 50
        limit = max(1, min(limit, 100))
        before = request.args.get("before")  # ISO timestamp for pagination

        q = (
            supabase.table("messages")
            .select("id, body, thread_id, user_id, created_at")
            .eq("thread_id", thread_id)
        )
        if before:
            q = q.lt("created_at", before)
        q = q.order("created_at", desc=False).limit(limit)
        messages = supabase_retry(lambda: q.execute()).data or []

        # Attach sender display names
        sender_ids = list({m["user_id"] for m in messages})
        name_map = {}
        if sender_ids:
            u_res = supabase.table("users").select("id, display_name").in_("id", sender_ids).execute()
            name_map = {u["id"]: u.get("display_name") or "Member" for u in (u_res.data or [])}
        for m in messages:
            m["sender_name"] = name_map.get(m["user_id"], "Member")

        return api_ok(data={"messages": messages})

    # POST — send a message
    payload = request.get_json(silent=True) or {}
    body = (payload.get("body") or "").strip()
    if not body:
        return api_error("invalid_request", status=400)

    # Server-side profanity filter — defense-in-depth. The Flutter client
    # already censors, but anything hitting this endpoint directly (curl,
    # third-party client, older app version) also gets cleaned here.
    body = _censor_profanity(body)

    res = supabase.table("messages").insert({
        "body": body,
        "thread_id": thread_id,
        "user_id": user_id,
    }).execute()

    # Bump thread updated_at
    supabase.table("threads").update({"updated_at": "now()"}).eq("id", thread_id).execute()

    msg = res.data[0] if res.data else {}
    # Attach sender name for optimistic UI
    u_res = supabase.table("users").select("display_name").eq("id", user_id).limit(1).execute()
    msg["sender_name"] = (u_res.data or [{}])[0].get("display_name") or "Member"

    return api_ok(data={"message": msg}, status=201)


# ─────────────────────────────────────────────────────────────────────────────
# GET / POST  /threads/<id>/members
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/threads/<thread_id>/members", methods=["GET", "POST"])
@limiter.limit("60 per minute; 20 per minute")
@require_auth
def thread_members_collection(thread_id):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    is_admin = user.get("role") == "admin"

    if not is_admin and not _is_thread_member(supabase, thread_id, user_id):
        return api_error("forbidden", status=403)

    if request.method == "GET":
        mem_res = (
            supabase.table("thread_members")
            .select("user_id, member_role, created_at")
            .eq("thread_id", thread_id)
            .execute()
        )
        members = mem_res.data or []
        uids = [m["user_id"] for m in members]
        if uids:
            u_res = supabase.table("users").select("id, display_name, role").in_("id", uids).execute()
            name_map = {u["id"]: u for u in (u_res.data or [])}
            for m in members:
                u = name_map.get(m["user_id"], {})
                m["display_name"] = u.get("display_name") or "Member"
                m["app_role"] = u.get("role", "member")
        return api_ok(data={"members": members})

    # POST — add a new member (owner or admin only)
    if not is_admin and not _is_thread_owner(supabase, thread_id, user_id):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    new_uid = payload.get("user_id")
    if not new_uid:
        return api_error("invalid_request", status=400)
    if _is_thread_member(supabase, thread_id, new_uid):
        return api_ok(data={"message": "already_member"})

    supabase.table("thread_members").insert({
        "thread_id": thread_id,
        "user_id": new_uid,
        "member_role": "member",
    }).execute()
    return api_ok(data={"message": "added"}, status=201)


# ─────────────────────────────────────────────────────────────────────────────
# DELETE /threads/<id>/members/<uid>  — remove member or leave
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/threads/<thread_id>/members/<target_uid>", methods=["DELETE"])
@limiter.limit("10 per minute")
@require_auth
def thread_member_remove(thread_id, target_uid):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    is_admin = user.get("role") == "admin"

    # Users can remove themselves (leave); owners/admins can remove others
    if target_uid != user_id:
        if not is_admin and not _is_thread_owner(supabase, thread_id, user_id):
            return api_error("forbidden", status=403)

    supabase.table("thread_members").delete().eq("thread_id", thread_id).eq("user_id", target_uid).execute()
    return api_ok(data={"message": "removed"})


# ─────────────────────────────────────────────────────────────────────────────
# POST /messages/<msg_id>/report  — report a message
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/messages/<msg_id>/report", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def report_message(msg_id):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")

    # Fetch the message to confirm existence + get context
    msg_res = (
        supabase.table("messages")
        .select("id, body, thread_id, user_id, created_at")
        .eq("id", msg_id)
        .limit(1)
        .execute()
    )
    if not msg_res.data:
        return api_error("not_found", status=404)
    msg = msg_res.data[0]
    thread_id = msg["thread_id"]

    # Requester must be a thread member
    if not _is_thread_member(supabase, thread_id, user_id):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    reason = (payload.get("reason") or "inappropriate").strip()

    # Grab surrounding context (3 messages before + the reported one)
    ctx_res = (
        supabase.table("messages")
        .select("body, user_id, created_at")
        .eq("thread_id", thread_id)
        .lte("created_at", msg["created_at"])
        .order("created_at", desc=True)
        .limit(4)
        .execute()
    )
    context_msgs = list(reversed(ctx_res.data or []))
    context_text = "\n".join(
        f"[{m.get('created_at','')[:16]}] {m.get('body','')}"
        for m in context_msgs
    )

    # Insert report
    supabase.table("reports").insert({
        "target_type": "message",
        "target_id": msg_id,
        "reason": reason,
        "reporter_id": user_id,
        "status": "open",
        "context": context_text,
    }).execute()

    return api_ok(data={"message": "reported"}, status=201)


# ─────────────────────────────────────────────────────────────────────────────
# GET /reports  — list moderation reports (advisor / admin)
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/reports", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def reports_list():
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    role = user.get("role", "member")

    if role not in ("admin", "advisor"):
        return api_error("forbidden", status=403)

    # Admins / district-level advisors see all; chapter advisors see their chapter's reports
    reports_res = (
        supabase.table("reports")
        .select("*")
        .order("created_at", desc=True)
        .execute()
    )
    reports = reports_res.data or []

    if role == "advisor":
        # Limit to reports where the reporter is in the advisor's chapter
        chapter_id = user.get("chapter_id")
        if chapter_id:
            # Get member IDs in this chapter
            ch_members_res = (
                supabase.table("users")
                .select("id")
                .eq("chapter_id", chapter_id)
                .execute()
            )
            ch_member_ids = {u["id"] for u in (ch_members_res.data or [])}
            reports = [r for r in reports if r.get("reporter_id") in ch_member_ids]
        else:
            reports = []

    # Attach reporter display name
    reporter_ids = list({r["reporter_id"] for r in reports if r.get("reporter_id")})
    name_map = {}
    if reporter_ids:
        u_res = supabase.table("users").select("id, display_name").in_("id", reporter_ids).execute()
        name_map = {u["id"]: u.get("display_name") or "Member" for u in (u_res.data or [])}
    for r in reports:
        r["reporter_name"] = name_map.get(r.get("reporter_id"), "Member")

    return api_ok(data={"reports": reports})


# ─────────────────────────────────────────────────────────────────────────────
# PATCH /reports/<id>  — update status (advisor / admin)
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/reports/<report_id>", methods=["PATCH"])
@limiter.limit("30 per minute")
@require_auth
def report_update(report_id):
    supabase = get_supabase()
    user = _current_user()
    user_id = user.get("id")
    role = user.get("role", "member")

    if role not in ("admin", "advisor"):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    new_status = payload.get("status")
    if new_status not in ("open", "reviewed", "closed"):
        return api_error("invalid_request", status=400)

    # ── Chapter-scope IDOR guard ─────────────────────────────────────────
    # Advisors can resolve reports only within their own chapter. Without
    # this check, an advisor in chapter A could PATCH a report belonging
    # to chapter B (no FK enforcement at the route layer). Admins are
    # global and skip the scope check.
    if role == "advisor":
        existing = (
            supabase.table("reports")
            .select("id, chapter_id, reporter_id")
            .eq("id", report_id)
            .limit(1)
            .execute()
        )
        if not existing.data:
            return api_error("not_found", status=404)

        report_chapter = existing.data[0].get("chapter_id")
        advisor_chapter = user.get("chapter_id")
        # If the report carries a chapter, advisor must match. If the
        # report has no chapter (legacy/global), only admins may touch it.
        if not advisor_chapter or report_chapter != advisor_chapter:
            return api_error("forbidden", status=403)

    updates: dict = {"status": new_status}
    if new_status == "closed":
        updates["resolved"] = True
        updates["resolved_by"] = user_id
        updates["resolved_at"] = "now()"

    res = supabase.table("reports").update(updates).eq("id", report_id).execute()
    return api_ok(data={"report": res.data[0] if res.data else {}})
