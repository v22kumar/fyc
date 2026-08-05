"""
Live bot tournament — a watchable, end-to-end demo.

Creates a real chess tournament, fills it with bot players, and plays it round
by round through the actual API and WebSocket endpoints, at a human pace, so
the whole thing can be watched live on the web telecast while it runs.

Unlike simulate_full_tournament.py (which races to completion to validate
correctness), this one is paced for an audience:
  * bots think for a few seconds between moves instead of moving instantly
  * there is a configurable gap between rounds, so viewers can catch up
  * it prints the telecast links and a per-round summary as it goes

Everything goes through the same endpoints a phone uses: register → approve →
close → start → ready → play → move. Nothing is faked into the database except
the bot accounts themselves.

── Running it ────────────────────────────────────────────────────────────────
Locally (server already running on :8000):
    python scripts/demo_live_tournament.py

On Fly (runs inside the machine, against its own app and database):
    flyctl ssh console -a fyc-backend -C \
      "python /app/scripts/demo_live_tournament.py --round-gap 300"

Useful flags:
    --players 100        how many bots enter (64 gives a clean bracket, no byes)
    --round-gap 300      seconds between rounds (default 5 minutes)
    --move-delay 3.0     average seconds a bot 'thinks' per move
    --time-control rapid_10_0
    --dry-run            print the plan and exit without creating anything
    --cleanup            delete everything this script created, then exit

The organizer actions (create / approve / start) run as an EXISTING admin in
the organisation. The script deliberately does NOT create an admin account —
it will stop and tell you if it can't find one.
"""
import argparse
import asyncio
import json
import os
import random
import sys
import time
import uuid
from datetime import datetime, timezone

import chess
import httpx
import websockets

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal  # noqa: E402
from app.core.security import create_access_token, get_password_hash  # noqa: E402
from app.models.chess import ChessGame, ChessMove  # noqa: E402
from app.models.chess_tournament import (  # noqa: E402
    ChessTournament,
    ChessTournamentEntry,
    ChessTournamentMatch,
)
from app.models.tenant import Organization  # noqa: E402
from app.models.user import User, UserProfile  # noqa: E402

BOT_EMAIL_PREFIX = "demobot"
BOT_PHONE_BASE = 9880000000
ORGANIZER_ROLES = ("SUPER_ADMIN", "ADMIN", "EXECUTIVE_MEMBER")


# ── helpers ───────────────────────────────────────────────────────────────────

def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def token_for(user_id, role, org_id) -> str:
    return create_access_token(str(user_id), role, str(org_id))


def headers(user_id, role, org_id) -> dict:
    return {
        "Authorization": f"Bearer {token_for(user_id, role, org_id)}",
        "X-Organization-ID": str(org_id),
    }


def pick_org(db, org_id: str | None) -> Organization:
    if org_id:
        org = db.query(Organization).filter(Organization.id == uuid.UUID(org_id)).first()
        if not org:
            raise SystemExit(f"No organisation {org_id}")
        return org
    org = db.query(Organization).order_by(Organization.created_at.asc()).first()
    if not org:
        raise SystemExit("No organisation exists — nothing to run against.")
    return org


def find_organizer(db, org: Organization) -> User:
    """An existing admin runs the organizer actions.

    Creating a privileged account as a side effect of a demo would be a nasty
    surprise, so this stops instead if there isn't one already.
    """
    admin = (
        db.query(User)
        .filter(User.organization_id == org.id, User.role.in_(ORGANIZER_ROLES))
        .order_by(User.created_at.asc())
        .first()
    )
    if not admin:
        raise SystemExit(
            f"No user with role {ORGANIZER_ROLES} in '{org.slug}'. "
            "Promote an account first — this script will not create an admin."
        )
    return admin


def ensure_bots(db, org: Organization, n: int) -> list:
    """Create (or reuse) n bot players. Idempotent across runs."""
    bots, created = [], 0
    for i in range(n):
        email = f"{BOT_EMAIL_PREFIX}{i}@fyc.local"
        u = db.query(User).filter(
            User.organization_id == org.id, User.email == email
        ).first()
        if not u:
            u = User(
                id=uuid.uuid4(),
                organization_id=org.id,
                email=email,
                phone_number=f"+91{BOT_PHONE_BASE + i}",
                password_hash=get_password_hash(uuid.uuid4().hex),
                role="USER",
                is_verified=True,
                preferred_language="en",
            )
            db.add(u)
            db.flush()
            db.add(UserProfile(
                user_id=u.id,
                full_name_en=f"Bot {i + 1:03d}",
                full_name_ta=f"பாட் {i + 1:03d}",
            ))
            created += 1
        bots.append(u)
    db.commit()
    log(f"bots ready: {len(bots)} ({created} new, {len(bots) - created} reused)")
    return bots


