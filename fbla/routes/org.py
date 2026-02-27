from flask import Blueprint, jsonify, request

from fbla.services.supabase_auth import require_auth
from fbla.services.supabase_client import get_supabase


bp = Blueprint("org", __name__)


@bp.route("/districts", methods=["GET"])
@require_auth
def districts_list():
    supabase = get_supabase()
    result = supabase.table("districts").select("*").order("name", desc=False).execute()
    return jsonify({"districts": result.data})


@bp.route("/chapters", methods=["GET"])
@require_auth
def chapters_list():
    supabase = get_supabase()
    district_id = request.args.get("district_id")
    query = supabase.table("chapters").select("*")
    if district_id:
        query = query.eq("district_id", district_id)
    result = query.order("name", desc=False).execute()
    return jsonify({"chapters": result.data})
