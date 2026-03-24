import secrets

from flask import Flask, jsonify
from flask_limiter import Limiter
from flask_limiter.errors import RateLimitExceeded
from flask_limiter.util import get_remote_address
from flask_cors import CORS

from fbla.api_utils import api_ok, api_error

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - handled at runtime
    load_dotenv = None

from config import Config
from fbla.routes import admin, announcements, auth, events, hub, messages, org, posts, uploads, users


def create_app():
    if load_dotenv:
        load_dotenv()

    app = Flask(__name__)
    app.config.from_object(Config)

    # Allow mobile and web frontends to call the API.
    # For simplicity we allow all origins during development.
    CORS(
        app,
        resources={r"/api/*": {"origins": "*"}, r"/health": {"origins": "*"}},
        supports_credentials=True,
    )

    # Rate limiting: use IP + user id when available.
    def _rate_limit_key():
        user_id = None
        try:
            from flask import g

            user_id = (g.get("auth") or {}).get("user", {}).get("id")
        except Exception:
            user_id = None
        return f"{get_remote_address()}:{user_id or 'anon'}"

    limiter = Limiter(
        key_func=_rate_limit_key,
        default_limits=["50 per minute", "200 per hour"],
        storage_uri=app.config.get("RATELIMIT_STORAGE_URI", "memory://"),
    )
    limiter.init_app(app)

    @app.errorhandler(RateLimitExceeded)
    def _rate_limit_exceeded(_):
        return api_error("rate_limit_exceeded", status=429)

    if not app.config.get("SECRET_KEY"):
        # Generate a transient dev key; set SECRET_KEY in env for production.
        app.config["SECRET_KEY"] = secrets.token_hex(32)

    @app.after_request
    def _security_headers(response):
        # OWASP-recommended security headers for APIs.
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response

    app.register_blueprint(auth.bp, url_prefix="/api")
    app.register_blueprint(users.bp, url_prefix="/api")
    app.register_blueprint(posts.bp, url_prefix="/api")
    app.register_blueprint(messages.bp, url_prefix="/api")
    app.register_blueprint(events.bp, url_prefix="/api")
    app.register_blueprint(hub.bp, url_prefix="/api")
    app.register_blueprint(uploads.bp, url_prefix="/api")
    app.register_blueprint(admin.bp, url_prefix="/api")
    app.register_blueprint(announcements.bp, url_prefix="/api")
    app.register_blueprint(org.bp, url_prefix="/api")

    @app.route("/health")
    def health():
        return api_ok(data={"status": "ok"}, status=200)

    return app