# ── one game ──────────────────────────────────────────────────────────────────

async def play_game(ws_base, game_id, white, black, org_id, move_delay, jitter,
                    max_plies, counters):
    """Two bots play a game over the real WebSocket, thinking between moves."""
    done = asyncio.Event()
    outcome = {}

    async def side(user, colour):
        board = chess.Board()
        last_sent_ply = -1
        uri = (f"{ws_base}/api/v1/chess/games/{game_id}/ws"
               f"?token={token_for(user.id, user.role, org_id)}")
        try:
            async with websockets.connect(uri, ping_interval=20) as ws:
                while not done.is_set():
                    try:
                        msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=180))
                    except asyncio.TimeoutError:
                        counters["timeout"] += 1
                        done.set()
                        return
                    except websockets.ConnectionClosed:
                        return

                    t = msg.get("type")
                    if t == "game_over":
                        outcome["result"] = msg.get("result")
                        outcome["reason"] = msg.get("reason")
                        done.set()
                        return
                    if t == "error":
                        # Never sit on a stale board waiting for an echo that
                        # will not come — ask for the authoritative position.
                        counters["error"] += 1
                        await ws.send(json.dumps({"type": "sync"}))
                        continue
                    if t not in ("game_start", "state", "move"):
                        continue

                    fen = msg.get("fen")
                    if fen:
                        board.set_fen(fen)
                    if ("white" if board.turn else "black") != colour:
                        continue
                    if board.ply() == last_sent_ply:
                        continue          # one move per position
                    last_sent_ply = board.ply()

                    # Think, so a human can actually follow the game.
                    await asyncio.sleep(max(0.0, random.gauss(move_delay, jitter)))
                    if done.is_set():
                        return

                    if board.ply() >= max_plies:
                        await ws.send(json.dumps({"type": "resign"}))
                        continue
                    legal = list(board.legal_moves)
                    if not legal:
                        continue
                    mates = [m for m in legal if board.gives_check(m)]
                    caps = [m for m in legal if board.is_capture(m)]
                    await ws.send(json.dumps({
                        "type": "move",
                        "uci": random.choice(mates or caps or legal).uci(),
                    }))
        except Exception as e:  # noqa: BLE001
            counters[f"conn_error:{type(e).__name__}"] += 1
            done.set()

    await asyncio.gather(side(white, "white"), side(black, "black"),
                         return_exceptions=True)
    counters[f"result:{outcome.get('result', 'UNRESOLVED')}"] += 1
    return outcome


# ── round driver ──────────────────────────────────────────────────────────────

async def play_round(api, ws_base, tour_id, org_id, rnd, bots_by_id, args, counters):
    with SessionLocal() as db:
        matches = (
            db.query(ChessTournamentMatch)
            .filter(
                ChessTournamentMatch.tournament_id == tour_id,
                ChessTournamentMatch.round == rnd,
                ChessTournamentMatch.winner_id.is_(None),
                ChessTournamentMatch.player_a_id.isnot(None),
                ChessTournamentMatch.player_b_id.isnot(None),
            ).all()
        )
        pending = [(m.id, m.player_a_id, m.player_b_id) for m in matches]

    if not pending:
        log(f"round {rnd}: nothing to play")
        return 0

    log(f"round {rnd}: opening {len(pending)} boards…")
    async with httpx.AsyncClient(timeout=60) as client:
        for mid, a, b in pending:
            for uid in (a, b):
                u = bots_by_id[uid]
                r = await client.post(
                    f"{api}/api/v1/chess/tournaments/{tour_id}/matches/{mid}/ready",
                    headers=headers(u.id, u.role, org_id))
                if r.status_code >= 400:
                    counters[f"ready_fail:{r.status_code}"] += 1
            ua = bots_by_id[a]
            r = await client.post(
                f"{api}/api/v1/chess/tournaments/{tour_id}/matches/{mid}/play",
                headers=headers(ua.id, ua.role, org_id))
            if r.status_code >= 400:
                counters[f"play_fail:{r.status_code}"] += 1

    with SessionLocal() as db:
        live = (
            db.query(ChessTournamentMatch)
            .filter(
                ChessTournamentMatch.tournament_id == tour_id,
                ChessTournamentMatch.round == rnd,
                ChessTournamentMatch.game_id.isnot(None),
                ChessTournamentMatch.winner_id.is_(None),
            ).all()
        )
        games = [(m.game_id, m.player_a_id, m.player_b_id) for m in live]

    log(f"round {rnd}: {len(games)} games LIVE — watch now")
    t0 = time.time()
    await asyncio.gather(*[
        play_game(ws_base, g, bots_by_id[a], bots_by_id[b], org_id,
                  args.move_delay, args.move_jitter, args.max_plies, counters)
        for g, a, b in games
    ], return_exceptions=True)
    log(f"round {rnd}: all {len(games)} games finished in {time.time() - t0:.0f}s")
    return len(games)


