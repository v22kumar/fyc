"""
Cross-platform tournament soak test — run this before a real event.

Your tournament will be played half in browsers and half on phones, over mobile
networks that drop. The other two scripts do not cover that:

    simulate_full_tournament.py   races a tournament to a champion (correctness)
    demo_live_tournament.py       paces one for an audience to watch

This one plays a tournament where every bot behaves like a REAL client of one
kind or the other, and where connections deliberately fail mid-game. It answers
the question you actually care about the night before: *if half these people are
on phones on patchy 4G, does the tournament still finish?*

What "cross-platform" means here, precisely
------------------------------------------
Both clients speak the same WebSocket protocol, so this simulates their WIRE
behaviour faithfully — heartbeats, when each sends `sync`, how each answers the
server's latency probe, and how each reconnects. It does NOT drive their user
interfaces; that is covered separately (Playwright for the web board, and the
xdotool harness for the Flutter board). What this proves is that the two client
behaviours interoperate under load and disruption, and that the server's
protocol handles both.

Running it on Fly
-----------------
    flyctl ssh console -a fyc-backend -C \\
      "python /app/scripts/simulate_cross_platform_tournament.py --players 16"

Useful flags:
    --players 16        bots in the tournament (power of two = no byes)
    --web-share 0.5     fraction behaving like browser clients
    --drop-rate 0.25    chance a player's connection dies mid-game and returns
    --move-delay 0.4    seconds a bot thinks (raise it to watch on the telecast)
    --time-control rapid_10_0
    --cleanup           remove everything this script created, then exit
    --dry-run           print the plan and exit
"""
import argparse
import asyncio
import json
import os
import random
import sys
import time
import uuid
from collections import Counter
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

BOT_EMAIL_PREFIX = "xplatbot"
BOT_PHONE_BASE = 9890000000
TOURNAMENT_NAME_PREFIX = "Cross-Platform Soak"
ORGANIZER_ROLES = ("SUPER_ADMIN", "ADMIN", "EXECUTIVE_MEMBER")

stats = Counter()
protocol_seen = set()


def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


# ── client profiles ───────────────────────────────────────────────────────────
# The two behaviours the server has to serve at once. Keep these honest: if the
# real clients change how they talk, change them here too, or this stops testing
# anything.

WEB = "web"
MOBILE = "mobile"

PROFILE = {
    # The browser board re-syncs on EVERY connect, because a page that has been
    # in a background tab cannot trust what it last saw.
    WEB: {"sync_on_connect": True, "ping_every": 20.0, "answers_probe": True},
    # The app syncs on reconnect and relies on the server's opening snapshot
    # otherwise, and heartbeats a little slower to spare the radio.
    MOBILE: {"sync_on_connect": False, "ping_every": 25.0, "answers_probe": True},
}


