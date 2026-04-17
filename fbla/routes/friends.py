"""Friends API.

Bidirectional friendship management for FBLA Connect. Each friendship is
stored as a single row with the user IDs sorted (`user_low_id < user_high_id`)
so duplicate pairs are impossible regardless of who initiated the request.

Routes
------
GET    /api/friends                — list current user's accepted friends
GET    /api/friends/pending        — list incoming pending requests
GET    /api/friends/sent           — list outgoing pending requests
GET    /api/friends/search?q=…     — search users not currently friends
POST   /api/friends/request/<uid>  — send a friend request
POST   /api/friends/<uid>/accept   — accept a pending incoming request
POST   /api/friends/<uid>/reject   — reject (or cancel) a pending request
DELETE /api/friends/<uid>          — unfriend an accepted friend
"""

from flask import Blueprint, g, request

from fbla.extensions import limiter
from fbla.api_utils import api_ok, api_error
from fbla.schemas.common import is_valid_uuid
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry


bp = Blueprint("friends", __name__)


def _me():
    """Return the authenticated user's UUID string, or None."""
    return ((g.get("auth") or {}).get("user") or {}).get("id")


def _canonical_pair(a, b):
    """Sort two UUID strings so we always store the same canonical row."""
    return (a, b) if a < b else (b, a)


def _hydrate_users(user_ids):
    """Look up display_name / role / chapter_id for a list of user IDs."""
    if not user_ids:
        return {}
    supabase = get_supabase()
    res = (
        supabase.table("users")
        .select("id, display_name, username, role, chapter_id")
        .in_("id", list(user_ids))
        .execute()
    )
    return {row["id"]: row for row in (res.data or [])}


# ─────────────────────────────────────────────────────────────────────────────
# Read endpoints
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/friends", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def list_friends():
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    if not is_valid_uuid(me):
        return api_error("invalid_user_id", status=400)

    supabase = get_supabase()
    res = supabase_retry(lambda: supabase.table("friendships")
        .select("*")
        .eq("status", "accepted")
        .or_(f"user_low_id.eq.{me},user_high_id.eq.{me}")
        .order("updated_at", desc=True)
        .execute())
    rows = res.data or []

    # The "other" user is whichever side isn't me.
    other_ids = {
        (r["user_high_id"] if r["user_low_id"] == me else r["user_low_id"])
        for r in rows
    }
    users = _hydrate_users(other_ids)

    friends = []
    for r in rows:
        other = r["user_high_id"] if r["user_low_id"] == me else r["user_low_id"]
        friends.append({
            "id": r["id"],
            "user": users.get(other) or {"id": other},
            "since": r["updated_at"],
        })
    return api_ok(data={"friends": friends})