# ── cleanup ───────────────────────────────────────────────────────────────────

def cleanup(org_id_arg):
    from sqlalchemy import text
    with SessionLocal() as db:
        org = pick_org(db, org_id_arg)
        bot_ids = [
            u.id for u in db.query(User).filter(
                User.organization_id == org.id,
                User.email.like(f"{BOT_EMAIL_PREFIX}%@fyc.local"),
            ).all()
        ]
        tours = db.query(ChessTournament).filter(
            ChessTournament.organization_id == org.id,
            ChessTournament.name.like("Bot Demo%"),
        ).all()
        tour_ids = [t.id for t in tours]

        games = db.query(ChessGame).filter(
            ChessGame.white_id.in_(bot_ids) | ChessGame.black_id.in_(bot_ids)
        ).all() if bot_ids else []
        for g in games:
            db.query(ChessMove).filter(ChessMove.game_id == g.id).delete(
                synchronize_session=False)
        for t in tour_ids:
            db.query(ChessTournamentMatch).filter(
                ChessTournamentMatch.tournament_id == t).delete(
                synchronize_session=False)
            db.query(ChessTournamentEntry).filter(
                ChessTournamentEntry.tournament_id == t).delete(
                synchronize_session=False)
        for g in games:
            db.delete(g)
        for t in tours:
            db.delete(t)
        db.commit()

        if bot_ids:
            for tbl in ("chess_player_stats", "notifications", "user_profiles"):
                try:
                    db.execute(text(f"DELETE FROM {tbl} WHERE user_id IN :ids"),
                               {"ids": tuple(str(i) for i in bot_ids)})
                except Exception:
                    db.rollback()
            db.query(User).filter(User.id.in_(bot_ids)).delete(
                synchronize_session=False)
            db.commit()
        log(f"cleaned: {len(tours)} tournament(s), {len(games)} game(s), "
            f"{len(bot_ids)} bot account(s)")


# ── main ──────────────────────────────────────────────────────────────────────

