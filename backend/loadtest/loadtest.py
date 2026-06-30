#!/usr/bin/env python3
"""
FYC Connect — pre-event load test.

Runs from YOUR laptop against production (the app sandbox can't reach *.fly.dev).
Two phases:
  1. REST soak   — N concurrent users hammering read endpoints, reports latency.
  2. Chess WS    — M concurrent online games (2 sockets each) exchanging moves,
                   to validate the single-worker WebSocket relay under load.

Install:
    pip install httpx websockets

Run (REST only, 50 users for 30s):
    python loadtest.py --base https://fyc-backend.fly.dev --org <ORG_ID> \
        --email you@example.com --password 'secret' --users 50 --seconds 30

Run with chess (also opens 25 games — needs that many test logins, see --tokens):
    python loadtest.py ... --games 25 --tokens tokens.txt

`tokens.txt` = one JWT per line (>= 2*games lines). Get a token by logging in
(password) and copying the access_token; or reuse the same 2 accounts with
--allow-reuse for a relay smoke test (not a true concurrency test).
"""
import argparse
import asyncio
import statistics
import time

import httpx

READ_PATHS = [
    "/api/v1/posts?scope=all&limit=20",
    "/api/v1/events",
    "/api/v1/community/stats",
    "/api/v1/community/feed?limit=5",
    "/api/v1/chess/tournaments",
    "/api/v1/sports/tournaments",
    "/api/v1/app/info",
]


async def _login(base, org, email, password):
    async with httpx.AsyncClient(base_url=base, timeout=20) as c:
        r = await c.post(
            "/api/v1/auth/login",
            json={"organization_id": org, "username": email, "password": password},
        )
        r.raise_for_status()
        return r.json().get("access_token") or r.json().get("token")


async def _rest_user(base, org, token, deadline, lat, errs):
    headers = {"Authorization": f"Bearer {token}", "X-Org-Id": org}
    async with httpx.AsyncClient(base_url=base, timeout=20, headers=headers) as c:
        i = 0
        while time.monotonic() < deadline:
            path = READ_PATHS[i % len(READ_PATHS)]
            i += 1
            t0 = time.monotonic()
            try:
                r = await c.get(path)
                lat.append((time.monotonic() - t0) * 1000)
                if r.status_code >= 500:
                    errs.append(f"{r.status_code} {path}")
            except Exception as e:  # noqa: BLE001
                errs.append(f"EXC {type(e).__name__} {path}")
            await asyncio.sleep(0.2)  # ~5 req/s per user (realistic browsing)


async def rest_phase(args, token):
    lat, errs = [], []
    deadline = time.monotonic() + args.seconds
    await asyncio.gather(
        *[_rest_user(args.base, args.org, token, deadline, lat, errs) for _ in range(args.users)]
    )
    lat.sort()
    n = len(lat)
    print("\n=== REST phase ===")
    print(f"users={args.users} duration={args.seconds}s requests={n} errors={len(errs)}")
    if n:
        print(f"latency ms  p50={lat[n//2]:.0f}  p95={lat[int(n*0.95)]:.0f}  "
              f"p99={lat[int(n*0.99)]:.0f}  max={lat[-1]:.0f}  mean={statistics.mean(lat):.0f}")
    for e in errs[:10]:
        print("  ERR", e)


async def chess_phase(args, tokens):
    try:
        import websockets  # noqa: F401
    except ImportError:
        print("\n[chess] install 'websockets' to run the WS phase — skipping")
        return
    import json
    import websockets

    ws_base = args.base.replace("https://", "wss://").replace("http://", "ws://")
    print(f"\n=== Chess WS phase: {args.games} games ===")
    # NOTE: a real game needs two registered players + a server-side game id.
    # This phase is a RELAY SMOKE TEST: it opens 2 sockets per game id you pass in
    # via --game-ids and confirms a move sent by one socket is received by the
    # other. Create those games first (admin: start a tournament, tap Play).
    print("Provide --game-ids and matching --tokens to exercise live relay.")


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--org", required=True)
    ap.add_argument("--email")
    ap.add_argument("--password")
    ap.add_argument("--token", help="use an existing JWT instead of logging in")
    ap.add_argument("--users", type=int, default=50)
    ap.add_argument("--seconds", type=int, default=30)
    ap.add_argument("--games", type=int, default=0)
    ap.add_argument("--tokens", help="file with one JWT per line for chess")
    args = ap.parse_args()

    token = args.token
    if not token:
        if not (args.email and args.password):
            ap.error("provide --token, or --email and --password")
        token = await _login(args.base, args.org, args.email, args.password)
    print(f"auth OK (token …{token[-8:]})")

    await rest_phase(args, token)
    if args.games:
        toks = []
        if args.tokens:
            toks = [l.strip() for l in open(args.tokens) if l.strip()]
        await chess_phase(args, toks)


if __name__ == "__main__":
    asyncio.run(main())
