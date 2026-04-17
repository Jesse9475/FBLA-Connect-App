from flask import Blueprint, g, request
from datetime import datetime, timezone

from fbla.extensions import limiter
from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import EVENT_CREATE_SCHEMA, EVENT_UPDATE_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("events", __name__)

POINTS_PER_REGISTRATION = 5
POINTS_PER_ATTENDANCE   = 10   # additional on top of registration points


# ── Helpers ───────────────────────────────────────────────────────────────────

def _auth_user():
    return (g.get("auth") or {}).get("user") or {}


def _upsert_profile_points(supabase, user_id, delta_points=0,
                           delta_attended=0, delta_awards=0):
    """Atomically credit points / counters to a member's profile row."""
    existing = (
        supabase.table("profiles")
        .select("points, events_attended, awards_count")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        row = existing.data[0]
        supabase.table("profiles").update({
            "points":          row.get("points", 0)          + delta_points,
            "events_attended": row.get("events_attended", 0) + delta_attended,
            "awards_count":    row.get("awards_count", 0)    + delta_awards,
            "updated_at":      datetime.now(timezone.utc).isoformat(),
        }).eq("user_id", user_id).execute()
    else:
        supabase.table("profiles").insert({
            "user_id":         user_id,
            "points":          max(delta_points, 0),
            "events_attended": max(delta_attended, 0),
            "awards_count":    max(delta_awards, 0),
        }).execute()


# ── /events collection ────────────────────────────────────────────────────────

@bp.route("/events", methods=["GET", "POST"])
@limiter.limit("120 per minute")
@require_auth
def events_collection():
    supabase = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")
    role      = auth_user.get("role", "member")
    is_admin  = role == "admin"

    if request.method == "GET":
        if is_admin:
            query = supabase.table("events").select("*")
        else:
            chapter_id  = auth_user.get("chapter_id")
            district_id = auth_user.get("district_id")

            # All events are org-scoped (no public events).
            # Show events from the viewer's chapter, their district (no-chapter events),
            # and events they created.
            vis_filters = []
            if user_id:
                vis_filters.append(f"created_by.eq.{user_id}")
            if chapter_id:
                vis_filters.append(f"chapter_id.eq.{chapter_id}")
            if district_id:
                vis_filters.append(
                    f"and(district_id.eq.{district_id},chapter_id.is.null)"
                )
            if not vis_filters:
                # No chapter/district — return nothing
                vis_filters.append("id.eq.00000000-0000-0000-0000-000000000000")
            query = supabase.table("events").select("*").or_(",".join(vis_filters))

        events = supabase_retry(lambda: query.order("start_at", desc=False).execute()).data or []

        # Attach registration status for the current user
        if events and user_id:
            event_ids = [e["id"] for e in events]
            regs = (
                supabase.table("event_registrations")
                .select("event_id, attended")
                .eq("user_id", user_id)
                .in_("event_id", event_ids)
                .execute()
            ).data or []
            reg_map = {r["event_id"]: r for r in regs}
            for e in events:
                r = reg_map.get(e["id"])
                e["is_registered"] = r is not None
                e["is_attended"]   = (r or {}).get("attended", False)

        return api_ok(data={"events": events})

    # ── POST: create event ────────────────────────────────────────────────────
    from flask import current_app
    current_app.logger.info(
        "[events.POST] user=%s role=%s chapter_id=%s district_id=%s",
        user_id, role, auth_user.get("chapter_id"), auth_user.get("district_id"),
    )
    if role not in ("admin", "advisor"):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, EVENT_CREATE_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    # All events are org-scoped; no public events.
    cleaned["visibility"] = "members"
    cleaned["created_by"] = user_id

    if role == "admin":
        # Admins post nationally
        cleaned.setdefault("chapter_id", None)
        cleaned.setdefault("district_id", None)
    else:
        # Advisors always scope to their chapter/district
        cleaned["chapter_id"]  = auth_user.get("chapter_id")
        cleaned["district_id"] = auth_user.get("district_id")

    result = supabase_retry(lambda: supabase.table("events").insert(cleaned).execute())
    return api_ok(data={"event": result.data[0] if result.data else cleaned}, status=201)


# ── /events/<id> detail ───────────────────────────────────────────────────────

@bp.route("/events/<event_id>", methods=["GET", "PATCH", "DELETE"])
@limiter.limit("60 per minute; 30 per minute; 10 per minute")
@require_auth
def events_detail(event_id):
    supabase  = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")
    is_admin  = auth_user.get("role") == "admin"

    if request.method == "GET":
        result = supabase_retry(lambda: supabase.table("events").select("*").eq("id", event_id).limit(1).execute())
        event = result.data[0] if result.data else None
        if not event:
            return api_ok(data={"event": None})
        if (not is_admin
                and event.get("visibility") not in ("public", "members")
                and event.get("created_by") != user_id):
            return api_error("forbidden", status=403)

        # Attach registration count + current user status
        reg_count = (
            supabase.table("event_registrations")
            .select("id", count="exact")
            .eq("event_id", event_id)
            .execute()
        ).count or 0
        my_reg = (
            supabase.table("event_registrations")
            .select("attended")
            .eq("event_id", event_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        ).data
        event["registration_count"] = reg_count
        event["is_registered"] = bool(my_reg)
        event["is_attended"]   = (my_reg[0].get("attended", False)) if my_reg else False
        return api_ok(data={"event": event})

    if request.method == "DELETE":
        if not is_admin:
            owned = (supabase.table("events").select("id")
                     .eq("id", event_id).eq("created_by", user_id)
                     .limit(1).execute())
            if not owned.data:
                return api_error("forbidden", status=403)
        supabase.table("events").delete().eq("id", event_id).execute()
        return api_ok(data={"deleted": True})

    # PATCH
    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, EVENT_UPDATE_SCHEMA, allow_partial=True)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)
    if not is_admin:
        owned = (supabase.table("events").select("id")
                 .eq("id", event_id).eq("created_by", user_id)
                 .limit(1).execute())
        if not owned.data:
            return api_error("forbidden", status=403)
    result = supabase_retry(lambda: supabase.table("events").update(cleaned).eq("id", event_id).execute())
    return api_ok(data={"event": result.data[0] if result.data else cleaned})