async def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--players", type=int, default=100)
    ap.add_argument("--round-gap", type=float, default=300.0,
                    help="seconds between rounds (default 300 = 5 minutes)")
    ap.add_argument("--move-delay", type=float, default=3.0,
                    help="average seconds a bot thinks per move")
    ap.add_argument("--move-jitter", type=float, default=1.2)
    ap.add_argument("--max-plies", type=int, default=60,
                    help="a bot resigns past this, so games stay bounded")
    ap.add_argument("--time-control", default="rapid_10_0")
    ap.add_argument("--name", default=None)
    ap.add_argument("--api-base", default=os.getenv("DEMO_API_BASE",
                                                    "http://127.0.0.1:8000"))
    ap.add_argument("--ws-base", default=os.getenv("DEMO_WS_BASE", None))
    ap.add_argument("--web-base", default=os.getenv("DEMO_WEB_BASE",
                                                    "https://fycconnect.com"))
    ap.add_argument("--org-id", default=os.getenv("DEFAULT_ORG_ID"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--cleanup", action="store_true")
    args = ap.parse_args()

    if args.cleanup:
        cleanup(args.org_id)
        return 0

    api = args.api_base.rstrip("/")
    ws_base = args.ws_base or api.replace("https://", "wss://").replace("http://", "ws://")
    name = args.name or f"Bot Demo — {datetime.now().strftime('%d %b %H:%M')}"

    # Bracket shape, so the plan is visible before anything is created.
    import math
    depth = math.ceil(math.log2(max(2, args.players)))
    bracket = 2 ** depth
    byes = bracket - args.players
    first_round_games = (bracket // 2) - byes
    plan = [first_round_games] + [bracket // (2 ** (i + 2)) for i in range(depth - 1)]

    print("=" * 60)
    print(f"  {name}")
    print(f"  players       : {args.players}  (bracket {bracket}, {byes} byes)")
    print(f"  rounds        : {' → '.join(f'{g} games' for g in plan)}")
    print(f"  time control  : {args.time_control}")
    print(f"  bot pace      : ~{args.move_delay}s per move")
    print(f"  gap between   : {args.round_gap / 60:.0f} min")
    print("=" * 60)
    if args.dry_run:
        print("dry run — nothing created")
        return 0

    with SessionLocal() as db:
        org = pick_org(db, args.org_id)
        admin = find_organizer(db, org)
        org_id, admin_id, admin_role = org.id, admin.id, admin.role
        bots = ensure_bots(db, org, args.players)
        bots_by_id = {b.id: b for b in bots}
        bot_refs = [(b.id, b.role) for b in bots]

    admin_hdr = headers(admin_id, admin_role, org_id)

    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(f"{api}/api/v1/chess/tournaments",
                              json={"name": name,
                                    "description": "Automated bot demo — live telecast",
                                    "time_control": args.time_control},
                              headers=admin_hdr)
        if r.status_code >= 400:
            raise SystemExit(f"create failed {r.status_code}: {r.text}")
        tour_id = r.json()["id"]
        log(f"tournament created: {tour_id}")

        print()
        print("  ┌─ WATCH LIVE ────────────────────────────────────────────")
        print(f"  │ this tournament : {args.web_base}/chess?tournament={tour_id}")
        print(f"  │ all live games  : {args.web_base}/chess")
        print("  └─────────────────────────────────────────────────────────")
        print()

        log("registering bots…")
        for uid, role in bot_refs:
            await client.post(
                f"{api}/api/v1/chess/tournaments/{tour_id}/register",
                headers=headers(uid, role, org_id))
        log("approving registrations…")
        for uid, _ in bot_refs:
            await client.post(
                f"{api}/api/v1/chess/tournaments/{tour_id}/registrations/{uid}/decision",
                json={"approve": True}, headers=admin_hdr)

        await client.post(f"{api}/api/v1/chess/tournaments/{tour_id}/close",
                          headers=admin_hdr)
        r = await client.post(f"{api}/api/v1/chess/tournaments/{tour_id}/start",
                              headers=admin_hdr)
        if r.status_code >= 400:
            raise SystemExit(f"start failed {r.status_code}: {r.text}")
        total_rounds = r.json().get("rounds") or len(plan)
        log(f"bracket drawn — {total_rounds} rounds. Round 1 is live.")

    counters = __import__("collections").Counter()
    t_start = time.time()

    for rnd in range(1, total_rounds + 1):
        if rnd > 1:
            log(f"── {args.round_gap / 60:.0f} minute break before round {rnd} ──")
            await asyncio.sleep(args.round_gap)
            async with httpx.AsyncClient(timeout=60) as client:
                r = await client.post(
                    f"{api}/api/v1/chess/tournaments/{tour_id}/next-round",
                    headers=admin_hdr)
                if r.status_code >= 400:
                    log(f"could not start round {rnd}: {r.status_code} {r.text[:120]}")
                    break

        await play_round(api, ws_base, uuid.UUID(tour_id), org_id, rnd,
                         bots_by_id, args, counters)

        # Fetching the detail is what advances the bracket (same call the app
        # makes), so do it explicitly before the next round.
        async with httpx.AsyncClient(timeout=60) as client:
            await client.get(f"{api}/api/v1/chess/tournaments/{tour_id}",
                             headers=admin_hdr)

    with SessionLocal() as db:
        tour = db.query(ChessTournament).filter(
            ChessTournament.id == uuid.UUID(tour_id)).first()
        champ = ""
        if tour and tour.champion_id:
            p = db.query(UserProfile).filter(
                UserProfile.user_id == tour.champion_id).first()
            champ = p.full_name_en if p else str(tour.champion_id)
        unresolved = db.query(ChessTournamentMatch).filter(
            ChessTournamentMatch.tournament_id == uuid.UUID(tour_id),
            ChessTournamentMatch.winner_id.is_(None)).count()

    print()
    print("=" * 60)
    print(f"  status      : {tour.status if tour else '?'}")
    print(f"  champion    : {champ or '— none —'}")
    print(f"  unresolved  : {unresolved}")
    print(f"  total time  : {(time.time() - t_start) / 60:.1f} min")
    for k, v in sorted(counters.items()):
        print(f"    {k:<30} {v}")
    print("=" * 60)
    print(f"  replay: {args.web_base}/chess?tournament={tour_id}")
    return 0 if (tour and tour.status == "COMPLETED" and unresolved == 0) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
