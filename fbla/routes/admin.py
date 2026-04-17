from flask import Blueprint, g, jsonify, request

from fbla.extensions import limiter
from fbla.schemas.common import validate_payload
from fbla.schemas.payloads import REPORT_SCHEMA
from fbla.services.supabase_auth import require_auth
from fbla.services.permissions import require_admin
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok, api_error


bp = Blueprint("admin", __name__)


@bp.route("/reports", methods=["GET", "POST"])
@limiter.limit("120 per minute")
@require_auth
def reports_collection():
    supabase = get_supabase()
    if request.method == "GET":
        auth_user = (g.get("auth") or {}).get("user") or {}
        user_id = auth_user.get("id")
        is_admin = auth_user.get("role") == "admin"
        query = supabase.table("reports").select("*")
        if not is_admin:
            query = query.eq("reporter_id", user_id)
        result = supabase_retry(lambda: query.order("created_at", desc=True).execute())
        return api_ok(data={"reports": result.data or []})

    payload = request.get_json(silent=True) or {}
    ok, cleaned = validate_payload(payload, REPORT_SCHEMA)
    if not ok:
        return api_error("invalid_request", status=400, data=cleaned)

    reporter_id = (g.get("auth") or {}).get("user", {}).get("id")
    cleaned["reporter_id"] = reporter_id
    result = supabase_retry(lambda: supabase.table("reports").insert(cleaned).execute())
    return api_ok(data={"report": result.data[0] if result.data else cleaned}, status=201)


@bp.route("/admin/reports", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
@require_admin
def admin_reports():
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("reports").select("*").order("created_at", desc=True).execute())
    return api_ok(data={"reports": result.data})