class BotClient:
    """One player, behaving like a browser or like the app."""

    def __init__(self, ws_base, game_id, user, profile, args):
        self.ws_base = ws_base
        self.game_id = str(game_id)
        self.user = user
        self.profile = profile
        self.args = args
        self.board = chess.Board()
        self.my_colour = None
        self.done = asyncio.Event()
        self.result = None
        self.reconnects = 0

    @property
    def _behaviour(self):
        return PROFILE[self.profile]

    async def play(self):
        """Connect and play until the game ends, reconnecting if dropped."""
        attempts = 0
        while not self.done.is_set() and attempts < 4:
            attempts += 1
            try:
                await self._session(first=attempts == 1)
            except Exception as e:  # noqa: BLE001
                stats[f"{self.profile}:conn_error"] += 1
                if self.done.is_set():
                    break
                await asyncio.sleep(0.5 + random.random())
        return self.result

    async def _session(self, first: bool):
        token = create_access_token(
            str(self.user["id"]), self.user["role"], str(self.user["org_id"])
        )
        uri = f"{self.ws_base}/api/v1/chess/games/{self.game_id}/ws?token={token}"
        async with websockets.connect(uri, ping_interval=None) as ws:
            if not first:
                self.reconnects += 1
                stats[f"{self.profile}:reconnect"] += 1
            # A reconnecting client ALWAYS resyncs; a fresh one only if its
            # profile says so.
            if self._behaviour["sync_on_connect"] or not first:
                await ws.send(json.dumps({"type": "sync"}))

            heartbeat = asyncio.create_task(self._heartbeat(ws))
            chaos = asyncio.create_task(self._maybe_drop(ws)) if first else None
            try:
                await self._pump(ws)
            finally:
                heartbeat.cancel()
                if chaos:
                    chaos.cancel()

    async def _heartbeat(self, ws):
        while True:
            await asyncio.sleep(self._behaviour["ping_every"])
            try:
                await ws.send(json.dumps({"type": "ping"}))
            except Exception:  # noqa: BLE001
                return

    async def _maybe_drop(self, ws):
        """Kill the connection mid-game, the way a tunnel or a lift does.

        This is the point of the whole script: the resync-and-resume path is the
        one that has never faced a real network, and a tournament that cannot
        survive it will fail in public.
        """
        if random.random() >= self.args.drop_rate:
            return
        await asyncio.sleep(random.uniform(2.0, 6.0))
        if not self.done.is_set():
            stats[f"{self.profile}:dropped"] += 1
            await ws.close()

    async def _pump(self, ws):
        last_sent_ply = -1
        while not self.done.is_set():
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=120)
            except asyncio.TimeoutError:
                stats[f"{self.profile}:timeout"] += 1
                return
            except websockets.ConnectionClosed:
                return

            msg = json.loads(raw)
            kind = msg.get("type")
            protocol_seen.add(kind)

            if kind == "latency_probe":
                # Answer at once — the round trip measured here is what the
                # server refunds to this player's clock.
                if self._behaviour["answers_probe"]:
                    await ws.send(json.dumps({"type": "latency_pong"}))
                continue
            if kind == "game_over":
                self.result = (msg.get("result"), msg.get("reason"))
                self.done.set()
                return
            if kind == "game_paused":
                stats["game_paused"] += 1
                continue
            if kind == "error":
                stats[f"{self.profile}:error"] += 1
                await ws.send(json.dumps({"type": "sync"}))
                continue
            if kind in ("state", "game_start", "move"):
                if msg.get("color"):
                    self.my_colour = msg["color"]
                fen = msg.get("fen")
                if fen:
                    self.board.set_fen(fen)
            else:
                continue

            if self.my_colour is None:
                continue
            turn = "white" if self.board.turn else "black"
            if turn != self.my_colour:
                continue
            if self.board.ply() == last_sent_ply:
                continue                     # one move per position
            last_sent_ply = self.board.ply()

            await asyncio.sleep(max(0.0, random.gauss(self.args.move_delay,
                                                     self.args.move_delay / 3)))
            if self.done.is_set():
                return
            if self.board.ply() >= self.args.max_plies:
                await ws.send(json.dumps({"type": "resign"}))
                continue
            legal = list(self.board.legal_moves)
            if not legal:
                continue
            mates = [m for m in legal if self.board.gives_check(m)]
            caps = [m for m in legal if self.board.is_capture(m)]
            move = random.choice(mates or caps or legal)
            try:
                await ws.send(json.dumps({"type": "move", "uci": move.uci()}))
                stats[f"{self.profile}:moves"] += 1
            except Exception:  # noqa: BLE001
                return


# ── setup ─────────────────────────────────────────────────────────────────────

def pick_org(db, org_id):
    if org_id:
        org = db.query(Organization).filter(Organization.id == uuid.UUID(org_id)).first()
        if not org:
            raise SystemExit(f"No organisation {org_id}")
        return org
    org = db.query(Organization).order_by(Organization.created_at.asc()).first()
    if not org:
        raise SystemExit("No organisation exists — nothing to run against.")
    return org


def find_organizer(db, org):
    """Use an EXISTING admin. Creating a privileged account as a side effect of
    a test script would be a nasty surprise."""
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


