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
        org_id = org.id
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
    return str(org_id), games


def cleanup(org_id):
    """Remove the throwaway load-test org and everything under it."""
    from app.core.database import SessionLocal
    from app.models.tenant import Organization
    from app.models.user import User, UserProfile
    from app.models.chess import ChessGame, ChessMove
    import uuid as _uuid
    oid = _uuid.UUID(org_id)
    with SessionLocal() as s:
        gids = [g.id for g in s.query(ChessGame.id).filter(ChessGame.organization_id == oid).all()]
        if gids:
            s.query(ChessMove).filter(ChessMove.game_id.in_(gids)).delete(synchronize_session=False)
        s.query(ChessGame).filter(ChessGame.organization_id == oid).delete(synchronize_session=False)
        uids = [u.id for u in s.query(User.id).filter(User.organization_id == oid).all()]
        if uids:
            s.query(UserProfile).filter(UserProfile.user_id.in_(uids)).delete(synchronize_session=False)
        s.query(User).filter(User.organization_id == oid).delete(synchronize_session=False)
        s.query(Organization).filter(Organization.id == oid).delete(synchronize_session=False)
        s.commit()


def _jwt_org(token):
    """Best-effort extract organization_id from a JWT payload (no verification)."""
    try:
        import base64
        p = token.split(".")[1]
        p += "=" * (-len(p) % 4)
        return json.loads(base64.urlsafe_b64decode(p)).get("organization_id")
    except Exception:
        return None