@bp.route("/friends/pending", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def list_pending():
    """Incoming pending requests — i.e. someone asked to be MY friend."""
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    if not is_valid_uuid(me):
        return api_error("invalid_user_id", status=400)

    supabase = get_supabase()
    res = supabase_retry(lambda: supabase.table("friendships")
        .select("*")
        .eq("status", "pending")
        .neq("requested_by", me)
        .or_(f"user_low_id.eq.{me},user_high_id.eq.{me}")
        .order("created_at", desc=True)
        .execute())
    rows = res.data or []
    requester_ids = {r["requested_by"] for r in rows}
    users = _hydrate_users(requester_ids)

    requests = [
        {
            "id": r["id"],
            "user": users.get(r["requested_by"]) or {"id": r["requested_by"]},
            "requested_at": r["created_at"],
        }
        for r in rows
    ]
    return api_ok(data={"requests": requests})


@bp.route("/friends/sent", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def list_sent():
    """Outgoing pending requests — i.e. requests I sent that haven't been
    accepted yet. Useful for the UI to show 'Request sent' on those rows."""
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    if not is_valid_uuid(me):
        return api_error("invalid_user_id", status=400)

    supabase = get_supabase()
    res = supabase_retry(lambda: supabase.table("friendships")
        .select("*")
        .eq("status", "pending")
        .eq("requested_by", me)
        .order("created_at", desc=True)
        .execute())
    rows = res.data or []
    other_ids = {
        (r["user_high_id"] if r["user_low_id"] == me else r["user_low_id"])
        for r in rows
    }
    users = _hydrate_users(other_ids)

    out = []
    for r in rows:
        other = r["user_high_id"] if r["user_low_id"] == me else r["user_low_id"]
        out.append({
            "id": r["id"],
            "user": users.get(other) or {"id": other},
            "requested_at": r["created_at"],
        })
    return api_ok(data={"requests": out})


@bp.route("/friends/search", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def search_users():
    """Search for users to add as friends.

    Returns a relationship-aware list: each user has a `relationship` field
    of `none | pending_outgoing | pending_incoming | accepted | self` so the
    UI can show the right CTA without an extra round trip.
    """
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    q = (request.args.get("q") or "").strip()
    try:
        limit = max(1, min(int(request.args.get("limit", 25)), 100))
    except (TypeError, ValueError):
        limit = 25

    supabase = get_supabase()

    query = (
        supabase.table("users")
        .select("id, display_name, username, role, chapter_id")
        .order("display_name")
        .limit(limit)
    )
    if q:
        safe = q.replace("%", r"\%").replace("_", r"\_")
        # Match either display_name OR username so users can find each other
        # by either handle.
        query = query.or_(
            f"display_name.ilike.%{safe}%,username.ilike.%{safe}%"
        )
    users = supabase_retry(lambda: query.execute()).data or []

    # Pull every existing friendship row that touches me so we can label
    # results without N+1 queries.
    if not is_valid_uuid(me):
        return api_error("invalid_user_id", status=400)

    rel_res = supabase_retry(lambda: supabase.table("friendships")
        .select("*")
        .or_(f"user_low_id.eq.{me},user_high_id.eq.{me}")
        .execute())
    rels_by_other = {}
    for r in (rel_res.data or []):
        other = r["user_high_id"] if r["user_low_id"] == me else r["user_low_id"]
        rels_by_other[other] = r

    out = []
    for u in users:
        uid = u["id"]
        if uid == me:
            label = "self"
        else:
            rel = rels_by_other.get(uid)
            if not rel:
                label = "none"
            elif rel["status"] == "accepted":
                label = "accepted"
            elif rel["status"] == "pending":
                label = ("pending_outgoing"
                         if rel["requested_by"] == me else "pending_incoming")
            else:
                label = "none"
        out.append({**u, "relationship": label})

    return api_ok(data={"users": out, "query": q})


# ─────────────────────────────────────────────────────────────────────────────
# Mutating endpoints
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/friends/request/<other_id>", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def send_request(other_id):
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)
    if other_id == me:
        return api_error("cannot_friend_self", status=400)

    supabase = get_supabase()

    # Verify target user exists.
    target = (
        supabase.table("users")
        .select("id")
        .eq("id", other_id)
        .limit(1)
        .execute()
    )
    if not target.data:
        return api_error("user_not_found", status=404)

    low, high = _canonical_pair(me, other_id)

    existing = (
        supabase.table("friendships")
        .select("*")
        .eq("user_low_id", low)
        .eq("user_high_id", high)
        .limit(1)
        .execute()
    )
    if existing.data:
        row = existing.data[0]
        if row["status"] == "accepted":
            return api_error("already_friends", status=409)
        if row["status"] == "pending":
            # If the OTHER side already asked us, treat this POST as an
            # implicit accept — common UX pattern in messaging apps.
            if row["requested_by"] != me:
                upd = (
                    supabase.table("friendships")
                    .update({"status": "accepted"})
                    .eq("id", row["id"])
                    .execute()
                )
                return api_ok(
                    data={"friendship": (upd.data or [row])[0],
                           "auto_accepted": True},
                    status=200,
                )
            return api_error("request_already_pending", status=409)
        # status == 'rejected' — allow re-requesting by flipping back to pending
        upd = (
            supabase.table("friendships")
            .update({"status": "pending", "requested_by": me})
            .eq("id", row["id"])
            .execute()
        )
        return api_ok(data={"friendship": (upd.data or [row])[0]}, status=200)

    ins = (
        supabase.table("friendships")
        .insert({
            "user_low_id":  low,
            "user_high_id": high,
            "requested_by": me,
            "status":       "pending",
        })
        .execute()
    )
    return api_ok(data={"friendship": (ins.data or [{}])[0]}, status=201)


@bp.route("/friends/<other_id>/accept", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def accept_request(other_id):
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    supabase = get_supabase()
    low, high = _canonical_pair(me, other_id)

    existing = (
        supabase.table("friendships")
        .select("*")
        .eq("user_low_id", low)
        .eq("user_high_id", high)
        .limit(1)
        .execute()
    )
    if not existing.data:
        return api_error("no_pending_request", status=404)
    row = existing.data[0]
    if row["status"] != "pending":
        return api_error("invalid_state", status=409,
                         data={"status": row["status"]})
    if row["requested_by"] == me:
        # Can't accept your own request.
        return api_error("cannot_accept_own_request", status=400)

    upd = (
        supabase.table("friendships")
        .update({"status": "accepted"})
        .eq("id", row["id"])
        .execute()
    )
    return api_ok(data={"friendship": (upd.data or [row])[0]}, status=200)


@bp.route("/friends/<other_id>/reject", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def reject_request(other_id):
    """Reject an incoming request OR cancel an outgoing one. Either way the
    row is removed so the requester can try again later."""
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    supabase = get_supabase()
    low, high = _canonical_pair(me, other_id)

    existing = (
        supabase.table("friendships")
        .select("*")
        .eq("user_low_id", low)
        .eq("user_high_id", high)
        .limit(1)
        .execute()
    )
    if not existing.data:
        return api_error("no_pending_request", status=404)
    row = existing.data[0]
    if row["status"] != "pending":
        return api_error("invalid_state", status=409,
                         data={"status": row["status"]})

    supabase.table("friendships").delete().eq("id", row["id"]).execute()
    return api_ok(data={"removed": True}, status=200)


@bp.route("/friends/<other_id>", methods=["DELETE"])
@limiter.limit("10 per minute")
@require_auth
def unfriend(other_id):
    me = _me()
    if not me:
        return api_error("unauthorized", status=401)

    supabase = get_supabase()
    low, high = _canonical_pair(me, other_id)

    existing = (
        supabase.table("friendships")
        .select("id, status")
        .eq("user_low_id", low)
        .eq("user_high_id", high)
        .limit(1)
        .execute()
    )
    if not existing.data:
        return api_error("not_friends", status=404)

    supabase.table("friendships").delete().eq("id", existing.data[0]["id"]).execute()
    return api_ok(data={"removed": True}, status=200)