def ensure_bots(db, org, n):
    bots, created = [], 0
    for i in range(n):
        email = f"{BOT_EMAIL_PREFIX}{i}@fyc.local"
        u = db.query(User).filter(
            User.organization_id == org.id, User.email == email).first()
        if not u:
            u = User(
                id=uuid.uuid4(), organization_id=org.id, email=email,
                phone_number=f"+91{BOT_PHONE_BASE + i}",
                password_hash=get_password_hash(uuid.uuid4().hex),
                role="USER", is_verified=True, preferred_language="en",
            )
            db.add(u)
            db.flush()
            db.add(UserProfile(user_id=u.id,
                               full_name_en=f"XBot {i + 1:03d}",
                               full_name_ta=f"XBot {i + 1:03d}"))
            created += 1
        bots.append(u)
    db.commit()
    log(f"bots ready: {len(bots)} ({created} new)")
    return [{"id": b.id, "role": b.role, "org_id": org.id} for b in bots]


def cleanup(org_id_arg):
    from sqlalchemy import text
    with SessionLocal() as db:
        org = pick_org(db, org_id_arg)
        bot_ids = [u.id for u in db.query(User).filter(
            User.organization_id == org.id,
            User.email.like(f"{BOT_EMAIL_PREFIX}%@fyc.local")).all()]
        tours = db.query(ChessTournament).filter(
            ChessTournament.organization_id == org.id,
            ChessTournament.name.like(f"{TOURNAMENT_NAME_PREFIX}%")).all()
        games = db.query(ChessGame).filter(
            ChessGame.white_id.in_(bot_ids) | ChessGame.black_id.in_(bot_ids)
        ).all() if bot_ids else []

        for g in games:
            db.query(ChessMove).filter(ChessMove.game_id == g.id).delete(
                synchronize_session=False)
        for t in tours:
            db.query(ChessTournamentMatch).filter(
                ChessTournamentMatch.tournament_id == t.id).delete(
                synchronize_session=False)
            db.query(ChessTournamentEntry).filter(
                ChessTournamentEntry.tournament_id == t.id).delete(
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
                except Exception:  # noqa: BLE001
                    db.rollback()
            db.query(User).filter(User.id.in_(bot_ids)).delete(
                synchronize_session=False)
            db.commit()
        log(f"cleaned: {len(tours)} tournament(s), {len(games)} game(s), "
            f"{len(bot_ids)} bot account(s)")


# ── driving a round ───────────────────────────────────────────────────────────

async def play_round(api, ws_base, tour_id, org_id, rnd, by_id, profiles, args):
    with SessionLocal() as db:
        pending = [
            (m.id, m.player_a_id, m.player_b_id)
            for m in db.query(ChessTournamentMatch).filter(
                ChessTournamentMatch.tournament_id == tour_id,
                ChessTournamentMatch.round == rnd,
                ChessTournamentMatch.winner_id.is_(None),
                ChessTournamentMatch.player_a_id.isnot(None),
                ChessTournamentMatch.player_b_id.isnot(None),
            ).all()
        ]
    if not pending:
        return 0

    def hdr(uid):
        u = by_id[uid]
        return {
            "Authorization":
                f"Bearer {create_access_token(str(uid), u['role'], str(org_id))}",
            "X-Organization-ID": str(org_id),
        }

    async with httpx.AsyncClient(timeout=60) as client:
        for mid, a, b in pending:
            for uid in (a, b):
                r = await client.post(
                    f"{api}/api/v1/chess/tournaments/{tour_id}/matches/{mid}/ready",
                    headers=hdr(uid))
                if r.status_code >= 400:
                    stats[f"ready_fail:{r.status_code}"] += 1
            r = await client.post(
                f"{api}/api/v1/chess/tournaments/{tour_id}/matches/{mid}/play",
                headers=hdr(a))
            if r.status_code >= 400:
                stats[f"play_fail:{r.status_code}"] += 1

    with SessionLocal() as db:
        live = [
            (m.game_id, m.player_a_id, m.player_b_id)
            for m in db.query(ChessTournamentMatch).filter(
                ChessTournamentMatch.tournament_id == tour_id,
                ChessTournamentMatch.round == rnd,
                ChessTournamentMatch.game_id.isnot(None),
                ChessTournamentMatch.winner_id.is_(None),
            ).all()
        ]

    mixed = sum(1 for _, a, b in live if profiles[a] != profiles[b])
    log(f"  round {rnd}: {len(live)} games ({mixed} of them web-vs-phone)")

    tasks = []
    for gid, a, b in live:
        for uid in (a, b):
            tasks.append(
                BotClient(ws_base, gid, by_id[uid], profiles[uid], args).play())
    await asyncio.gather(*tasks, return_exceptions=True)
    return len(live)


def activate_round(tour_id, rnd):
    with SessionLocal() as db:
        tour = db.query(ChessTournament).filter(
            ChessTournament.id == tour_id).first()
        ms = db.query(ChessTournamentMatch).filter(
            ChessTournamentMatch.tournament_id == tour_id,
            ChessTournamentMatch.round == rnd).all()
        for m in ms:
            m.activated = True
            m.activated_at = datetime.now(timezone.utc)
            if m.player_a_id and m.player_b_id and m.winner_id is None:
                m.status = "READY"
        tour.current_round = rnd
        tour.status = "IN_PROGRESS"
        db.commit()
        return len([m for m in ms
                    if m.winner_id is None and m.player_a_id and m.player_b_id])


def resolve(tour_id):
    from app.routers.chess_tournaments import _auto_resolve
    with SessionLocal() as db:
        tour = db.query(ChessTournament).filter(
            ChessTournament.id == tour_id).first()
        try:
            _auto_resolve(db, tour)
        except Exception as e:  # noqa: BLE001
            log(f"  auto-resolve failed: {e}")
            db.rollback()
        db.refresh(tour)
        return tour.status, tour.champion_id


# ── main ──────────────────────────────────────────────────────────────────────

async def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--players", type=int, default=16)
    ap.add_argument("--web-share", type=float, default=0.5,
                    help="fraction of bots behaving like browser clients")
    ap.add_argument("--drop-rate", type=float, default=0.25,
                    help="chance a player's connection dies mid-game")
    ap.add_argument("--move-delay", type=float, default=0.4)
    ap.add_argument("--max-plies", type=int, default=60)
    ap.add_argument("--time-control", default="rapid_10_0")
    ap.add_argument("--api-base",
                    default=os.getenv("SIM_API_BASE", "http://127.0.0.1:8000"))
    ap.add_argument("--ws-base", default=os.getenv("SIM_WS_BASE"))
    ap.add_argument("--org-id", default=os.getenv("DEFAULT_ORG_ID"))
    ap.add_argument("--cleanup", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.cleanup:
        cleanup(args.org_id)
        return 0

    api = args.api_base.rstrip("/")
    ws_base = args.ws_base or api.replace("https://", "wss://").replace("http://", "ws://")

    import math
    depth = math.ceil(math.log2(max(2, args.players)))
    bracket = 2 ** depth
    byes = bracket - args.players
    n_web = int(round(args.players * args.web_share))

    print("=" * 64)
    print(f"  {TOURNAMENT_NAME_PREFIX}")
    print(f"  players      : {args.players}  ({n_web} web-like, "
          f"{args.players - n_web} phone-like)")
    print(f"  bracket      : {bracket} slots, {byes} byes, {depth} rounds")
    print(f"  time control : {args.time_control}")
    print(f"  drop rate    : {args.drop_rate:.0%} of players lose their "
          f"connection mid-game")
    print("=" * 64)
    if args.dry_run:
        print("dry run — nothing created")
        return 0

    with SessionLocal() as db:
        org = pick_org(db, args.org_id)
        admin = find_organizer(db, org)
        org_id, admin_id, admin_role = org.id, admin.id, admin.role
        bots = ensure_bots(db, org, args.players)

    by_id = {b["id"]: b for b in bots}
    ids = [b["id"] for b in bots]
    random.shuffle(ids)
    profiles = {uid: (WEB if i < n_web else MOBILE) for i, uid in enumerate(ids)}

    admin_hdr = {
        "Authorization":
            f"Bearer {create_access_token(str(admin_id), admin_role, str(org_id))}",
        "X-Organization-ID": str(org_id),
    }
    name = f"{TOURNAMENT_NAME_PREFIX} — {datetime.now().strftime('%d %b %H:%M')}"

    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(f"{api}/api/v1/chess/tournaments",
                              json={"name": name,
                                    "description": "Cross-platform soak test",
                                    "time_control": args.time_control},
                              headers=admin_hdr)
        if r.status_code >= 400:
            raise SystemExit(f"create failed {r.status_code}: {r.text}")
        tour_id = r.json()["id"]
        log(f"tournament {tour_id}")

        for b in bots:
            await client.post(
                f"{api}/api/v1/chess/tournaments/{tour_id}/register",
                headers={
                    "Authorization":
                        f"Bearer {create_access_token(str(b['id']), b['role'], str(org_id))}",
                    "X-Organization-ID": str(org_id),
                })
        for b in bots:
            await client.post(
                f"{api}/api/v1/chess/tournaments/{tour_id}/registrations/{b['id']}/decision",
                json={"approve": True}, headers=admin_hdr)
        await client.post(f"{api}/api/v1/chess/tournaments/{tour_id}/close",
                          headers=admin_hdr)
        r = await client.post(f"{api}/api/v1/chess/tournaments/{tour_id}/start",
                              headers=admin_hdr)
        if r.status_code >= 400:
            raise SystemExit(f"start failed {r.status_code}: {r.text}")
        total_rounds = r.json().get("rounds") or depth

    t0 = time.time()
    for rnd in range(1, total_rounds + 1):
        if activate_round(uuid.UUID(tour_id), rnd):
            await play_round(api, ws_base, uuid.UUID(tour_id), org_id, rnd,
                             by_id, profiles, args)
        resolve(uuid.UUID(tour_id))

    status, champion = resolve(uuid.UUID(tour_id))
    elapsed = time.time() - t0

    with SessionLocal() as db:
        unresolved = db.query(ChessTournamentMatch).filter(
            ChessTournamentMatch.tournament_id == uuid.UUID(tour_id),
            ChessTournamentMatch.winner_id.is_(None)).count()
        # Scope this to THIS tournament's games. Counting every unfinished game
        # in the database sweeps up leftovers from earlier runs and reports a
        # failure that never happened — a false alarm in a pre-event health
        # check is worse than no check at all.
        our_games = [
            m.game_id for m in db.query(ChessTournamentMatch).filter(
                ChessTournamentMatch.tournament_id == uuid.UUID(tour_id),
                ChessTournamentMatch.game_id.isnot(None)).all()
        ]
        stuck = db.query(ChessGame).filter(
            ChessGame.id.in_(our_games),
            ChessGame.status.in_(("waiting", "in_progress")),
        ).count() if our_games else 0
        champ_name = ""
        if champion:
            p = db.query(UserProfile).filter(
                UserProfile.user_id == champion).first()
            champ_name = p.full_name_en if p else str(champion)
            champ_name += f"  ({profiles.get(champion, '?')}-like)"

    print()
    print("=" * 64)
    print(f"  status           : {status}")
    print(f"  champion         : {champ_name or '— none —'}")
    print(f"  unresolved match : {unresolved}")
    print(f"  games not ended  : {stuck}")
    print(f"  wall time        : {elapsed / 60:.1f} min")
    print("-" * 64)
    for k in sorted(stats):
        print(f"    {k:<28} {stats[k]}")
    print("-" * 64)
    # Protocol coverage: if a message never appeared, this run did not test it,
    # and saying so is more useful than a green tick that means nothing.
    for expected in ("game_start", "move", "game_over", "latency_probe",
                     "opponent_disconnected", "opponent_reconnected"):
        mark = "seen" if expected in protocol_seen else "NOT EXERCISED"
        print(f"    {expected:<28} {mark}")
    print("=" * 64)

    healthy = status == "COMPLETED" and unresolved == 0 and stuck == 0
    print("  RESULT:", "tournament completed cleanly"
          if healthy else "PROBLEMS — see above")
    return 0 if healthy else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
