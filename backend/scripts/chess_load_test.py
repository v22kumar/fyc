#!/usr/bin/env python3
"""Concurrent chess load test (Phase 3 of the hardening sprint).

Drives N simultaneous online games (2 real WebSocket players each) plus spectators
plus mid-game reconnects against a live server, and reports throughput, move
round-trip latency, and any persistence failures (game_paused).

Self-contained: it seeds an org + players + games directly into the DB, mints
JWTs, boots a uvicorn subprocess against the SAME database, runs the async
clients, then tears everything down.

    python scripts/chess_load_test.py --games 35 --spectators 2 --plies 30 --reconnects 5

Run locally it uses SQLite — the PESSIMISTIC case for the move-persist path
(single writer). Surviving it means Postgres (row-level locking) will do better.
Point --db at a Postgres URL to measure the real target.
"""
import argparse
import asyncio
import json
import os
import subprocess
import sys
import time
import uuid
from statistics import mean

# Make `app` importable when run as scripts/chess_load_test.py from backend/.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ── Env must be set BEFORE importing app modules (settings read env at import) ──
_DEFAULT_DB = f"sqlite:////tmp/chess_loadtest_{uuid.uuid4().hex[:8]}.db"


def _pctile(values, p):
    if not values:
        return 0.0
    s = sorted(values)
    k = int(round((p / 100.0) * (len(s) - 1)))
    return s[k]


async def _wait_health(base, timeout=30):
    import urllib.request
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"{base}/api/health", timeout=2) as r:
                if r.status == 200:
                    return True
        except Exception:
            await asyncio.sleep(0.4)
    return False


async def _play(ws_base, game_id, token, color, plies, metrics, reconnect_at=None):
    """One player: connect, and whenever it is our turn push a random legal move,
    measuring send→own-echo latency. Optionally drop + reconnect once mid-game."""
    import chess
    import websockets

    uri = f"{ws_base}/api/v1/chess/games/{game_id}/ws?token={token}"
    is_white = color == "white"
    board = chess.Board()
    awaiting_echo = False
    send_ts = None
    did_reconnect = False

    async def _maybe_move(ws):
        nonlocal awaiting_echo, send_ts
        if awaiting_echo or board.is_game_over():
            return
        if board.turn != is_white:
            return
        if len(board.move_stack) >= plies:
            return
        mv = next(iter(board.legal_moves))
        send_ts = time.perf_counter()
        awaiting_echo = True
        await ws.send(json.dumps({"type": "move", "uci": mv.uci()}))

    try:
        while True:
            async with websockets.connect(uri, open_timeout=15, ping_interval=None) as ws:
                # First message is our state snapshot (or game_start once both in).
                while True:
                    try:
                        raw = await asyncio.wait_for(ws.recv(), timeout=10)
                    except asyncio.TimeoutError:
                        metrics["timeouts"] += 1
                        return
                    msg = json.loads(raw)
                    t = msg.get("type")
                    if t in ("state", "game_start"):
                        snap = msg.get("moves", [])
                        # Only accept a snapshot that is at least as advanced as
                        # our board — a stale (shorter) snapshot must not rewind us
                        # into re-sending a move we already made ("not your turn").
                        if len(snap) >= len(board.move_stack):
                            nb = chess.Board()
                            for m in snap:
                                try:
                                    nb.push_uci(m["uci"])
                                except Exception:
                                    pass
                            board = nb
                            awaiting_echo = False  # snapshot is ground truth
                        await _maybe_move(ws)
                    elif t == "move":
                        try:
                            board.push_uci(msg["uci"])
                        except Exception:
                            pass
                        # Was this the echo of OUR move?
                        moved_color_was_white = not board.turn  # side to move flipped
                        if awaiting_echo and moved_color_was_white == is_white and send_ts is not None:
                            metrics["latencies"].append((time.perf_counter() - send_ts) * 1000)
                            metrics["moves"] += 1
                            awaiting_echo = False
                        await _maybe_move(ws)
                    elif t == "game_paused":
                        metrics["paused"] += 1
                        return
                    elif t == "game_over":
                        metrics["finished"] += 1
                        return
                    elif t == "error":
                        metrics["errors"] += 1
                        awaiting_echo = False

                    # Reconnect simulation: drop the socket once at the target ply.
                    if (reconnect_at is not None and not did_reconnect
                            and len(board.move_stack) >= reconnect_at):
                        did_reconnect = True
                        metrics["reconnects"] += 1
                        break  # leave the `async with` → reconnect below
                    if len(board.move_stack) >= plies:
                        return
            # loop back to reconnect
            await asyncio.sleep(0.2)
            awaiting_echo = False
    except Exception as e:  # noqa: BLE001
        metrics["conn_errors"] += 1
        metrics["last_error"] = str(e)[:200]


async def _spectate(ws_base, game_id, plies, metrics):
    import websockets
    uri = f"{ws_base}/api/v1/chess/games/{game_id}/spectate"
    try:
        async with websockets.connect(uri, open_timeout=15, ping_interval=None) as ws:
            seen = 0
            while seen < plies:
                try:
                    # Short idle timeout: the run caps games at `plies` (no
                    # checkmate → no game_over), so exit once moves stop flowing.
                    raw = await asyncio.wait_for(ws.recv(), timeout=4)
                except asyncio.TimeoutError:
                    return
                msg = json.loads(raw)
                if msg.get("type") in ("move", "game_over"):
                    seen += 1
                metrics["spectator_msgs"] += 1
    except Exception:
        metrics["spectator_errors"] += 1


