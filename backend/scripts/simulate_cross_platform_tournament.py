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
        # Earlier versions of this script created the tournament through the
        # API, which posts a "registration open" notice to the members' board.
        # Remove any of those too, so a soak run leaves nothing members can see.
        announcements = 0
        try:
            from app.models.announcement import Announcement
            rows = db.query(Announcement).filter(
                Announcement.organization_id == org.id,
                Announcement.title_en.like(f"%{TOURNAMENT_NAME_PREFIX}%"),
            ).all()
            announcements = len(rows)
            for a in rows:
                db.delete(a)
            db.commit()
        except Exception as e:  # noqa: BLE001
            db.rollback()
            log(f"could not remove announcements: {e}")

        log(f"cleaned: {len(tours)} tournament(s), {len(games)} game(s), "
            f"{len(bot_ids)} bot account(s), {announcements} announcement(s)")



def _build_tournament_silently(org_id, admin_id, name, player_ids, time_control):
    """Create the tournament, entries and full bracket with direct writes.

    Mirrors what POST /start does — power-of-two bracket, byes distributed, byes
    auto-advanced — but without the member-facing side effects.
    """
    import math
    with SessionLocal() as db:
        tour = ChessTournament(
            id=uuid.uuid4(), organization_id=org_id, name=name,
            description="Cross-platform soak test",
            status="IN_PROGRESS", current_round=0,
            time_control=time_control, created_by_user_id=admin_id,
        )
        db.add(tour)
        db.flush()
        for uid in player_ids:
            db.add(ChessTournamentEntry(
                id=uuid.uuid4(), organization_id=org_id,
                tournament_id=tour.id, user_id=uid, status="APPROVED"))
        db.flush()

        players = list(player_ids)
        random.shuffle(players)
        depth = math.ceil(math.log2(max(2, len(players))))
        bracket = 2 ** depth
        byes = bracket - len(players)

        slots = [None] * bracket
        for i in range(byes):
            slots[i * 2] = "BYE"
        p = 0
        for i in range(bracket):
            if slots[i] != "BYE":
                slots[i] = players[p]
                p += 1

        for i in range(0, bracket, 2):
            a, b = slots[i], slots[i + 1]
            status, winner = "PENDING", None
            if a == "BYE" and b != "BYE":
                status, winner, a = "BYE", b, None
            elif b == "BYE" and a != "BYE":
                status, winner, b = "BYE", a, None
            db.add(ChessTournamentMatch(
                id=uuid.uuid4(), organization_id=org_id, tournament_id=tour.id,
                round=1, slot=i // 2, player_a_id=a, player_b_id=b,
                winner_id=winner, status=status, conduct_mode="APP",
                activated=False))
        # Empty shells for later rounds, filled as winners advance.
        size = bracket // 2
        rnd = 2
        while size > 1:
            size //= 2
            for slot in range(size):
                db.add(ChessTournamentMatch(
                    id=uuid.uuid4(), organization_id=org_id,
                    tournament_id=tour.id, round=rnd, slot=slot,
                    status="PENDING", conduct_mode="APP", activated=False))
            rnd += 1
        db.commit()

        # Carry byes into round 2 so those slots are not left empty.
        from app.routers.chess_tournaments import _advance
        tour = db.query(ChessTournament).filter(
            ChessTournament.id == tour.id).first()
        for m in db.query(ChessTournamentMatch).filter(
                ChessTournamentMatch.tournament_id == tour.id,
                ChessTournamentMatch.status == "BYE").all():
            _advance(db, tour, m, m.winner_id)
        db.commit()
        return str(tour.id)


def _round_count(tour_id) -> int:
    with SessionLocal() as db:
        return max((m.round for m in db.query(ChessTournamentMatch).filter(
            ChessTournamentMatch.tournament_id == tour_id).all()), default=0)



async def api_post(client, url, headers, what, retries=3):
    """POST with retries and an honest failure message.

    A soak test that dies with a raw traceback teaches nothing. Time out, say
    which call and how long it waited, and carry on where possible.
    """
    for attempt in range(1, retries + 1):
        try:
            r = await client.post(url, headers=headers)
            if r.status_code >= 400:
                stats[f"http_{r.status_code}:{what}"] += 1
                log(f"    {what} -> HTTP {r.status_code}: {r.text[:120]}")
            return r
        except Exception as e:  # noqa: BLE001
            stats[f"http_timeout:{what}"] += 1
            log(f"    {what} attempt {attempt}/{retries} failed: "
                f"{type(e).__name__} — the server did not answer in time")
            if attempt == retries:
                return None
            await asyncio.sleep(2.0 * attempt)
    return None


async def preflight(api, headers):
    """Check the server answers, and how fast, before blaming the test."""
    async with httpx.AsyncClient(timeout=20) as client:
        for label, url in (("health", f"{api}/api/health"),):
            t = time.time()
            try:
                r = await client.get(url)
                log(f"preflight {label}: HTTP {r.status_code} in "
                    f"{(time.time() - t) * 1000:.0f} ms")
            except Exception as e:  # noqa: BLE001
                log(f"preflight {label}: FAILED ({type(e).__name__}) — "
                    f"the API is not reachable at {api}")
                return False
    return True


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

    log(f"  round {rnd}: opening {len(pending)} boards…")
    async with httpx.AsyncClient(timeout=30) as client:
        for mid, a, b in pending:
            for uid in (a, b):
                await api_post(
                    client,
                    f"{api}/api/v1/chess/tournaments/{tour_id}/matches/{mid}/ready",
                    hdr(uid), "ready")
            await api_post(
                client,
                f"{api}/api/v1/chess/tournaments/{tour_id}/matches/{mid}/play",
                hdr(a), "play")

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

    # Suppress notifications raised by the bracket advancing in THIS process.
    # Without it, every decided match pushes "Chess match decided" to the real
    # organizer's phone — about thirty notifications for one soak run.
    import app.routers.chess_tournaments as ct
    ct._notify = lambda *a, **k: None

    # Build the tournament directly rather than through create/register/approve.
    # Those endpoints deliberately do member-facing things: creating one posts a
    # "registration open" announcement to the club notice board, and approving
    # each player pushes a notification. On a live server that means members see
    # a fake tournament and the organizer's phone lights up — and the blocking
    # push calls are what made this appear to hang. The endpoints are already
    # covered by simulate_full_tournament.py; what THIS script exists to test is
    # live play and reconnection.
    log("drawing the bracket (silently — no announcement, no notifications)")
    tour_id = _build_tournament_silently(org_id, admin_id, name, ids,
                                         args.time_control)
    log(f"tournament {tour_id}")
    total_rounds = _round_count(uuid.UUID(tour_id))

    # Hand back every connection this process is holding before we start calling
    # the API. The script and the server share one database; on a small Postgres
    # a handful of idle connections held here can leave the server waiting for
    # one, which looks exactly like the API hanging.
    try:
        from app.core.database import engine
        engine.dispose()
    except Exception:  # noqa: BLE001
        pass

    if not await preflight(api, admin_hdr):
        return 1

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
