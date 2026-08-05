#!/usr/bin/env bash
#
# Run the Flutter integration tests against a real backend.
#
# These drive the real widget tree — real gesture arena, real timers, real
# WebSocket — with the opponent playing from the other side of the wire. It is
# as close to a device test as can be reached without hardware, and it is what
# caught a move-encoding bug that every unit test structurally could not.
#
#   scripts/e2e/run_mobile_e2e.sh
#
# Requires the Linux desktop toolchain (ninja-build, libgtk-3-dev, clang).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
API_PORT="${E2E_API_PORT:-8000}"

cleanup() {
  [[ -n "${API_PID:-}" ]] && kill "$API_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

export DATABASE_URL="sqlite:///$WORK/e2e.db"
export SCHEDULER_ENABLED=false
export SKIP_BULK_SEED=1
export SECRET_KEY="${SECRET_KEY:-e2e-secret-not-for-production}"
export FIRST_SUPERADMIN_PASSWORD="${FIRST_SUPERADMIN_PASSWORD:-e2e-not-a-real-password}"

echo "→ starting backend on :$API_PORT"
(cd "$ROOT/backend" && python -m uvicorn app.main:app --port "$API_PORT" --log-level warning) \
  >"$WORK/api.log" 2>&1 &
API_PID=$!

for _ in $(seq 1 60); do
  curl -sf "http://127.0.0.1:$API_PORT/api/health" >/dev/null && break
  sleep 1
done
curl -sf "http://127.0.0.1:$API_PORT/api/health" >/dev/null || {
  echo "backend never came up:"; tail -40 "$WORK/api.log"; exit 1; }

# One board per test that needs a fresh game — a test that resigns cannot hand
# the same game to the next one.
echo "→ seeding boards"
CFG="$(cd "$ROOT" && python scripts/e2e/seed_e2e_games.py --games 6)"
read -r GAME_IDS TOKEN OPP_TOKEN <<<"$(python - "$CFG" <<'PY'
import json, sys
c = json.loads(sys.argv[1])
print(",".join(c["game_ids"]), c["web_token"], c["opp_token"])
PY
)"

echo "→ running the integration suite on the Linux embedder"
cd "$ROOT/mobile"

# The desktop embedder needs a display even though nobody is looking at it;
# without one the app builds fine and then fails to launch.
RUNNER=()
if [[ -z "${DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null || {
    echo "no DISPLAY and no xvfb-run — install xvfb or run with a display"; exit 1; }
  RUNNER=(xvfb-run -a --server-args="-screen 0 1280x1024x24")
fi

"${RUNNER[@]}" flutter test integration_test/chess_live_game_test.dart -d linux \
  --dart-define=GAME_IDS="$GAME_IDS" \
  --dart-define=TOKEN="$TOKEN" \
  --dart-define=OPP_TOKEN="$OPP_TOKEN" \
  --dart-define=WS_BASE="ws://127.0.0.1:$API_PORT" \
  --dart-define=API_BASE_URL="http://127.0.0.1:$API_PORT"
