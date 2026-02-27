from flask import Blueprint, current_app, render_template


bp = Blueprint("web", __name__)


@bp.route("/")
def index():
    return render_template(
        "index.html",
        supabase_url=current_app.config.get("SUPABASE_URL"),
        supabase_anon_key=current_app.config.get("SUPABASE_ANON_KEY"),
    )


@bp.route("/dashboard")
def dashboard():
    return render_template(
        "dashboard.html",
        supabase_url=current_app.config.get("SUPABASE_URL"),
        supabase_anon_key=current_app.config.get("SUPABASE_ANON_KEY"),
    )
