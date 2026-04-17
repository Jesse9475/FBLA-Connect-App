#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  FBLA Connect — one-shot dev runner
#
#  Starts the Flask backend in the background, waits for it to be reachable,
#  then starts Flutter web with the right BACKEND_URL baked in. Ctrl+C kills
#  both cleanly.
#
#  USAGE
#    # local only (laptop, web target)
#    ./dev.sh
#
#    # phone-via-tunnel (ngrok / cloudflared / vscode port-forward):
#    #   1. Start your tunnel for port 5050 first, e.g.
#    #        ngrok http 5050
#    #   2. Pass the public URL so Flutter web knows where to call:
#    BACKEND_URL="https://abc123.ngrok-free.app/api" ./dev.sh
#
#    # iPhone plugged in via Xcode / free Apple ID:
#    #   Auto-detects your Mac's LAN IP so the phone can reach Flask
#    #   over Wi-Fi. Mac + iPhone must be on the same Wi-Fi network.
#    MODE=ios ./dev.sh
#    # or pick a specific device:
#    MODE=ios FLUTTER_DEVICE_ID="00008120-..." ./dev.sh
#
#    # force a specific Flutter web port (default 3000):
#    FLUTTER_WEB_PORT=8080 ./dev.sh
#
#  ENV VARS
#    MODE               'web' (default) or 'ios'. In ios mode the script auto-
#                       detects your Mac's LAN IP and bakes that into
#                       BACKEND_URL so the iPhone can reach Flask over Wi-Fi.
#    BACKEND_URL        Full /api URL the Flutter app will POST/GET against.
#                       Overrides the auto-detected one. Defaults to
#                       http://localhost:5050/api in web mode.
#    FLASK_RUN_PORT     Port Flask binds to. Defaults to 5050.
#    FLUTTER_WEB_PORT   Port Flutter web dev server binds to (web mode only).
#                       Defaults to 3000.
#    FLUTTER_WEB_HOST   Host Flutter binds to (web mode only). Default 0.0.0.0
#                       so your phone / a tunnel can reach it.
#    FLUTTER_DEVICE_ID  Specific device id for `flutter run -d` (ios mode).
#                       Leave unset to let Flutter pick.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="${MODE:-web}"
FLASK_RUN_PORT="${FLASK_RUN_PORT:-5050}"
FLUTTER_WEB_PORT="${FLUTTER_WEB_PORT:-3000}"
FLUTTER_WEB_HOST="${FLUTTER_WEB_HOST:-0.0.0.0}"
FLUTTER_DEVICE_ID="${FLUTTER_DEVICE_ID:-}"

# Auto-detect Mac's LAN IP for iOS mode so the phone can reach Flask over
# Wi-Fi. en0 is the default on modern Macs (Wi-Fi). If that doesn't
# resolve, try en1 (sometimes Wi-Fi on older Macs) then route lookup.
detect_lan_ip() {
  local ip
  ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
  if [[ -z "$ip" ]]; then
    ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "$ip" ]]; then
    ip="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}' \
         | xargs -I{} ipconfig getifaddr {} 2>/dev/null || true)"
  fi
  echo "$ip"
}

# Default BACKEND_URL: always prefer the Mac's LAN IP so a browser on a
# phone (or a native iOS build) on the same Wi-Fi can reach Flask. Falls
# back to localhost only if we can't detect a LAN IP (e.g. offline).
# Explicit BACKEND_URL env var always wins.
if [[ -z "${BACKEND_URL:-}" ]]; then
  LAN_IP="$(detect_lan_ip)"
  if [[ -n "$LAN_IP" ]]; then
    BACKEND_URL="http://${LAN_IP}:${FLASK_RUN_PORT}/api"
  elif [[ "$MODE" == "ios" ]]; then
    # iOS builds can't use localhost at all — hard fail.
    echo "dev.sh: couldn't auto-detect your Mac's LAN IP. Pass one explicitly:"
    echo "  BACKEND_URL=http://192.168.x.x:$FLASK_RUN_PORT/api MODE=ios ./dev.sh"
    exit 1
  else
    BACKEND_URL="http://localhost:${FLASK_RUN_PORT}/api"
  fi
