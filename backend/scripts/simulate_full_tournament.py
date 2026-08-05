"""
End-to-end simulation of a full knockout chess tournament.

Drives a seeded tournament from round 1 to a champion with every match played
over a real WebSocket against the running server — the same path a phone takes.
Reports concurrency, wall time, and any board that failed to resolve.

Usage (server must already be running):
    python scripts/seed_large_chess_tournament.py
    python scripts/simulate_full_tournament.py [--max-plies 80]
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
from app.core.security import create_access_token  # noqa: E402
from app.models.chess import ChessGame  # noqa: E402
from app.models.chess_tournament import (  # noqa: E402
    ChessTournament,
    ChessTournamentMatch,
)

API = "http://127.0.0.1:8000/api/v1"
WS = "ws://127.0.0.1:8000/api/v1"

stats = Counter()
peak_concurrent = 0
_live = 0


def _token(user_id, org_id):
    return create_access_token(str(user_id), "USER", str(org_id))


def _hdr(user_id, org_id):
    return {
        "Authorization": f"Bearer {_token(user_id, org_id)}",
        "X-Organization-ID": str(org_id),
    }


async def play_game(game_id, white_id, black_id, org_id, max_plies):
    """Both players connect and play random legal moves until the game ends."""
    global _live, peak_concurrent
    done = asyncio.Event()
    result_holder = {}

    async def side(uid, my_colour):
        # Each side keeps its OWN board. Sharing one between both coroutines
        # desynced them, producing illegal moves that stalled the game.
        board = chess.Board()
        # The server sends both `state` and `game_start` for the same position,
        # so acting on every message made a bot move twice for one ply ("Not
        # your turn" / illegal move, then a stalled board). The real client has
        # a moveInFlight guard; this is its equivalent — one move per ply.
        last_sent_ply = -1
        token = _token(uid, org_id)
        uri = f"{WS}/chess/games/{game_id}/ws?token={token}"
        async with websockets.connect(uri, ping_interval=None) as ws:
            while not done.is_set():
                try:
                    msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=60))
                except asyncio.TimeoutError:
                    stats["ws_timeout"] += 1
                    done.set()
                    return
                except websockets.ConnectionClosed:
                    return

                t = msg.get("type")
                if t == "error":
                    # Recover from any desync by asking the server for the
                    # authoritative position instead of stalling forever.
                    stats[f"err:{msg.get('message','?')[:24]}"] += 1
                    await ws.send(json.dumps({"type": "sync"}))
                    continue
                if t == "game_over":
                    result_holder["result"] = msg.get("result")
                    result_holder["reason"] = msg.get("reason")
                    done.set()
                    return
                if t not in ("game_start", "state", "move"):
                    continue

                fen = msg.get("fen")
                if fen:
                    board.set_fen(fen)
                turn = "white" if board.turn else "black"
                if turn != my_colour:
                    continue
                if board.ply() == last_sent_ply:
                    continue          # already moved for this position
                last_sent_ply = board.ply()
                if board.ply() >= max_plies:
                    # Keep the simulation bounded while still exercising a
                    # real terminal path through the server.
                    await ws.send(json.dumps({"type": "resign"}))
                    continue
                legal = list(board.legal_moves)
                if not legal:
                    continue
                # Prefer mates/captures so games converge instead of
                # shuffling to the 75-move rule.
                mates = [m for m in legal if board.gives_check(m)]
                caps = [m for m in legal if board.is_capture(m)]
                pool = mates or caps or legal
                await ws.send(json.dumps({
                    "type": "move", "uci": random.choice(pool).uci(),
                }))

    _live += 1
    peak_concurrent = max(peak_concurrent, _live)
    try:
        await asyncio.gather(
            side(white_id, "white"), side(black_id, "black"),
            return_exceptions=True,
        )
    finally:
        _live -= 1

    stats[f"result:{result_holder.get('result','UNRESOLVED')}"] += 1
    stats[f"reason:{result_holder.get('reason','none')}"] += 1
    return result_holder


async def run_round(tour_id, org_id, rnd, max_plies):
    """Ready + start + play every activated match in this round, concurrently."""
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
        return 0

    async with httpx.AsyncClient(timeout=30) as client:
        # Both players acknowledge readiness, then one opens the board.
        for mid, a, b in pending:
            for uid in (a, b):
                r = await client.post(
                    f"{API}/chess/tournaments/{tour_id}/matches/{mid}/ready",
                    headers=_hdr(uid, org_id))
                if r.status_code >= 400:
                    stats[f"ready_fail:{r.status_code}"] += 1
            r = await client.post(
                f"{API}/chess/tournaments/{tour_id}/matches/{mid}/play",
                headers=_hdr(a, org_id))
            if r.status_code >= 400:
                stats[f"play_fail:{r.status_code}"] += 1

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

    print(f"  round {rnd}: {len(games)} games running concurrently…")
    await asyncio.gather(*[
        play_game(g, a, b, org_id, max_plies) for g, a, b in games
    ], return_exceptions=True)
    return len(games)


def activate_round(tour_id, rnd):
    """Mimic the organizer pressing 'Start Next Round'."""
    with SessionLocal() as db:
        tour = db.query(ChessTournament).filter(ChessTournament.id == tour_id).first()
        ms = (
            db.query(ChessTournamentMatch)
            .filter(ChessTournamentMatch.tournament_id == tour_id,
                    ChessTournamentMatch.round == rnd).all()
        )
        for m in ms:
            m.activated = True
            m.activated_at = datetime.now(timezone.utc)
            if m.player_a_id and m.player_b_id and m.winner_id is None:
                m.status = "READY"
        tour.current_round = rnd
        tour.status = "IN_PROGRESS"
        db.commit()
        return len([m for m in ms if m.winner_id is None and m.player_a_id and m.player_b_id])


def resolve(tour_id):
    """Advance the bracket for any finished game (what the detail endpoint does)."""
    from app.routers.chess_tournaments import _auto_resolve
    with SessionLocal() as db:
        tour = db.query(ChessTournament).filter(ChessTournament.id == tour_id).first()
        _auto_resolve(db, tour)
        db.refresh(tour)
        return tour.status, tour.champion_id


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-plies", type=int, default=80)
    args = ap.parse_args()

    with SessionLocal() as db:
        tour = (
            db.query(ChessTournament)
            .filter(ChessTournament.short_code == "MEGA100").first()
        )
        if not tour:
            print("No MEGA100 tournament — run seed_large_chess_tournament.py first.")
            return 1
        tour_id, org_id = tour.id, tour.organization_id
        total_rounds = max(
            r[0] for r in db.query(ChessTournamentMatch.round)
            .filter(ChessTournamentMatch.tournament_id == tour_id).all()
        )

    print(f"Tournament {tour_id}  ({total_rounds} rounds)")
    t0 = time.time()

    for rnd in range(1, total_rounds + 1):
        n = activate_round(tour_id, rnd)
        if n:
            await run_round(tour_id, org_id, rnd, args.max_plies)
        resolve(tour_id)

    status, champion = resolve(tour_id)
    elapsed = time.time() - t0

    with SessionLocal() as db:
        unresolved = (
            db.query(ChessTournamentMatch)
            .filter(ChessTournamentMatch.tournament_id == tour_id,
                    ChessTournamentMatch.winner_id.is_(None)).count()
        )
        stuck = (
            db.query(ChessGame)
            .filter(ChessGame.status.in_(("waiting", "in_progress"))).count()
        )
        name = ""
        if champion:
            from app.models.user import UserProfile
            p = db.query(UserProfile).filter(UserProfile.user_id == champion).first()
            name = p.full_name_en if p else str(champion)

    print("\n" + "=" * 52)
    print(f"status           : {status}")
    print(f"champion         : {name or '— none —'}")
    print(f"unresolved match : {unresolved}")
    print(f"games not ended  : {stuck}")
    print(f"peak concurrency : {peak_concurrent} games")
    print(f"wall time        : {elapsed:.1f}s")
    print("-" * 52)
    for k, v in sorted(stats.items()):
        print(f"  {k:<34} {v}")
    print("=" * 52)
    return 0 if (status == "COMPLETED" and unresolved == 0 and stuck == 0) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
