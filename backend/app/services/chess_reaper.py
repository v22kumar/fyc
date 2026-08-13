"""
Chess reaper — the safety net that stops a stalled board from freezing a round.

Live games are driven by the WebSocket handler, but that handler only acts while
someone is connected. Three situations previously left a game `in_progress`
forever, which in a knockout bracket blocks the whole round from advancing:

  1. A player's clock expired while they were away — nothing decremented it.
  2. Both players disconnected — the 60s forfeit timer is an in-memory asyncio
     task, so it dies with the process on any redeploy.
  3. A game was created but never started (nobody ever connected).

This job runs on the scheduler, adjudicates those games from the DURABLE clock,
and then advances any tournament bracket whose match just became decided. It is
deliberately conservative: it never touches a game that still has a live
in-memory session with a connected player, so it can never race the WS handler.
"""
import logging
from datetime import datetime, timedelta, timezone

from starlette.concurrency import run_in_threadpool

from app.core.database import SessionLocal
from app.models.chess import ChessChallenge, ChessGame, ChessMove
from app.services.chess_ws_manager import ws_manager

logger = logging.getLogger(__name__)

# A timed game is only reaped once it has been expired for this long, so the
# WebSocket handler (which adjudicates instantly) always gets first refusal.
FLAG_GRACE_SECONDS = 30

# An untimed or never-started game with no activity for this long is treated as
# abandoned. Generous on purpose: a real game should never hit it.
ABANDON_AFTER_SECONDS = 6 * 3600

# How long a session may sit with nobody attached before it is evicted.
SESSION_IDLE_SECONDS = 3600


def _aware(dt):
    """Normalise a possibly-naive DB datetime (SQLite) to timezone-aware UTC."""
    if dt is None:
        return None
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)


def _has_live_players(game_id) -> bool:
    """True if an in-memory session for this game still has a player connected —
    in which case the WS handler owns adjudication and we must not interfere."""
    session = ws_manager.get(str(game_id))
    return bool(session and session.connections)


def _reap_once() -> dict:
    """One synchronous pass. Returns a small summary for logging."""
    from app.routers.chess import _update_stats  # lazy: avoids a router↔service cycle

    now = datetime.now(timezone.utc)
    timed_out = 0
    abandoned = 0

    with SessionLocal() as db:
        games = (
            db.query(ChessGame)
            .filter(
                ChessGame.status.in_(("waiting", "in_progress")),
                ChessGame.mode == "online",
            )
            .all()
        )

        for g in games:
            if _has_live_players(g.id):
                continue

            last_move_at = _aware(g.last_move_at)
            is_timed = g.white_time_ms is not None and g.black_time_ms is not None

            # ── 1. Clock expiry ────────────────────────────────────────────────
            if is_timed and last_move_at is not None:
                move_count = (
                    db.query(ChessMove).filter(ChessMove.game_id == g.id).count()
                )
                # White moves on even ply counts (0, 2, 4 …).
                turn_is_white = move_count % 2 == 0
                banked = g.white_time_ms if turn_is_white else g.black_time_ms
                elapsed_ms = int((now - last_move_at).total_seconds() * 1000)
                remaining_ms = (banked or 0) - elapsed_ms

                if remaining_ms <= -(FLAG_GRACE_SECONDS * 1000):
                    g.result = "white_wins" if not turn_is_white else "black_wins"
                    g.draw_reason = "time"
                    g.status = "ended"
                    g.total_moves = move_count
                    g.ended_at = now
                    _update_stats(db, g, g.organization_id)
                    timed_out += 1
                    logger.info(
                        f"[chess-reaper] game {g.id} decided on time "
                        f"({'black' if turn_is_white else 'white'} wins)"
                    )
                    continue

            # ── 2. Abandonment ────────────────────────────────────────────────
            idle_since = last_move_at or _aware(g.started_at) or _aware(g.created_at)
            if idle_since is None:
                continue
            if now - idle_since > timedelta(seconds=ABANDON_AFTER_SECONDS):
                # No winner is invented: an abandoned game is left for the
                # organizer to settle (walkover claim / manual result), and it is
                # deliberately NOT rated — _update_stats would score it as a
                # double loss, which is not what an abandonment means.
                g.result = "abandoned"
                g.status = "ended"
                g.ended_at = now
                abandoned += 1
                logger.info(f"[chess-reaper] game {g.id} marked abandoned (idle)")

        if timed_out or abandoned:
            db.commit()

    # ── 3. Advance any bracket whose match just became decided ────────────────
    advanced = 0
    if timed_out:
        from app.models.chess_tournament import ChessTournament
        from app.routers.chess_tournaments import _auto_resolve

        with SessionLocal() as db:
            tours = (
                db.query(ChessTournament)
                .filter(ChessTournament.status == "IN_PROGRESS")
                .all()
            )
            for t in tours:
                try:
                    _auto_resolve(db, t)
                    advanced += 1
                except Exception as e:  # noqa: BLE001
                    logger.warning(f"[chess-reaper] auto-resolve failed for {t.id}: {e}")

    # ── 4. Challenges nobody answered ─────────────────────────────────────
    #
    # The lists already refuse to show these, so this changes nothing a member
    # can see. It stops the table growing without bound, and it means the row's
    # status tells the truth if anybody ever reads it — "pending" for a game
    # invitation sent last month is a lie that a query filter alone would leave
    # sitting in the database.
    challenges_expired = 0
    with SessionLocal() as db:
        from app.routers.chess import _live_challenge_cutoff  # lazy: router↔service cycle

        challenges_expired = (
            db.query(ChessChallenge)
            .filter(
                ChessChallenge.status == "pending",
                ChessChallenge.created_at < _live_challenge_cutoff(),
            )
            .update({"status": "expired"}, synchronize_session=False)
        )
        if challenges_expired:
            db.commit()

    evicted = ws_manager.sweep(max_idle_seconds=SESSION_IDLE_SECONDS)
    return {
        "timed_out": timed_out,
        "abandoned": abandoned,
        "tournaments_checked": advanced,
        "challenges_expired": challenges_expired,
        "sessions_evicted": evicted,
    }


async def run_chess_reaper() -> None:
    """Scheduler entry point. Never raises — a failed sweep must not kill the job."""
    try:
        summary = await run_in_threadpool(_reap_once)
        if any(v for v in summary.values()):
            logger.info(f"[chess-reaper] {summary}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"[chess-reaper] pass failed: {e}")
