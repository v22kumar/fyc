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

# `( … ) &` makes $! the subshell, not the server, so killing it can leave
# uvicorn and http.server orphaned on their ports — and the next run fails with
# address-in-use, blaming something unrelated. `exec` below makes the PID the
# real process; the process-group kill is the belt to that braces.
cleanup() {
  for pid in "${API_PID:-}" "${WEB_PID:-}"; do
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
    kill -- "-$pid" 2>/dev/null || true
  done
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
(cd "$ROOT/backend" && exec python3 -m uvicorn app.main:app --port "$API_PORT" --log-level warning) \
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
(cd "$ROOT/web/dist" && exec python3 -m http.server "$WEB_PORT" --bind 127.0.0.1) \
  >"$WORK/web.log" 2>&1 &
WEB_PID=$!
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$WEB_PORT/" >/dev/null && break
  sleep 1
done
curl -sf "http://127.0.0.1:$WEB_PORT/" >/dev/null || {
  echo "the site never came up:"; tail -40 "$WORK/web.log"; exit 1; }
# The pages under test, not just the root: if astro ever built file-style
# output there would be no /finance/ directory, and the only symptom would be a
# selector that never appears.
curl -sf "http://127.0.0.1:$WEB_PORT/finance/" >/dev/null || {
  echo "/finance did not resolve — check the astro build format"; exit 1; }

echo "→ driving Chromium"
export E2E_WEB_BASE="http://127.0.0.1:$WEB_PORT"
cd "$ROOT/web"
# The server logs go with $WORK on exit, so a failed assertion sitting on top of
# a backend 500 would show only the browser half of the story.
run() {
  if ! "$@"; then
    echo "--- backend log ---"; tail -80 "$WORK/api.log" || true
    echo "--- web log ---";     tail -40 "$WORK/web.log" || true
    exit 1
  fi
}
run node e2e/finance_page.test.mjs "$CFG"

# The way back. The finance pages depend on ?next returning the member to the
# page they were sent from, which makes that parameter worth its own test.
run node e2e/login_next_test.mjs
