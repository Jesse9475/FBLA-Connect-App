import os
import secrets

from flask import Flask, jsonify
from flask_limiter.errors import RateLimitExceeded
from flask_limiter.util import get_remote_address
from flask_cors import CORS

from fbla.api_utils import api_ok, api_error
from fbla.extensions import limiter   # shared Limiter instance

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - handled at runtime
    load_dotenv = None

from config import Config
from fbla.routes import (
    admin, announcements, auth, competitive_events, events, friends, hub,
    messages, org, otp, posts, uploads, users,
)


def create_app():
    if load_dotenv:
        load_dotenv()

    app = Flask(__name__)
    app.config.from_object(Config)

    # ── CORS ─────────────────────────────────────────────────────────────────
    # Allow mobile and web frontends to call the API. Mobile clients (Flutter
    # native) don't enforce CORS, so wildcard origins are safe — but we drop
    # `supports_credentials` because the CORS spec forbids combining it with
    # `*` (browsers reject the combo). If you need cookie-based auth, set
    # `CORS_ORIGINS` to an explicit comma-separated list and re-enable
    # supports_credentials.
    cors_origins_env = os.environ.get("CORS_ORIGINS", "*").strip()
    if cors_origins_env == "*":
        cors_resources = {
            r"/api/*": {"origins": "*"},
            r"/health": {"origins": "*"},
        }
        cors_supports_credentials = False
    else:
        origins_list = [o.strip() for o in cors_origins_env.split(",") if o.strip()]
        cors_resources = {
            r"/api/*": {"origins": origins_list},
            r"/health": {"origins": origins_list},
        }
        cors_supports_credentials = True

    CORS(
        app,
        resources=cors_resources,
        supports_credentials=cors_supports_credentials,
    )

    # ── Rate limiting ─────────────────────────────────────────────────────────
    # Key: IP + authenticated user_id (prevents one user hogging the quota
    # of another user sharing the same NAT IP).
    def _rate_limit_key():
        user_id = None
        try:
            from flask import g
            user_id = (g.get("auth") or {}).get("user", {}).get("id")
        except Exception:
            user_id = None
        return f"{get_remote_address()}:{user_id or 'anon'}"

    limiter._key_func = _rate_limit_key   # override with composite key
    limiter.init_app(app)

    # Global defaults — individual sensitive routes override these lower.
    app.config.setdefault("RATELIMIT_DEFAULT_LIMITS", ["60 per minute", "300 per hour"])
    app.config.setdefault("RATELIMIT_STORAGE_URI",    "memory://")

    @app.errorhandler(RateLimitExceeded)
    def _rate_limit_exceeded(exc):
        retry_after = getattr(exc, "retry_after", None)
        data = {}
        if retry_after is not None:
            data["retry_after"] = int(retry_after)
        return api_error("rate_limit_exceeded", status=429, data=data or None)

    # ── Secret key ───────────────────────────────────────────────────────────
    if not app.config.get("SECRET_KEY"):
        app.config["SECRET_KEY"] = secrets.token_hex(32)

    # ── Security headers ─────────────────────────────────────────────────────
    @app.after_request
    def _security_headers(response):
        # OWASP-recommended headers for REST APIs.
        response.headers["X-Content-Type-Options"]  = "nosniff"
        response.headers["X-Frame-Options"]         = "DENY"
        response.headers["Referrer-Policy"]         = "no-referrer"
        response.headers["X-XSS-Protection"]        = "0"          # disable legacy IE header; CSP is better
        response.headers["Cache-Control"]           = "no-store"   # prevent caching of API responses
        response.headers["Permissions-Policy"]      = "geolocation=(), microphone=(), camera=()"
        # Strict CSP for any embedded HTML response — prevents inline JS,
        # framing, and arbitrary fetch destinations. JSON responses ignore
        # CSP but it's free defense-in-depth for /admin_panel.html etc.
        response.headers["Content-Security-Policy"] = (
            "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
        )
        # Tell browsers to always upgrade to HTTPS once they've seen us.
        if not app.config.get("DEBUG"):
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return response

    # ── Blueprints ────────────────────────────────────────────────────────────
    app.register_blueprint(auth.bp,          url_prefix="/api")
    app.register_blueprint(otp.bp,           url_prefix="/api")
    app.register_blueprint(users.bp,         url_prefix="/api")
    app.register_blueprint(posts.bp,         url_prefix="/api")
    app.register_blueprint(messages.bp,      url_prefix="/api")
    app.register_blueprint(events.bp,        url_prefix="/api")
    app.register_blueprint(hub.bp,           url_prefix="/api")
    app.register_blueprint(uploads.bp,       url_prefix="/api")
    app.register_blueprint(admin.bp,         url_prefix="/api")
    app.register_blueprint(announcements.bp,         url_prefix="/api")
    app.register_blueprint(competitive_events.bp,   url_prefix="/api")
    app.register_blueprint(org.bp,                  url_prefix="/api")
    app.register_blueprint(friends.bp,              url_prefix="/api")

    # ── Global exception handler ────────────────────────────────────────────
    # Catches unhandled exceptions so the client always receives JSON
    # instead of Flask's default HTML error page.
    @app.errorhandler(Exception)
    def _unhandled_exception(exc):
        # Log full exception server-side, but never leak internal details
        # to clients in production (avoids exposing stack traces, SQL
        # fragments, file paths). In DEBUG, surface the message for
        # easier local development.
        app.logger.exception("Unhandled exception: %s", exc)
        if app.config.get("DEBUG"):
            return api_error(str(exc), status=500)
        return api_error("internal_error", status=500)

    @app.errorhandler(404)
    def _not_found(exc):
        return api_error("not_found", status=404)

    @app.errorhandler(405)
    def _method_not_allowed(exc):
        return api_error("method_not_allowed", status=405)

    # ── Health check ─────────────────────────────────────────────────────────
    @app.route("/health")
    def health():
        return api_ok(data={"status": "ok"}, status=200)

    return app
