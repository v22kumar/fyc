#!/usr/bin/env bash
#
# Run the browser end-to-end test of the finance pages.
#
# Boots a throwaway backend and a production build of the site, seeds a club
# official and an ordinary member, then drives a real Chromium through the whole
# thing: create the collection, appoint a treasurer, record money, hit both
# duplicate guards, go offline and come back, and verify.
#
#   scripts/e2e/run_finance_e2e.sh
#
# Everything it starts, it stops.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
API_PORT="${E2E_API_PORT:-8011}"
WEB_PORT="${E2E_WEB_PORT:-4331}"

cleanup() {
  [[ -n "${API_PID:-}" ]] && kill "$API_PID" 2>/dev/null || true
  [[ -n "${WEB_PID:-}" ]] && kill "$WEB_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# A scratch database per run. This test records money; it must never be
# pointed at anything real.
export DATABASE_URL="sqlite:///$WORK/finance-e2e.db"
export TESTING=false
export SCHEDULER_ENABLED=false
export SKIP_BULK_SEED=1
export SECRET_KEY="${SECRET_KEY:-e2e-secret-not-for-production}"
export FIRST_SUPERADMIN_PASSWORD="${FIRST_SUPERADMIN_PASSWORD:-e2e-not-a-real-password}"

echo "→ starting backend on :$API_PORT"
(cd "$ROOT/backend" && python3 -m uvicorn app.main:app --port "$API_PORT" --log-level warning) \
  >"$WORK/api.log" 2>&1 &
API_PID=$!

for _ in $(seq 1 60); do
  curl -sf "http://127.0.0.1:$API_PORT/api/health" >/dev/null && break
  sleep 1
done
curl -sf "http://127.0.0.1:$API_PORT/api/health" >/dev/null || {
  echo "backend never came up:"; tail -40 "$WORK/api.log"; exit 1; }

echo "→ seeding an official and an ordinary member"
CFG="$(cd "$ROOT" && python3 scripts/e2e/seed_finance_e2e.py)"
ORG_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["org_id"])' "$CFG")"

echo "→ building the site against the local backend"
export PUBLIC_API_BASE="http://127.0.0.1:$API_PORT"
export PUBLIC_DEFAULT_ORG_ID="$ORG_ID"
(cd "$ROOT/web" && npm run build >"$WORK/build.log" 2>&1) || {
  echo "web build failed:"; tail -40 "$WORK/build.log"; exit 1; }

echo "→ serving the site on :$WEB_PORT"
(cd "$ROOT/web/dist" && python3 -m http.server "$WEB_PORT" --bind 127.0.0.1) \
  >"$WORK/web.log" 2>&1 &
WEB_PID=$!
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$WEB_PORT/" >/dev/null && break
  sleep 1
done
curl -sf "http://127.0.0.1:$WEB_PORT/" >/dev/null || {
  echo "the site never came up:"; tail -40 "$WORK/web.log"; exit 1; }

echo "→ driving Chromium"
export E2E_WEB_BASE="http://127.0.0.1:$WEB_PORT"
cd "$ROOT/web" && node e2e/finance_page.test.mjs "$CFG"

# The way back. The finance pages depend on ?next returning the member to the
# page they were sent from, which makes that parameter worth its own test.
node e2e/login_next_test.mjs
