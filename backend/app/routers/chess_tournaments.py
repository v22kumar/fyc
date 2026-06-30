import math
import random
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.chess_tournament import (
    ChessTournament,
    ChessTournamentEntry,
    ChessTournamentMatch,
)
from app.models.chess import ChessGame
from app.models.user import User
from app.schemas.chess_tournament import (
    ChessTournamentCreate,
    ChessTournamentOut,
    ChessTournamentDetailOut,
    MatchOut,
    PlayerRef,
    ReportResultIn,
)
from app.dependencies import get_current_user, get_current_user_optional, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/chess/tournaments", tags=["Chess Tournaments"])

require_exec = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


# ── name helpers ─────────────────────────────────────────────────────────────
def _name(u: Optional[User]) -> str:
    if not u:
        return "Player"
    p = getattr(u, "profile", None)
    if p:
        return p.full_name_en or p.full_name_ta or "Player"
    return "Player"


def _ref(db: Session, user_id) -> Optional[PlayerRef]:
    if not user_id:
        return None
    u = db.query(User).filter(User.id == user_id).first()
    return PlayerRef(id=user_id, name=_name(u))


# ── bracket helpers ──────────────────────────────────────────────────────────
def _advance(db: Session, tour: ChessTournament, match: ChessTournamentMatch, winner_id):
    """Record a winner and push them into the next round (or crown champion)."""
    match.winner_id = winner_id
    if match.status != "BYE":
        match.status = "DONE"
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
        return
    if match.slot % 2 == 0:
        nxt.player_a_id = winner_id
    else:
        nxt.player_b_id = winner_id
    if nxt.player_a_id and nxt.player_b_id:
        nxt.status = "READY"


def _auto_resolve(db: Session, tour: ChessTournament):
    """Resolve any LIVE match whose linked Arena game has finished."""
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
    changed = False
    for m in live:
        g = db.query(ChessGame).filter(ChessGame.id == m.game_id).first()
        if not g or not g.result:
            continue
        if g.result == "white_wins":
            _advance(db, tour, m, m.player_a_id)
            changed = True
        elif g.result == "black_wins":
            _advance(db, tour, m, m.player_b_id)
            changed = True
        # draws are left LIVE — a replay/decider is needed (admin can report).
    if changed:
        db.commit()


def _serialize(db: Session, tour: ChessTournament, user_id) -> ChessTournamentOut:
    count = (
        db.query(func.count(ChessTournamentEntry.id))
        .filter(ChessTournamentEntry.tournament_id == tour.id)
        .scalar()
        or 0
    )
    registered = False
    if user_id:
        registered = (
            db.query(ChessTournamentEntry.id)
            .filter(
                ChessTournamentEntry.tournament_id == tour.id,
                ChessTournamentEntry.user_id == user_id,
            )
            .first()
            is not None
        )
    return ChessTournamentOut(
        id=tour.id,
        name=tour.name,
        description=tour.description,
        status=tour.status,
        registration_deadline=tour.registration_deadline,
        entry_count=count,
        is_registered=registered,
        champion=_ref(db, tour.champion_id),
        created_at=tour.created_at,
    )


