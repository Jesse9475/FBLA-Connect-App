"""
Shared Flask extensions.

Instantiated here so blueprints can import and decorate routes with
@limiter.limit(...) without circular-import issues.  Call init_app(app)
inside create_app() to attach them to the actual Flask application.
"""

from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

# ── Rate limiter ────────────────────────────────────────────────────────────
# Key function is overridden in create_app so that authenticated requests
# are keyed by IP + user_id instead of IP alone — preventing one bad actor
# from consuming another user's quota.
limiter = Limiter(key_func=get_remote_address)