def fetch_health(http_base, admin_token):
    """GET the admin /system/health once — returns the parsed dict (or None).
    Sends X-Organization-ID (from the token) to satisfy the tenant guard."""
    import urllib.request
    headers = {}
    if admin_token:
        headers["Authorization"] = f"Bearer {admin_token}"
        org = _jwt_org(admin_token)
        if org:
            headers["X-Organization-ID"] = org
    req = urllib.request.Request(f"{http_base}/api/v1/system/health", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        return {"error": str(e)[:120]}


async def sample_metrics(http_base, admin_token, stop_event, out):
    """Poll /system/health ~1×/s while the load runs, collecting server CPU/mem."""
    import urllib.request
    while not stop_event.is_set():
        h = await asyncio.get_event_loop().run_in_executor(None, fetch_health, http_base, admin_token)
        m = (h or {}).get("system_metrics") or {}
        if "process_rss_mb" in m:
            out["rss_mb"].append(m["process_rss_mb"])
        if "cpu_percent" in m:
            out["cpu"].append(m["cpu_percent"])
        if "process_cpu_percent" in m:
            out["proc_cpu"].append(m["process_cpu_percent"])
        ch = (h or {}).get("chess") or {}
        out["peak_sessions"] = max(out["peak_sessions"], ch.get("active_sessions", 0))
        out["peak_spectators"] = max(out["peak_spectators"], ch.get("spectators", 0))
        out["paused_seen"] = max(out["paused_seen"], ch.get("paused_games", 0))
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            pass


async def run(games, ws_base, plies, spectators, reconnects, http_base=None, admin_token=None):
    metrics = {
        "moves": 0, "latencies": [], "paused": 0, "errors": 0, "conn_errors": 0,
        "timeouts": 0, "finished": 0, "reconnects": 0, "spectator_msgs": 0,
        "spectator_errors": 0, "last_error": "",
        "server": {"rss_mb": [], "cpu": [], "proc_cpu": [],
                   "peak_sessions": 0, "peak_spectators": 0, "paused_seen": 0},
    }
    tasks = []
    for idx, g in enumerate(games):
        rc = (plies // 2) if idx < reconnects else None
        tasks.append(_play(ws_base, g["id"], g["white"], "white", plies, metrics))
        tasks.append(_play(ws_base, g["id"], g["black"], "black", plies, metrics, reconnect_at=rc))
        for _ in range(spectators):
            tasks.append(_spectate(ws_base, g["id"], plies, metrics))

    # Sample server CPU/mem via the admin health endpoint while the load runs.
    stop = asyncio.Event()
    sampler = None
    if http_base:
        sampler = asyncio.create_task(sample_metrics(http_base, admin_token, stop, metrics["server"]))

    t0 = time.perf_counter()
    await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), timeout=300)
    metrics["wall_s"] = time.perf_counter() - t0
    if sampler:
        stop.set()
        try:
            await asyncio.wait_for(sampler, timeout=5)
        except Exception:
            pass
    return metrics


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--games", type=int, default=35)
    ap.add_argument("--spectators", type=int, default=2)
    ap.add_argument("--plies", type=int, default=30)
    ap.add_argument("--reconnects", type=int, default=5)
    ap.add_argument("--port", type=int, default=8911, help="local mode only")
    ap.add_argument("--db", default=None,
                    help="Override DATABASE_URL. LOCAL default: a temp sqlite. Inside the "
                         "prod container leave unset so it uses the prod Postgres secret.")
    # Split modes for testing a locked-down deployment where the DB is only
    # reachable inside the container and Fly secrets are write-only:
    #   1) flyctl ssh console -a fyc-backend -C "python scripts/chess_load_test.py --seed-only --games 35" > seed.json
    #   2) laptop: python scripts/chess_load_test.py --run-only --seed-file seed.json --target wss://fyc-backend.fly.dev --admin-token <jwt>
    #   3) flyctl ssh console -a fyc-backend -C "python scripts/chess_load_test.py --cleanup-only --org <id>"
    ap.add_argument("--seed-only", action="store_true", help="Seed DB + print games JSON, then exit (run in the prod container).")
    ap.add_argument("--run-only", action="store_true", help="Skip seeding; load games from --seed-file and drive --target.")
    ap.add_argument("--cleanup-only", action="store_true", help="Delete the load-test org given by --org, then exit.")
    ap.add_argument("--seed-file", default=None, help="Path to the seed JSON emitted by --seed-only.")
    ap.add_argument("--org", default=None, help="Org id to clean up (with --cleanup-only).")
    # Remote mode: point at the deployed server. Requires --db=prod-Postgres and
    # SECRET_KEY=<prod> in the env so minted JWTs validate on the server.
    ap.add_argument("--target", default=None,
                    help="Remote WSS base, e.g. wss://fyc-backend.fly.dev (skips the local server).")
    ap.add_argument("--http-base", default=None,
                    help="HTTPS base for health/metrics (defaults from --target).")
    ap.add_argument("--admin-token", default=None,
                    help="Admin JWT to sample /system/health (server CPU/mem + Postgres/Redis confirm).")
    ap.add_argument("--cleanup", action="store_true",
                    help="Delete the throwaway load-test org + data afterwards.")
    args = ap.parse_args()

    # DB env: an explicit --db wins; otherwise use whatever is already in the
    # environment (the container's prod Postgres); otherwise a local temp sqlite.
    if args.db:
        os.environ["DATABASE_URL"] = args.db
    elif not os.environ.get("DATABASE_URL"):
        os.environ["DATABASE_URL"] = _DEFAULT_DB
    os.environ.setdefault("TESTING", "1")  # skip heavy startup work (local server)

    # ── Split modes (for locked-down prod: seed/cleanup in-container, run remote) ──
    if args.cleanup_only:
        if not args.org:
            print("[error] --cleanup-only needs --org <id>"); sys.exit(1)
        cleanup(args.org)
        print(f"[cleanup] removed load-test org {args.org}")
        return
    if args.seed_only:
        org_id, games = seed(args.games)
        print(json.dumps({"org_id": org_id, "games": games}))
        return
    if args.run_only:
        if not (args.seed_file and args.target):
            print("[error] --run-only needs --seed-file and --target"); sys.exit(1)
        with open(args.seed_file) as f:
            seeded = json.load(f)
        org_id, games = seeded["org_id"], seeded["games"]
        ws_base = args.target.rstrip("/")
        http_base = (args.http_base or ws_base.replace("wss://", "https://").replace("ws://", "http://")).rstrip("/")
        if args.admin_token:
            h = fetch_health(http_base, args.admin_token)
            print(f"[backend] db={h.get('db_dialect')}  cache={h.get('cache')}")
        print(f"[run] {len(games)} games x2 players + {args.spectators} spectators/game")
        m = asyncio.run(run(games, ws_base, args.plies, args.spectators, args.reconnects,
                            http_base=http_base if args.admin_token else None,
                            admin_token=args.admin_token))
        _report(m, len(games), args.spectators, remote_label=ws_base)
        return

    remote = args.target is not None
    os.environ.setdefault("TESTING", "1")

    if remote:
        ws_base = args.target.rstrip("/")
        http_base = (args.http_base or ws_base.replace("wss://", "https://").replace("ws://", "http://")).rstrip("/")
        if os.environ.get("DATABASE_URL", "").startswith("sqlite"):
            print("[error] all-in-one remote mode seeds the server's DB, so it needs "
                  "--db=<prod Postgres URL> reachable from here. If prod Postgres is "
                  "private, use the split flow instead: --seed-only in the container, "
                  "then --run-only --seed-file from your laptop.")
            sys.exit(1)
    else:
        http_base = f"http://127.0.0.1:{args.port}"
        ws_base = f"ws://127.0.0.1:{args.port}"

    print(f"[seed] {args.games} games ({'REMOTE '+ws_base if remote else 'local'})")
    org_id, games = seed(args.games)

    proc = None
    if not remote:
        print(f"[server] starting uvicorn on :{args.port}")
        proc = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1",
             "--port", str(args.port), "--log-level", "warning"],
            env=os.environ.copy(),
        )

    try:
        if not remote and not asyncio.run(_wait_health(http_base)):
            print("[server] health check failed"); proc.terminate(); sys.exit(1)

        # Confirm the backend (Postgres/Redis) before hammering it.
        if args.admin_token:
            h = fetch_health(http_base, args.admin_token)
            print(f"[backend] db={h.get('db_dialect')}  cache={h.get('cache')}  "
                  f"mem={ (h.get('system_metrics') or {}).get('process_rss_mb') }MB")

        print(f"[run] {args.games} games x2 players + {args.spectators} spectators/game, "
              f"{args.plies} plies, {args.reconnects} reconnects")
        m = asyncio.run(run(games, ws_base, args.plies, args.spectators, args.reconnects,
                            http_base=http_base if args.admin_token else None,
                            admin_token=args.admin_token))
    finally:
        if proc:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except Exception:
                proc.kill()
        if args.cleanup:
            try:
                cleanup(org_id); print("[cleanup] removed load-test org + data")
            except Exception as e:
                print(f"[cleanup] failed: {e}")

    _report(m, args.games, args.spectators, remote_label=(ws_base if remote else None))


