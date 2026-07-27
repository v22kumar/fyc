# Production chess load test — runbook

Validate the **deployed** FYC Connect server (Fly.io + PostgreSQL + Valkey) with the
same 35-game test used locally. Run this **from your machine** (it has network access
to prod and `flyctl`; the CI sandbox does not).

Prod Postgres is private and Fly secrets are write-only, so seeding runs **inside the
container** (which already has `DATABASE_URL` + `SECRET_KEY`), and the WebSocket load
runs from your laptop.

## Prereqs (laptop)
```bash
pip install websockets chess
# flyctl already installed & logged in
```

## 0. Get an admin JWT (for metrics + backend confirmation)
> `flyctl ssh console -C` runs ONE binary — no shell, so no `cd` / `&&`. Use the
> absolute script path. Connection chatter goes to stderr, so `2>/dev/null | tail -1`
> grabs just the payload.

```bash
export ADMIN=$(flyctl ssh console -a fyc-backend -C \
  "python /app/scripts/mint_admin_token.py" 2>/dev/null | tail -1)
echo "$ADMIN"     # should be a long eyJ... JWT
```

## 1. Confirm the backend is Postgres + Redis
```bash
curl -s -H "Authorization: Bearer $ADMIN" \
  https://fyc-backend.fly.dev/api/v1/system/health | python3 -m json.tool
```
Expect: `"db_dialect": "postgresql"` and `"cache": "valkey/redis connected"`.
If you see `sqlite` or `in-memory fallback`, **stop** — prod isn't on Postgres/Redis
(check `DATABASE_URL` / `VALKEY_URL` secrets) before load-testing.

## 2. Seed 35 games INSIDE the container (prod Postgres)
```bash
flyctl ssh console -a fyc-backend -C \
  "python /app/scripts/chess_load_test.py --seed-only --games 35" 2>/dev/null | tail -1 > seed.json
python3 -c "import json;d=json.load(open('seed.json'));print('org',d['org_id'],'games',len(d['games']))"
```

## 3. Run the WebSocket load from your laptop → prod
```bash
python scripts/chess_load_test.py --run-only \
  --seed-file seed.json \
  --target wss://fyc-backend.fly.dev \
  --admin-token "$ADMIN" \
  --spectators 2 --plies 30 --reconnects 5
```
The report prints throughput, move RTT p50/p95/max, reconnects, errors, **GAMES
PAUSED**, and sampled server host-CPU% + process-RSS-MB (via `/system/health`).

## 4. Clean up the throwaway data (in the container)
```bash
ORG=$(python3 -c "import json;print(json.load(open('seed.json'))['org_id'])")
flyctl ssh console -a fyc-backend -C \
  "python /app/scripts/chess_load_test.py --cleanup-only --org $ORG"
```

## 5. (Optional) Cross-check CPU/mem from Fly
```bash
flyctl status -a fyc-backend
flyctl metrics -a fyc-backend      # or the Fly Grafana dashboard
```

## Pass criteria (tournament-ready evidence)
- `db_dialect = postgresql`, `cache = valkey/redis connected`
- **GAMES PAUSED = 0** (server-observed 0) — no persistence divergence
- move RTT p50/p95 in the same ballpark as local (Postgres should be **equal or
  better** than local SQLite, whose ~1s max tail came from single-writer locking)
- reconnects all handled, errors/timeouts ≈ 0
- server CPU stays well under saturation and RSS is stable (no leak/climb)

If prod passes with similar latency and no failures, that's strong evidence it's
ready to host a real FYC tournament.
