"""How a knockout tournament moves, separated from how it is served.

Everything here was written inline in `routers/chess_tournaments.py`, which had
grown to 1083 lines — the largest router in the codebase — with the bracket
rules living between HTTP concerns. The rules were *correct*; they were just
somewhere a reviewer of tournament logic would not think to look, and somewhere
a second caller (the reaper, a future Swiss variant) could not reach without
importing a router.

The router still owns HTTP: auth, tenancy, serialization, status codes. This
module owns chess: seeding, advancement, resolution, and the round gate.

## The shape of the event

A knockout is a round-based queue with a blocking join: every player in the
event is waiting on the slowest match of the current round. That gives the flow
exactly four verbs —

* **draw**    — seed the bracket from the approved list
* **resolve** — read finished Arena games into match results
* **advance** — put a winner into the next round's slot
* **gate**    — refuse the next round while this one has undecided matches

— and everything else in the feature is either HTTP or pixels.
"""
from __future__ import annotations

import logging
import random
import uuid
from datetime import datetime, timezone
from typing import Optional, Sequence

from sqlalchemy.orm import Session

from app.models.chess import ChessGame
from app.models.chess_tournament import (
    ChessTournament,
    ChessTournamentMatch,
)
from app.models.user import User

logger = logging.getLogger(__name__)


# ── shared helpers ───────────────────────────────────────────────────────────

def player_name(u: Optional[User]) -> str:
    if not u:
        return "Player"
    p = getattr(u, "profile", None)
    if p:
        return p.full_name_en or p.full_name_ta or "Player"
    return "Player"


def notify_player(db: Session, org_id, user_id, title_en, title_ta,
                  body_en, body_ta, data=None) -> None:
    """Best-effort single-user notification. Never breaks the primary action."""
    if not user_id:
        return
    try:
        from app.services.notification_service import NotificationService

        NotificationService(db).send_notification(
            user_id=user_id,
            organization_id=org_id,
            title_en=title_en,
            title_ta=title_ta,
            body_en=body_en,
            body_ta=body_ta,
            notification_type="TOURNAMENT",
            data=data or {},
        )
    except Exception:
        pass


def record_audit(db: Session, org_id, user_id, action_type: str, match_id,
                 old_values=None, new_values=None) -> None:
    """Append an audit row to the CURRENT transaction (committed by the caller,
    so the audit is atomic with the state change). Best-effort."""
    try:
        from app.models.audit import AuditLog

        db.add(AuditLog(
            organization_id=org_id,
            user_id=user_id,
            action_type=action_type,
            target_table="chess_tournament_matches",
            target_id=match_id,
            old_values=old_values,
            new_values=new_values,
        ))
    except Exception:
        pass


def _flag(v) -> bool:
    return bool(v) if v is not None else False


# ── draw ─────────────────────────────────────────────────────────────────────