# ── /events/<id>/register ─────────────────────────────────────────────────────

@bp.route("/events/<event_id>/register", methods=["POST", "DELETE"])
@limiter.limit("20 per minute")
@require_auth
def event_register(event_id):
    """
    POST   → register the current user for an event (+5 points)
    DELETE → cancel registration (-5 points)
    """
    supabase  = get_supabase()
    auth_user = _auth_user()
    user_id   = auth_user.get("id")
    if not user_id:
        return api_error("invalid_user", status=400)

    # Make sure the event exists
    ev = supabase.table("events").select("id").eq("id", event_id).limit(1).execute()
    if not ev.data:
        return api_error("not_found", status=404)

    if request.method == "POST":
        existing = (
            supabase.table("event_registrations")
            .select("id")
            .eq("event_id", event_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if existing.data:
            return api_ok(data={"status": "already_registered"})

        supabase.table("event_registrations").insert({
            "event_id": event_id,
            "user_id":  user_id,
        }).execute()

        # Award registration points
        _upsert_profile_points(supabase, user_id, delta_points=POINTS_PER_REGISTRATION)
        return api_ok(data={"status": "registered", "points_awarded": POINTS_PER_REGISTRATION}, status=201)

    # DELETE — cancel registration (only if not yet attended)
    reg = (
        supabase.table("event_registrations")
        .select("id, attended")
        .eq("event_id", event_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if not reg.data:
        return api_ok(data={"status": "not_registered"})
    if reg.data[0].get("attended"):
        return api_error("already_attended", status=400)

    supabase.table("event_registrations").delete().eq("id", reg.data[0]["id"]).execute()
    # Claw back registration points
    _upsert_profile_points(supabase, user_id, delta_points=-POINTS_PER_REGISTRATION)
    return api_ok(data={"status": "unregistered"})


# ── /events/<id>/registrations  (advisor/admin: list + mark attendance) ───────

@bp.route("/events/<event_id>/registrations", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def event_registrations_list(event_id):
    """Advisors/admins only — list registrations with member names."""
    auth_user = _auth_user()
    if auth_user.get("role") not in ("admin", "advisor"):
        return api_error("forbidden", status=403)

    supabase = get_supabase()
    regs = supabase_retry(lambda: supabase.table("event_registrations")
        .select("*, users(id, display_name, email)")
        .eq("event_id", event_id)
        .order("registered_at")
        .execute()).data or []
    return api_ok(data={"registrations": regs})


@bp.route("/events/<event_id>/registrations/<user_id>", methods=["PATCH"])
@limiter.limit("30 per minute")
@require_auth
def event_mark_attendance(event_id, user_id):
    """
    Advisors/admins mark a specific member as attended.
    PATCH body: { "attended": true }
    The Postgres trigger awards +10 points + increments events_attended automatically.
    """
    auth_user = _auth_user()
    if auth_user.get("role") not in ("admin", "advisor"):
        return api_error("forbidden", status=403)

    payload  = request.get_json(silent=True) or {}
    attended = payload.get("attended")
    if attended is None:
        return api_error("invalid_request", status=400)

    supabase = get_supabase()
    reg = (
        supabase.table("event_registrations")
        .select("id, attended")
        .eq("event_id", event_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if not reg.data:
        # Auto-create registration row if advisor marks someone as attended directly
        supabase.table("event_registrations").insert({
            "event_id": event_id,
            "user_id":  user_id,
            "attended": True,
            "attended_at": datetime.now(timezone.utc).isoformat(),
        }).execute()
        # The INSERT trigger doesn't fire for attendance; handle manually
        _upsert_profile_points(
            supabase, user_id,
            delta_points=POINTS_PER_REGISTRATION + POINTS_PER_ATTENDANCE,
            delta_attended=1,
        )
        return api_ok(data={"status": "attended_and_registered"})

    if reg.data[0].get("attended") and attended:
        return api_ok(data={"status": "already_attended"})

    update_data = {"attended": attended}
    if attended:
        update_data["attended_at"] = datetime.now(timezone.utc).isoformat()

    supabase.table("event_registrations").update(update_data).eq("id", reg.data[0]["id"]).execute()
    # The Postgres trigger handles points/events_attended when attended flips true
    return api_ok(data={"status": "updated"})


# ── /awards  (advisor/admin: grant a named award to a member) ─────────────────

@bp.route("/awards", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def awards_grant():
    """Grant a named award to a member. The Postgres trigger bumps their awards_count."""
    auth_user = _auth_user()
    if auth_user.get("role") not in ("admin", "advisor"):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    user_id = payload.get("user_id")
    title   = (payload.get("title") or "").strip()
    if not user_id or not title:
        return api_error("invalid_request", status=400)

    supabase = get_supabase()
    result = supabase.table("awards").insert({
        "user_id":    user_id,
        "title":      title,
        "description": payload.get("description", ""),
        "awarded_by": auth_user.get("id"),
    }).execute()
    return api_ok(data={"award": result.data[0] if result.data else {}}, status=201)


@bp.route("/awards/<user_id_param>", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def awards_list(user_id_param):
    """List all awards for a given member."""
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("awards")
        .select("*")
        .eq("user_id", user_id_param)
        .order("awarded_at", desc=True)
        .execute())
    return api_ok(data={"awards": result.data or []})