def _report(m, n_games, spectators, remote_label=None):
    lat = m["latencies"]
    wall = m.get("wall_s", 0) or 1
    srv = m.get("server", {"rss_mb": [], "cpu": [], "peak_sessions": 0, "peak_spectators": 0, "paused_seen": 0})
    print("\n" + "=" * 60)
    print(f"  CHESS LOAD TEST — {('REMOTE ' + remote_label) if remote_label else 'LOCAL (SQLite)'}")
    print("=" * 60)
    print(f"  games                : {n_games}  (players {n_games*2}, spectators {n_games*spectators})")
    print(f"  wall time            : {wall:.1f}s")
    print(f"  moves persisted+echo : {m['moves']}")
    print(f"  throughput           : {m['moves']/wall:.1f} moves/sec")
    if lat:
        print(f"  move RTT  p50/p95/max: {_pctile(lat,50):.0f} / {_pctile(lat,95):.0f} / {max(lat):.0f} ms  (mean {mean(lat):.0f})")
    print(f"  reconnects exercised : {m['reconnects']}")
    print(f"  spectator msgs recv  : {m['spectator_msgs']}")
    print(f"  GAMES PAUSED (persist fail): {m['paused']}  (server-observed: {srv.get('paused_seen', 0)})")
    print(f"  errors / conn / timeouts   : {m['errors']} / {m['conn_errors']} / {m['timeouts']}")
    if srv.get("rss_mb") or srv.get("cpu"):
        print("  ── server (sampled) ──")
        if srv.get("cpu"):
            print(f"  host cpu %  min/max/mean : {min(srv['cpu']):.0f} / {max(srv['cpu']):.0f} / {mean(srv['cpu']):.0f}")
        if srv.get("rss_mb"):
            print(f"  process RSS MB start/peak: {srv['rss_mb'][0]:.0f} / {max(srv['rss_mb']):.0f}")
        print(f"  peak sessions / spectators: {srv.get('peak_sessions',0)} / {srv.get('peak_spectators',0)}")
    if m["last_error"]:
        print(f"  last error           : {m['last_error']}")
    print("=" * 60)
    if m["moves"] == 0 or m["paused"] > 0 or srv.get("paused_seen", 0) > 0:
        sys.exit(2)


if __name__ == "__main__":
    main()