def draw_bracket(db: Session, tour: ChessTournament, tenant_id,
                 players: Sequence) -> list[ChessTournamentMatch]:
    """Seed a single-elimination bracket for `players` and activate round 1.

    Shuffles, rounds the field up to the next power of two, creates every match
    of every round, and pairs **front-against-back so byes face real players**
    — with 5 entrants in a bracket of 8, the three byes land on three different
    seeds rather than gifting one player a free semi-final.

    Byes are auto-advanced immediately. Does not commit.
    """
    field = list(players)
    random.shuffle(field)
    n = len(field)
    size = 1 << (n - 1).bit_length()  # next power of 2 >= n
    rounds = size.bit_length() - 1
    padded = field + [None] * (size - n)

    matches: dict[tuple[int, int], ChessTournamentMatch] = {}
    for r in range(1, rounds + 1):
        for s in range(size // (2 ** r)):
            m = ChessTournamentMatch(
                id=uuid.uuid4(),
                organization_id=tenant_id,
                tournament_id=tour.id,
                round=r,
                slot=s,
                status="PENDING",
                activated=False,
            )
            matches[(r, s)] = m
            db.add(m)

    now = datetime.now(timezone.utc)
    for s in range(size // 2):
        a = padded[s]
        b = padded[size - 1 - s]
        m = matches[(1, s)]
        m.player_a_id = a
        m.player_b_id = b
        m.activated = True  # round 1 goes live when the tournament starts
        m.activated_at = now
        if a and b:
            m.status = "READY"
        elif a and not b:
            m.status = "BYE"
        else:
            m.status = "PENDING"

    tour.status = "IN_PROGRESS"
    tour.current_round = 1
    db.flush()

    for s in range(size // 2):
        m = matches[(1, s)]
        if m.status == "BYE" and m.player_a_id:
            advance(db, tour, m, m.player_a_id)

    return list(matches.values())


# ── advance ──────────────────────────────────────────────────────────────────

def advance(db: Session, tour: ChessTournament, match: ChessTournamentMatch,
            winner_id) -> None:
    """Record a winner and place them in the next round's slot.

    Does NOT activate the next round — that is the manager's explicit
    "Start Next Round" decision, because a round beginning is a thing a person
    announces to a room, not a thing a database does behind their back.

    With no next round, the winner is the champion and the tournament ends.
    """
    was_bye = match.status == "BYE"
    match.winner_id = winner_id
    match.completed_at = datetime.now(timezone.utc)
    if not was_bye:
        match.status = "DONE"

        winner = db.query(User).filter(User.id == winner_id).first()
        wname = player_name(winner)
        notify_player(
            db, tour.organization_id, tour.created_by_user_id,
            "Chess match decided", "செஸ் ஆட்டம் முடிந்தது",
            f"{wname} won a match in {tour.name}.",
            f"{tour.name} போட்டியில் {wname} வென்றார்.",
            {"route": f"/chess/tournaments/{tour.id}"},
        )

    nxt = (
        db.query(ChessTournamentMatch)
        .filter(
            ChessTournamentMatch.tournament_id == tour.id,
            ChessTournamentMatch.round == match.round + 1,
            ChessTournamentMatch.slot == match.slot // 2,
        )
        .first()
    )
    if nxt is None:
        tour.champion_id = winner_id
        tour.status = "COMPLETED"
        notify_player(
            db, tour.organization_id, winner_id,
            "🏆 You are the champion!", "🏆 நீங்கள் வெற்றியாளர்!",
            f"You won {tour.name}. Congratulations!",
            f"{tour.name} போட்டியில் நீங்கள் வென்றீர்கள்! வாழ்த்துக்கள்!",
            {"route": f"/chess/tournaments/{tour.id}"},
        )
        notify_player(
            db, tour.organization_id, tour.created_by_user_id,
            "Tournament complete", "போட்டி முடிந்தது",
            f"{tour.name} has a champion.",
            f"{tour.name} போட்டிக்கு வெற்றியாளர் கிடைத்தார்.",
            {"route": f"/chess/tournaments/{tour.id}"},
        )
        return

    if match.slot % 2 == 0:
        nxt.player_a_id = winner_id
    else:
        nxt.player_b_id = winner_id
    # Only READY if the manager has already activated that round.
    if _flag(nxt.activated) and nxt.player_a_id and nxt.player_b_id:
        nxt.status = "READY"


# ── resolve ──────────────────────────────────────────────────────────────────

def auto_resolve(db: Session, tour: ChessTournament) -> bool:
    """Read finished Arena games into the bracket. Returns True if anything
    changed (the caller commits).

    Decisive games advance the winner. **A drawn game sends the match to a
    replay**: the game link is cleared, both ready flags reset, and both
    players told to play again.

    Draws used to be skipped with a comment that "a replay/decider is needed" —
    and no replay path existed. The match sat LIVE forever, `next-round`
    refuses while anything is undecided, so one drawn game stalled the whole
    event. Draws are common in chess; in a club knockout the ordinary answer is
    the one a person at the board would give: *play again* — with the
    organiser's result override still available as the tiebreak of last resort.
    The drawn game's id is kept in an audit row, so history survives the
    cleared link.
    """
    live = (
        db.query(ChessTournamentMatch)
        .filter(
            ChessTournamentMatch.tournament_id == tour.id,
            ChessTournamentMatch.status == "LIVE",
            ChessTournamentMatch.game_id.isnot(None),
            ChessTournamentMatch.winner_id.is_(None),
        )
        .all()
    )
    # Round one of a 100-player draw is 50 live matches, and this runs on every
    # read of the tournament — fetch the games together, not one at a time.
    games = {}
    if live:
        for g in (db.query(ChessGame)
                  .filter(ChessGame.id.in_([m.game_id for m in live]))
                  .all()):
            games[g.id] = g

    changed = False
    for m in live:
        g = games.get(m.game_id)
        if not g or not g.result:
            continue
        if g.result == "white_wins":
            advance(db, tour, m, m.player_a_id)
            changed = True
        elif g.result == "black_wins":
            advance(db, tour, m, m.player_b_id)
            changed = True
        elif g.result == "draw":
            _send_to_replay(db, tour, m, g)
            changed = True
    return changed


def _send_to_replay(db: Session, tour: ChessTournament,
                    m: ChessTournamentMatch, game: ChessGame) -> None:
    record_audit(
        db, tour.organization_id, None, "CHESS_MATCH_DRAWN_REPLAY", m.id,
        {"game_id": str(game.id)},
        {"action": "replay", "reason": "draw"},
    )
    m.game_id = None
    m.a_ready = False
    m.b_ready = False
    m.status = "READY"
    for pid in (m.player_a_id, m.player_b_id):
        notify_player(
            db, tour.organization_id, pid,
            "Drawn — play again ♟️", "சமன் — மீண்டும் விளையாடுங்கள் ♟️",
            f"Your {tour.name} game was a draw. Mark ready to replay; "
            f"the organizer can also decide the tie.",
            f"{tour.name} ஆட்டம் சமனில் முடிந்தது. மீண்டும் விளையாட தயாராகுங்கள்.",
            {"route": f"/chess/tournaments/{tour.id}"},
        )


# ── gate ─────────────────────────────────────────────────────────────────────

def undecided_in_round(matches: Sequence[ChessTournamentMatch],
                       round_no: int) -> list[ChessTournamentMatch]:
    """The matches that block a round from ending. Byes never block."""
    return [
        m for m in matches
        if m.round == round_no and m.winner_id is None and m.status != "BYE"
    ]
