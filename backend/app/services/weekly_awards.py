"""
Weekly awards computation service for FYC Chess — Sprint 9.

Queries the last 7 days of chess games (both online and local) to compute:
  - top_player: most wins this week
  - most_active: most games played this week
  - best_newcomer: < 5 total games before the week, first win this week
  - sharpest_mind: highest cumulative rating gain (white_rating_after - white_rating_before)
"""
from datetime import datetime, timedelta, timezone
from typing import Optional
from collections import defaultdict

from sqlalchemy.orm import Session

from app.models.chess import ChessGame, ChessPlayerStats
from app.models.user import User, UserProfile


def _display_name(db: Session, user_id) -> str:
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if profile:
        return profile.full_name_en or profile.full_name_ta or str(user_id)
    return str(user_id)


def compute_weekly_awards(db: Session, org_id) -> dict:
    week_start = datetime.now(tz=timezone.utc) - timedelta(days=7)

    # Fetch all ended games in the past 7 days for this org
    games = (
        db.query(ChessGame)
        .filter(
            ChessGame.organization_id == org_id,
            ChessGame.ended_at >= week_start,
            ChessGame.result.in_(["white_wins", "black_wins", "draw"]),
        )
        .all()
    )

    # ── Accumulators ─────────────────────────────────────────────────────────────
    wins: dict = defaultdict(int)          # user_id -> win count
    games_played: dict = defaultdict(int)  # user_id -> total games this week
    rating_gain: dict = defaultdict(float) # user_id -> cumulative rating delta
    week_winners: set = set()              # user_ids who won at least once

    for g in games:
        if g.white_id:
            games_played[g.white_id] += 1
            # Rating gain for white player on wins
            if (
                g.result == "white_wins"
                and g.white_rating_before is not None
                and g.white_rating_after is not None
            ):
                rating_gain[g.white_id] += g.white_rating_after - g.white_rating_before
                wins[g.white_id] += 1
                week_winners.add(g.white_id)

        if g.black_id:
            games_played[g.black_id] += 1
            if (
                g.result == "black_wins"
                and g.black_rating_before is not None
                and g.black_rating_after is not None
            ):
                rating_gain[g.black_id] += g.black_rating_after - g.black_rating_before
                wins[g.black_id] += 1
                week_winners.add(g.black_id)

    # ── top_player: most wins ─────────────────────────────────────────────────
    top_player = None
    if wins:
        best_uid = max(wins, key=lambda uid: wins[uid])
        top_player = {"user_id": str(best_uid), "name": _display_name(db, best_uid)}

    # ── most_active: most games played ───────────────────────────────────────
    most_active = None
    if games_played:
        active_uid = max(games_played, key=lambda uid: games_played[uid])
        most_active = {"user_id": str(active_uid), "name": _display_name(db, active_uid)}

    # ── best_newcomer: < 5 total games before the week, first win this week ──
    best_newcomer = None
    for uid in week_winners:
        stats = (
            db.query(ChessPlayerStats)
            .filter(ChessPlayerStats.user_id == uid)
            .first()
        )
        if stats is None:
            continue
        # Total games = all-time (materialized). Games this week were already counted.
        # Games before the week = total - games_this_week
        games_before = stats.games_played - games_played.get(uid, 0)
        if games_before < 5:
            best_newcomer = {"user_id": str(uid), "name": _display_name(db, uid)}
            break  # first match is fine; could be ranked but spec says first winner

    # ── sharpest_mind: highest cumulative rating gain ────────────────────────
    sharpest_mind = None
    if rating_gain:
        sharp_uid = max(rating_gain, key=lambda uid: rating_gain[uid])
        if rating_gain[sharp_uid] > 0:
            sharpest_mind = {
                "user_id": str(sharp_uid),
                "name": _display_name(db, sharp_uid),
            }

    return {
        "week_start": week_start.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "top_player": top_player,
        "most_active": most_active,
        "best_newcomer": best_newcomer,
        "sharpest_mind": sharpest_mind,
    }
