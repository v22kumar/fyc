#!/usr/bin/env bash
#
# Run the browser end-to-end test of the web chess board.
#
# Boots a throwaway backend and a production build of the site, seeds a game,
# then drives a real Chromium against both. Everything it starts, it stops.
#
#   scripts/e2e/run_web_e2e.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
API_PORT="${E2E_API_PORT:-8000}"
WEB_PORT="${E2E_WEB_PORT:-4321}"

cleanup() {
  [[ -n "${API_PID:-}" ]] && kill "$API_PID" 2>/dev/null || true
  [[ -n "${WEB_PID:-}" ]] && kill "$WEB_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# A scratch database per run: the test resigns games and moves pieces, and must
# never be pointed at anything real.
export DATABASE_URL="sqlite:///$WORK/e2e.db"
export TESTING=false
export SCHEDULER_ENABLED=false
# Skip the blood-donor CSV import: thousands of rows, and it holds the SQLite
# write lock long enough to lock out the game we are about to seed.
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

echo "→ seeding a game"
CFG="$(cd "$ROOT" && python scripts/e2e/seed_e2e_games.py --games 1)"
ORG_ID="$(python -c 'import json,sys; print(json.loads(sys.argv[1])["org_id"])' "$CFG")"

echo "→ building the site against the local backend"
export PUBLIC_API_BASE="http://127.0.0.1:$API_PORT"
export PUBLIC_DEFAULT_ORG_ID="$ORG_ID"
(cd "$ROOT/web" && npm run build >"$WORK/build.log" 2>&1) || {
  echo "web build failed:"; tail -40 "$WORK/build.log"; exit 1; }

echo "→ serving the site on :$WEB_PORT"
# A plain static server over the build output, rather than `astro preview`:
# the build is static anyway, and this has no dependency that can fail to
# resolve on a machine that is not this one. Directory requests like /play/
# resolve to play/index.html, which is the layout astro build produces.
(cd "$ROOT/web/dist" && python -m http.server "$WEB_PORT" --bind 127.0.0.1) \
  >"$WORK/web.log" 2>&1 &
WEB_PID=$!
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$WEB_PORT/" >/dev/null && break
  sleep 1
done
# Fail here rather than letting Chromium report a connection refused: the
# earlier version carried on and blamed the browser for a dead server.
curl -sf "http://127.0.0.1:$WEB_PORT/" >/dev/null || {
  echo "the site never came up:"; tail -40 "$WORK/web.log"; exit 1; }

echo "→ driving Chromium"
export E2E_WEB_BASE="http://127.0.0.1:$WEB_PORT"
export E2E_WS_BASE="ws://127.0.0.1:$API_PORT"
cd "$ROOT/web" && node e2e/play_page.test.mjs "$CFG"