def seed(n_games):
    from app.core.database import Base, engine, SessionLocal
    from app.core.security import create_access_token, get_password_hash
    from app.models.tenant import Organization
    from app.models.user import User, UserProfile
    from app.models.chess import ChessGame

    Base.metadata.create_all(bind=engine)
    games = []
    with SessionLocal() as s:
        org = Organization(id=uuid.uuid4(), slug=f"lt-{uuid.uuid4().hex[:6]}",
                           name_ta="LoadTest", name_en="LoadTest")
        s.add(org)
        s.flush()
        for i in range(n_games):
            w = User(organization_id=org.id, phone_number=f"1{i:04d}00001",
                     password_hash=get_password_hash("x"), role="VOLUNTEER", is_verified=True)
            b = User(organization_id=org.id, phone_number=f"1{i:04d}00002",
                     password_hash=get_password_hash("x"), role="VOLUNTEER", is_verified=True)
            s.add_all([w, b])
            s.flush()
            s.add_all([
                UserProfile(user_id=w.id, full_name_en=f"White{i}", full_name_ta=f"White{i}"),
                UserProfile(user_id=b.id, full_name_en=f"Black{i}", full_name_ta=f"Black{i}"),
            ])
            g = ChessGame(id=uuid.uuid4(), organization_id=org.id, white_id=w.id, black_id=b.id,
                          mode="online", status="waiting", time_control="untimed")
            s.add(g)
            s.flush()
            wt = create_access_token(subject=str(w.id), role="VOLUNTEER", organization_id=str(org.id))
            bt = create_access_token(subject=str(b.id), role="VOLUNTEER", organization_id=str(org.id))
            games.append({"id": str(g.id), "white": wt, "black": bt})
        s.commit()
    return games


async def run(games, ws_base, plies, spectators, reconnects):
    metrics = {
        "moves": 0, "latencies": [], "paused": 0, "errors": 0, "conn_errors": 0,
        "timeouts": 0, "finished": 0, "reconnects": 0, "spectator_msgs": 0,
        "spectator_errors": 0, "last_error": "",
    }
    tasks = []
    for idx, g in enumerate(games):
        rc = (plies // 2) if idx < reconnects else None
        tasks.append(_play(ws_base, g["id"], g["white"], "white", plies, metrics))
        tasks.append(_play(ws_base, g["id"], g["black"], "black", plies, metrics, reconnect_at=rc))
        for _ in range(spectators):
            tasks.append(_spectate(ws_base, g["id"], plies, metrics))
    t0 = time.perf_counter()
    await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), timeout=180)
    metrics["wall_s"] = time.perf_counter() - t0
    return metrics


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=35)
    ap.add_argument("--spectators", type=int, default=2)
    ap.add_argument("--plies", type=int, default=30)
    ap.add_argument("--reconnects", type=int, default=5)
    ap.add_argument("--port", type=int, default=8911)
    ap.add_argument("--db", default=_DEFAULT_DB)
    args = ap.parse_args()

    os.environ["DATABASE_URL"] = args.db
    os.environ.setdefault("TESTING", "1")  # skip heavy startup reconcile/scheduler
    base = f"http://127.0.0.1:{args.port}"
    ws_base = f"ws://127.0.0.1:{args.port}"

    print(f"[seed] {args.games} games on {args.db}")
    games = seed(args.games)

    print(f"[server] starting uvicorn on :{args.port}")
    proc = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1",
         "--port", str(args.port), "--log-level", "warning"],
        env=os.environ.copy(),
    )
    try:
        if not asyncio.run(_wait_health(base)):
            print("[server] health check failed"); proc.terminate(); sys.exit(1)
        print(f"[run] {args.games} games x2 players + {args.spectators} spectators/game, "
              f"{args.plies} plies, {args.reconnects} reconnects")
        m = asyncio.run(run(games, ws_base, args.plies, args.spectators, args.reconnects))
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except Exception:
            proc.kill()

    lat = m["latencies"]
    wall = m.get("wall_s", 0) or 1
    print("\n" + "=" * 56)
    print("  CHESS LOAD TEST RESULTS")
    print("=" * 56)
    print(f"  games                : {args.games}  (players {args.games*2}, "
          f"spectators {args.games*args.spectators})")
    print(f"  wall time            : {wall:.1f}s")
    print(f"  moves persisted+echo : {m['moves']}")
    print(f"  throughput           : {m['moves']/wall:.1f} moves/sec")
    if lat:
        print(f"  move RTT  p50/p95/max: {_pctile(lat,50):.0f} / {_pctile(lat,95):.0f} / {max(lat):.0f} ms  (mean {mean(lat):.0f})")
    print(f"  reconnects exercised : {m['reconnects']}")
    print(f"  spectator msgs recv  : {m['spectator_msgs']}")
    print(f"  GAMES PAUSED (persist fail): {m['paused']}")
    print(f"  errors / conn / timeouts   : {m['errors']} / {m['conn_errors']} / {m['timeouts']}")
    if m["last_error"]:
        print(f"  last error           : {m['last_error']}")
    print("=" * 56)
    # Non-zero exit if the run clearly failed (nothing moved or games paused).
    if m["moves"] == 0 or m["paused"] > 0:
        sys.exit(2)


if __name__ == "__main__":
    main()