# ── endpoints ────────────────────────────────────────────────────────────────
@router.get("", response_model=List[ChessTournamentOut])
def list_tournaments(
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    rows = (
        db.query(ChessTournament)
        .filter(ChessTournament.organization_id == tenant_id)
        .order_by(ChessTournament.created_at.desc())
        .all()
    )
    cid = current_user.id if current_user else None
    return [_serialize(db, t, cid) for t in rows]


@router.post("", response_model=ChessTournamentOut, status_code=status.HTTP_201_CREATED)
def create_tournament(
    payload: ChessTournamentCreate,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    name = (payload.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    tour = ChessTournament(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        name=name,
        description=(payload.description or "").strip() or None,
        registration_deadline=payload.registration_deadline,
        status="REGISTRATION_OPEN",
        created_by_user_id=current_user.id,
    )
    db.add(tour)
    db.commit()
    db.refresh(tour)
    return _serialize(db, tour, current_user.id)


@router.post("/{tour_id}/register", response_model=ChessTournamentOut)
def register(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    tour = (
        db.query(ChessTournament)
        .filter(ChessTournament.id == tour_id, ChessTournament.organization_id == tenant_id)
        .first()
    )
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
    if tour.status != "REGISTRATION_OPEN":
        raise HTTPException(status_code=400, detail="Registration is closed")
    if tour.registration_deadline and datetime.now(timezone.utc) > tour.registration_deadline:
        raise HTTPException(status_code=400, detail="Registration deadline has passed")
    existing = (
        db.query(ChessTournamentEntry)
        .filter(
            ChessTournamentEntry.tournament_id == tour_id,
            ChessTournamentEntry.user_id == current_user.id,
        )
        .first()
    )
    if not existing:
        db.add(
            ChessTournamentEntry(
                id=uuid.uuid4(),
                organization_id=tenant_id,
                tournament_id=tour_id,
                user_id=current_user.id,
            )
        )
        db.commit()
    return _serialize(db, tour, current_user.id)


@router.post("/{tour_id}/start", response_model=ChessTournamentDetailOut)
def start_tournament(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    tour = (
        db.query(ChessTournament)
        .filter(ChessTournament.id == tour_id, ChessTournament.organization_id == tenant_id)
        .first()
    )
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
    if tour.status != "REGISTRATION_OPEN":
        raise HTTPException(status_code=400, detail="Tournament already started")

    entries = (
        db.query(ChessTournamentEntry)
        .filter(ChessTournamentEntry.tournament_id == tour_id)
        .all()
    )
    players = [e.user_id for e in entries]
    if len(players) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 registered players")

    random.shuffle(players)
    n = len(players)
    size = 1 << (n - 1).bit_length()  # next power of 2 >= n
    rounds = size.bit_length() - 1
    padded = players + [None] * (size - n)

    # Create empty matches for every round.
    matches = {}  # (round, slot) -> ChessTournamentMatch
    for r in range(1, rounds + 1):
        for s in range(size // (2 ** r)):
            m = ChessTournamentMatch(
                id=uuid.uuid4(),
                organization_id=tenant_id,
                tournament_id=tour_id,
                round=r,
                slot=s,
                status="PENDING",
            )
            matches[(r, s)] = m
            db.add(m)

    # Seed round 1 by pairing front-with-back so byes face real players.
    for s in range(size // 2):
        a = padded[s]
        b = padded[size - 1 - s]
        m = matches[(1, s)]
        m.player_a_id = a
        m.player_b_id = b
        if a and b:
            m.status = "READY"
        elif a and not b:
            m.status = "BYE"  # auto-advance below
        else:
            m.status = "PENDING"

    tour.status = "IN_PROGRESS"
    db.flush()

    # Auto-advance byes into round 2.
    for s in range(size // 2):
        m = matches[(1, s)]
        if m.status == "BYE" and m.player_a_id:
            _advance(db, tour, m, m.player_a_id)

    db.commit()
    return _detail(db, tour, current_user.id)


@router.get("/{tour_id}", response_model=ChessTournamentDetailOut)
def get_tournament(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    tour = (
        db.query(ChessTournament)
        .filter(ChessTournament.id == tour_id, ChessTournament.organization_id == tenant_id)
        .first()
    )
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
    _auto_resolve(db, tour)  # pick up finished Arena games
    return _detail(db, tour, current_user.id if current_user else None)


@router.post("/{tour_id}/matches/{match_id}/play")
def play_match(
    tour_id: uuid.UUID,
    match_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Create (or return) the Arena game for a ready match, then the app opens
    the online board for the returned game_id."""
    m = (
        db.query(ChessTournamentMatch)
        .filter(
            ChessTournamentMatch.id == match_id,
            ChessTournamentMatch.tournament_id == tour_id,
            ChessTournamentMatch.organization_id == tenant_id,
        )
        .first()
    )
    if not m:
        raise HTTPException(status_code=404, detail="Match not found")
    if m.winner_id:
        raise HTTPException(status_code=400, detail="Match already decided")
    if not (m.player_a_id and m.player_b_id):
        raise HTTPException(status_code=400, detail="Match is not ready")
    if current_user.id not in (m.player_a_id, m.player_b_id):
        raise HTTPException(status_code=403, detail="You are not in this match")

    if m.game_id is None:
        game = ChessGame(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            white_id=m.player_a_id,
            black_id=m.player_b_id,
            mode="online",
            status="waiting",
            time_control="untimed",
        )
        db.add(game)
        m.game_id = game.id
        m.status = "LIVE"
        db.commit()
    return {"game_id": str(m.game_id)}


@router.post("/{tour_id}/matches/{match_id}/result", response_model=ChessTournamentDetailOut)
def report_result(
    tour_id: uuid.UUID,
    match_id: uuid.UUID,
    payload: ReportResultIn,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Admin/manager override — record a winner (e.g. a physical final or a draw
    decider) and advance the bracket."""
    tour = (
        db.query(ChessTournament)
        .filter(ChessTournament.id == tour_id, ChessTournament.organization_id == tenant_id)
        .first()
    )
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
    m = (
        db.query(ChessTournamentMatch)
        .filter(ChessTournamentMatch.id == match_id, ChessTournamentMatch.tournament_id == tour_id)
        .first()
    )
    if not m:
        raise HTTPException(status_code=404, detail="Match not found")
    if payload.winner_id not in (m.player_a_id, m.player_b_id):
        raise HTTPException(status_code=400, detail="Winner must be one of the two players")
    _advance(db, tour, m, payload.winner_id)
    db.commit()
    return _detail(db, tour, current_user.id)


def _detail(db: Session, tour: ChessTournament, user_id) -> ChessTournamentDetailOut:
    base = _serialize(db, tour, user_id)
    entries = (
        db.query(ChessTournamentEntry)
        .filter(ChessTournamentEntry.tournament_id == tour.id)
        .all()
    )
    entry_refs = [_ref(db, e.user_id) for e in entries]
    matches = (
        db.query(ChessTournamentMatch)
        .filter(ChessTournamentMatch.tournament_id == tour.id)
        .order_by(ChessTournamentMatch.round.asc(), ChessTournamentMatch.slot.asc())
        .all()
    )
    rounds = max([m.round for m in matches], default=0)
    match_out = [
        MatchOut(
            id=m.id,
            round=m.round,
            slot=m.slot,
            player_a=_ref(db, m.player_a_id),
            player_b=_ref(db, m.player_b_id),
            winner_id=m.winner_id,
            game_id=m.game_id,
            status=m.status,
        )
        for m in matches
    ]
    return ChessTournamentDetailOut(
        **base.model_dump(),
        entries=[r for r in entry_refs if r],
        rounds=rounds,
        matches=match_out,
    )
