from flask import Blueprint, request

from fbla.extensions import limiter
from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase, supabase_retry
from fbla.api_utils import api_ok


bp = Blueprint("org", __name__)


@bp.route("/districts", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def districts_list():
    # The Flutter signup flow expects a list — never null. If the PostgREST
    # call fails (error), `result.data` can be None, which would make the
    # client choke with "type 'Null' is not a subtype of type 'List'".
    supabase = get_supabase()
    result = supabase_retry(lambda: supabase.table("districts").select("*").order("name", desc=False).execute())
    return api_ok(data={"districts": result.data or []})


@bp.route("/chapters", methods=["GET"])
@limiter.limit("60 per minute")
@require_auth
def chapters_list():
    supabase = get_supabase()
    district_id = request.args.get("district_id")
    query = supabase.table("chapters").select("*")
    if district_id:
        query = query.eq("district_id", district_id)
    result = supabase_retry(lambda: query.order("name", desc=False).execute())
    return api_ok(data={"chapters": result.data or []})
