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

from fbla import create_app


app = create_app()

# Use 5001 by default to avoid conflict with macOS AirPlay on port 5000
PORT = int(os.environ.get("FLASK_RUN_PORT", 5001))


def _find_port(start: int, max_tries: int = 10) -> int:
    import socket
    for i in range(max_tries):
        p = start + i
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("", p))
                return p
        except OSError:
            continue
    return start  # fallback, will error with a clear message


if __name__ == "__main__":
    port = _find_port(PORT)
    if port != PORT:
        print(f"Port {PORT} in use, using {port} instead.", file=sys.stderr)
    print(f"FBLA Connect backend → http://0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port, debug=app.config.get("DEBUG", False))