fi

FLUTTER_APP_DIR="$SCRIPT_DIR/flutter/fbla_connect_app"
VENV_PY="$SCRIPT_DIR/.venv/bin/python"

# ── Pretty prefixed logs so Flask + Flutter output don't tangle ───────────
c_flask='\033[0;35m'   # magenta
c_flutter='\033[0;36m' # cyan
c_reset='\033[0m'
log()   { printf '%b[dev]%b %s\n' '\033[1;33m' "$c_reset" "$*"; }
logf()  { printf '%b[flask]%b %s\n' "$c_flask"   "$c_reset" "$*"; }
logfl() { printf '%b[flutter]%b %s\n' "$c_flutter" "$c_reset" "$*"; }

# ── Sanity: venv + flutter + flask port free ──────────────────────────────
if [[ ! -x "$VENV_PY" ]]; then
  log "no venv found. create it with:"
  log "  python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  log "flutter not on PATH — install Flutter or add it to PATH."
  exit 1
fi

if lsof -nP -iTCP:"$FLASK_RUN_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  log "port $FLASK_RUN_PORT is already in use — kill the old server and retry."
  log "  lsof -nP -iTCP:$FLASK_RUN_PORT -sTCP:LISTEN"
  exit 1
fi

# ── Cleanup: kill both children on any exit ───────────────────────────────
FLASK_PID=""
FLUTTER_PID=""
cleanup() {
  log "shutting down…"
  if [[ -n "$FLUTTER_PID" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    kill "$FLUTTER_PID" 2>/dev/null || true
  fi
  if [[ -n "$FLASK_PID" ]] && kill -0 "$FLASK_PID" 2>/dev/null; then
    kill "$FLASK_PID" 2>/dev/null || true
    # Give Flask ~2s to exit, then force
    for _ in 1 2 3 4; do
      kill -0 "$FLASK_PID" 2>/dev/null || break
      sleep 0.5
    done
    kill -9 "$FLASK_PID" 2>/dev/null || true
  fi
  log "bye."
}
trap cleanup EXIT INT TERM

# ── Start Flask ───────────────────────────────────────────────────────────
log "starting Flask on :$FLASK_RUN_PORT (bind 0.0.0.0, reachable from LAN/tunnel)"
FLASK_RUN_PORT="$FLASK_RUN_PORT" "$VENV_PY" app.py 2>&1 \
  | sed -u "s/^/$(printf '%b[flask]%b ' "$c_flask" "$c_reset")/" &
FLASK_PID=$!

# ── Wait for Flask to actually answer ─────────────────────────────────────
#
# We don't care what status code Flask returns — a 404 from the root path
# still proves the server is alive and accepting connections, which is
# all we need before handing off to Flutter. `curl -sf` was wrong for
# that because it treats 4xx as failure; we use `-w "%{http_code}"`
# instead and accept anything other than 000 (connection refused).
log "waiting for Flask to come up…"
for i in $(seq 1 40); do
  # Curl writes "%{http_code}" (3 digits or "000" on connect failure) even
  # when its exit code is non-zero — so we suppress its exit with `|| true`
  # instead of `|| echo 000`, which used to double-print the code.
  code=$(curl -s -o /dev/null -m 1 -w "%{http_code}" \
         "http://localhost:${FLASK_RUN_PORT}/" 2>/dev/null || true)
  if [[ -n "$code" && "$code" != "000" ]]; then
    log "Flask is up (root returned HTTP $code)."
    break
  fi
  if ! kill -0 "$FLASK_PID" 2>/dev/null; then
    log "Flask exited before becoming ready — check the [flask] log above."
    exit 1
  fi
  sleep 0.5
  if [[ $i -eq 40 ]]; then
    log "Flask didn't respond in 20s. Continuing anyway — check the [flask] log."
  fi
done

# ── Start Flutter (web or iOS depending on MODE) ──────────────────────────
log "BACKEND_URL = $BACKEND_URL"
cd "$FLUTTER_APP_DIR"

if [[ "$MODE" == "ios" ]]; then
  # ── Preflight: is there actually an iOS device Flutter can see? ─────
  # `flutter run -d ios` silently fails if nothing's attached, which used
  # to leave people staring at "still broken on my phone" while dev.sh
  # claimed everything was fine. Check first and give a real error.
  log "looking for a connected iOS device…"
  DEVICE_LINE=""
  if [[ -n "$FLUTTER_DEVICE_ID" ]]; then
    DEVICE_LINE="$FLUTTER_DEVICE_ID"
  else
    # flutter devices output looks like:
    #   "Surya's iPhone (mobile) • 00008120-xxxx • ios • iOS 18.1"
    # we grab the first row with "• ios •" (physical iOS, NOT simulator)
    DEVICE_LINE=$(flutter devices --machine 2>/dev/null \
      | grep -Eo '"id":"[^"]+","[^"]*"[^}]*"targetPlatform":"ios"' \
      | head -n1 \
      | sed -E 's/.*"id":"([^"]+)".*/\1/') || true

    # Fallback parser in case --machine output shape differs:
    if [[ -z "$DEVICE_LINE" ]]; then
      DEVICE_LINE=$(flutter devices 2>/dev/null \
        | awk -F'•' '/• ios •/ && !/simulator/i {gsub(/^ +| +$/,"",$2); print $2; exit}')
    fi
  fi

  if [[ -z "$DEVICE_LINE" ]]; then
    log "❌  No physical iPhone/iPad showed up in \`flutter devices\`."
    log ""
    log "   To fix:"
    log "     1. Plug the iPhone into your Mac with a data-capable cable."
    log "     2. Unlock the phone. If prompted, tap 'Trust this computer'."
    log "     3. Open Xcode once and make sure Signing → Team is set (free Apple ID)."
    log "     4. Run:  flutter devices     (you should see your iPhone listed)"
    log "     5. Then re-run:  MODE=ios ./dev.sh"
    log ""
    log "   If you already installed the app from a previous Xcode run and are"
    log "   opening its icon: that build has the OLD BACKEND_URL baked in and"
    log "   won't work. You must re-install via \`flutter run\` or Xcode with the"
    log "   right --dart-define so BACKEND_URL=$BACKEND_URL is baked in."
    exit 1
  fi

  log "target iOS device: $DEVICE_LINE"
  flutter run \
    -d "$DEVICE_LINE" \
    --dart-define=BACKEND_URL="$BACKEND_URL" \
    2>&1 | sed -u "s/^/$(printf '%b[flutter]%b ' "$c_flutter" "$c_reset")/" &
  FLUTTER_PID=$!
else
  log "starting Flutter web on $FLUTTER_WEB_HOST:$FLUTTER_WEB_PORT"
  log "   laptop:   http://localhost:$FLUTTER_WEB_PORT"
  log "   phone:    http://<your-laptop-LAN-ip>:$FLUTTER_WEB_PORT (or your tunnel URL)"
  flutter run \
    -d web-server \
    --web-hostname "$FLUTTER_WEB_HOST" \
    --web-port "$FLUTTER_WEB_PORT" \
    --dart-define=BACKEND_URL="$BACKEND_URL" \
    2>&1 | sed -u "s/^/$(printf '%b[flutter]%b ' "$c_flutter" "$c_reset")/" &
  FLUTTER_PID=$!
fi

# ── Wait on whichever child exits first, then cleanup kicks in ────────────
#
# macOS ships bash 3.2 which does NOT have `wait -n`. We poll instead:
# every second, check if either child is still alive; exit when one has
# died (the trap will then tear the other one down).
while kill -0 "$FLASK_PID" 2>/dev/null && kill -0 "$FLUTTER_PID" 2>/dev/null; do
  sleep 1
done
