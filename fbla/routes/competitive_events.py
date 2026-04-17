from flask import Blueprint, g, request

from fbla.extensions import limiter
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("competitive_events", __name__)


def _auth_user():
    return (g.get("auth") or {}).get("user") or {}


# ── Competitive Events ──────────────────────────────────────────────────────

@bp.route("/competitive-events", methods=["GET"])
@limiter.limit("120 per minute")
@require_auth
def list_competitive_events():
    """List all competitive events, optionally filtered by category."""
    supabase = get_supabase()
    category = request.args.get("category")

    query = supabase.table("competitive_events").select("*")
    if category and category != "all":
        query = query.eq("category", category)

    result = supabase_retry(lambda: query.order("name").execute())
    return api_ok(data={"events": result.data or []})


@bp.route("/competitive-events/<event_id>", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def get_competitive_event(event_id):
    """Get a single competitive event by ID."""
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("competitive_events")
        .select("*")
        .eq("id", event_id)
        .limit(1)
        .execute())
    event = result.data[0] if result.data else None
    if not event:
        return api_error("not_found", status=404)
    return api_ok(data={"event": event})


# ── Resources ───────────────────────────────────────────────────────────────

@bp.route("/competitive-events/<event_id>/resources", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def list_resources(event_id):
    """List resources for a competitive event."""
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("competitive_event_resources")
        .select("*")
        .eq("event_id", event_id)
        .order("created_at", desc=True)
        .execute())
    return api_ok(data={"resources": result.data or []})


@bp.route("/competitive-events/<event_id>/resources", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def create_resource(event_id):
    """Create a resource for a competitive event (advisor/admin only)."""
    auth_user = _auth_user()
    role = auth_user.get("role", "member")
    from flask import current_app
    current_app.logger.info(
        "[resources.POST] event=%s user=%s role=%s",
        event_id, auth_user.get("id"), role,
    )
    if role not in ("advisor", "admin"):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    title = (payload.get("title") or "").strip()
    if not title or len(title) > 200:
        return api_error("invalid_request", status=400)

    supabase = get_supabase()
    resource = {
        "event_id": event_id,
        "title": title,
        "description": (payload.get("description") or "").strip()[:1000],
        "resource_type": payload.get("resource_type", "link"),
        "url": (payload.get("url") or "").strip()[:500],
        "file_path": (payload.get("file_path") or "").strip()[:500],
        "source": (payload.get("source") or "").strip()[:200],
        "created_by": auth_user.get("id"),
    }
    result = supabase_retry(lambda: supabase.table("competitive_event_resources").insert(resource).execute())
    return api_ok(data={"resource": result.data[0] if result.data else resource}, status=201)


# ── Quizzes ─────────────────────────────────────────────────────────────────

@bp.route("/competitive-events/<event_id>/quizzes", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def list_quizzes(event_id):
    """List quizzes for a competitive event."""
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("quizzes")
        .select("*")
        .eq("event_id", event_id)
        .order("created_at", desc=True)
        .execute())
    return api_ok(data={"quizzes": result.data or []})


@bp.route("/quizzes/<quiz_id>/questions", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def list_questions(quiz_id):
    """List all questions for a quiz."""
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("quiz_questions")
        .select("*")
        .eq("quiz_id", quiz_id)
        .order("sort_order")
        .execute())
    return api_ok(data={"questions": result.data or []})


@bp.route("/quiz-attempts", methods=["POST"])
@require_auth
@limiter.limit("30 per hour;200 per day")
def submit_quiz_attempt():
    """Submit a quiz attempt. Points are awarded by the DB trigger.

    Rate-limited to prevent point-farming bots from spamming attempts.
    The composite key (IP + user_id) ensures an attacker can't bypass
    the limit by rotating IPs while logged in.
    """
    auth_user = _auth_user()
    user_id = auth_user.get("id")
    payload = request.get_json(silent=True) or {}

    quiz_id = payload.get("quiz_id")
    if not quiz_id:
        return api_error("invalid_request", status=400)

    # Defensive numeric clamping so a malicious client can't claim a
    # negative or wildly-inflated score that bypasses the DB trigger's
    # expectations.
    def _clamp_int(value, lo, hi, default=0):
        try:
            value = int(value)
        except (TypeError, ValueError):
            return default
        return max(lo, min(value, hi))

    score             = _clamp_int(payload.get("score"), 0, 10_000)
    total_questions   = _clamp_int(payload.get("total_questions"), 0, 1_000)
    correct_count     = _clamp_int(payload.get("correct_count"), 0, total_questions)
    time_taken        = _clamp_int(payload.get("time_taken_seconds"), 0, 60 * 60 * 24)
    points_earned     = _clamp_int(payload.get("points_earned"), 0, 10_000)

    mode = (payload.get("mode") or "test").strip().lower()
    if mode not in ("test", "practice", "review"):
        mode = "test"

    supabase = get_supabase()
    attempt = {
        "quiz_id": quiz_id,
        "user_id": user_id,
        "mode": mode,
        "score": score,
        "total_questions": total_questions,
        "correct_count": correct_count,
        "time_taken_seconds": time_taken,
        "answers": payload.get("answers"),
        "points_earned": points_earned,
    }
    result = supabase.table("quiz_attempts").insert(attempt).execute()
    return api_ok(
        data={"attempt": result.data[0] if result.data else attempt},
        status=201,
    )


# ── Share Tracking ──────────────────────────────────────────────────────────

def _track_share(table, item_id):
    """Append a platform to the shared_platforms array of a content item."""
    auth_user = _auth_user()
    role = auth_user.get("role", "member")
    if role not in ("advisor", "admin"):
        return api_error("forbidden", status=403)

    payload = request.get_json(silent=True) or {}
    platform = (payload.get("platform") or "").strip().lower()
    if not platform or platform not in ("instagram", "twitter", "native"):
        return api_error("invalid_request", status=400)

    supabase = get_supabase()

    # Fetch current platforms
    existing = (
        supabase.table(table)
        .select("shared_platforms")
        .eq("id", item_id)
        .limit(1)
        .execute()
    )
    if not existing.data:
        return api_error("not_found", status=404)

    current = existing.data[0].get("shared_platforms") or []
    if platform not in current:
        current.append(platform)
        supabase.table(table).update(
            {"shared_platforms": current}
        ).eq("id", item_id).execute()

    return api_ok(data={"shared_platforms": current})


@bp.route("/posts/<post_id>/share", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def share_post(post_id):
    return _track_share("posts", post_id)


@bp.route("/events/<event_id>/share", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def share_event(event_id):
    return _track_share("events", event_id)


@bp.route("/announcements/<announcement_id>/share", methods=["POST"])
@limiter.limit("20 per minute")
@require_auth
def share_announcement(announcement_id):
    return _track_share("announcements", announcement_id)
