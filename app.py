"""
FBLA Connect — Flask backend API.
Run: python app.py   (uses port 5001, or next free port if taken)
"""
import os
import sys

# If run with system Python (no venv), re-exec with project venv so deps are available
if __name__ == "__main__":
    try:
        import flask_limiter  # noqa: F401
    except ImportError:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        venv_python = os.path.join(script_dir, ".venv", "bin", "python")
        if os.path.isfile(venv_python):
            os.execv(venv_python, [venv_python] + sys.argv)
        else:
            print("Missing deps. Run: python3 -m venv .venv && .venv/bin/pip install -r requirements.txt", file=sys.stderr)
            sys.exit(1)

# ── Load .env BEFORE importing anything from fbla ────────────────────────────
# `config.py` reads env vars at class-definition time (class attrs like
# SUPABASE_JWT_SECRET = os.environ.get(...) run the instant the module is
# imported). If load_dotenv() runs after that import — as it used to, inside
# create_app() — every Supabase config value is frozen at None, and every
# authenticated request fails with "invalid_token" + a misleading
# `jwt_secret_set=False` log line even though the secret is right there in
# .env. Loading .env here, at the top of the entry script, is the only
# reliable fix.
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))
except ImportError:
    # python-dotenv missing — env vars must come from the real environment.
    pass

from fbla import create_app


app = create_app()

# Port 5050 — avoids macOS AirPlay (5000), common dev servers (5001/5002),
# and is consistent with the Flutter app's config.dart default.
PORT = int(os.environ.get("FLASK_RUN_PORT", 5050))

if __name__ == "__main__":
    print(f"FBLA Connect backend → http://localhost:{PORT}/api")
    app.run(host="0.0.0.0", port=PORT, debug=app.config.get("DEBUG", False))
