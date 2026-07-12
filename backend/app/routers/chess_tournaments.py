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
    EntryOut,
    MatchOut,
    PlayerRef,
    ReportResultIn,
    RegistrationDecisionIn,
    ConductModeIn,
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


def _estatus(e: ChessTournamentEntry) -> str:
    """A null status (legacy row added by schema-reconcile) counts as APPROVED so
    pre-existing registrations are never stranded."""
    return e.status or "APPROVED"


def _bool(v) -> bool:
    return bool(v) if v is not None else False


def _notify(db: Session, org_id, user_id, title_en, title_ta, body_en, body_ta, data=None):
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


# ── bracket helpers ──────────────────────────────────────────────────────────
def _advance(db: Session, tour: ChessTournament, match: ChessTournamentMatch, winner_id):
    """Record a winner and place them in the next round slot. Does NOT activate
    the next round — that is the manager's manual "Start Next Round" decision.
    Auto-records the result and notifies the organizer for real (non-bye) matches."""
    was_bye = match.status == "BYE"
    match.winner_id = winner_id
    match.completed_at = datetime.now(timezone.utc)
    if not was_bye:
        match.status = "DONE"

    if not was_bye:
        winner = db.query(User).filter(User.id == winner_id).first()
        wname = _name(winner)
        _notify(
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
        # Congratulate the champion and let the organizer know it's a wrap.
        _notify(
            db, tour.organization_id, winner_id,
            "🏆 You are the champion!", "🏆 நீங்கள் வெற்றியாளர்!",
            f"You won {tour.name}. Congratulations!",
            f"{tour.name} போட்டியில் நீங்கள் வென்றீர்கள்! வாழ்த்துக்கள்!",
            {"route": f"/chess/tournaments/{tour.id}"},
        )
        _notify(
            db, tour.organization_id, tour.created_by_user_id,
            "Tournament complete", "போட்டி முடிந்தது",
            f"{tour.name} has a champion.", f"{tour.name} போட்டிக்கு வெற்றியாளர் கிடைத்தார்.",
            {"route": f"/chess/tournaments/{tour.id}"},
        )
        return

    if match.slot % 2 == 0:
        nxt.player_a_id = winner_id
    else:
        nxt.player_b_id = winner_id
    # Only mark READY if the manager has already activated that round (normally
    # they haven't yet — the round is activated later via Start Next Round).
    if _bool(nxt.activated) and nxt.player_a_id and nxt.player_b_id:
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


def _entries(db: Session, tour_id):
    return (
        db.query(ChessTournamentEntry)
        .filter(ChessTournamentEntry.tournament_id == tour_id)
        .all()
    )


def _serialize(db: Session, tour: ChessTournament, user_id) -> ChessTournamentOut:
    entries = _entries(db, tour.id)
    approved = sum(1 for e in entries if _estatus(e) == "APPROVED")
    pending = sum(1 for e in entries if _estatus(e) == "PENDING")
    my_status = None
    if user_id:
        for e in entries:
            if e.user_id == user_id:
                my_status = _estatus(e)
                break
    return ChessTournamentOut(
        id=tour.id,
        name=tour.name,
        description=tour.description,
        status=tour.status,
        registration_deadline=tour.registration_deadline,
        entry_count=approved,
        pending_count=pending,
        current_round=tour.current_round or 0,
        is_registered=my_status is not None,
        my_status=my_status,
        champion=_ref(db, tour.champion_id),
        created_at=tour.created_at,
    )


def _get_tour(db, tour_id, tenant_id) -> ChessTournament:
    tour = (
        db.query(ChessTournament)
        .filter(ChessTournament.id == tour_id, ChessTournament.organization_id == tenant_id)
        .first()
    )
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
    return tour


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
        current_round=0,
        created_by_user_id=current_user.id,
    )
    db.add(tour)
    db.commit()
    db.refresh(tour)

    # A tournament opening for registration IS club news — put it on the
    # notice board automatically instead of relying on a separate admin post.
    from app.services.auto_announce import auto_announce
    from app.models.announcement import AnnouncementCategory
    auto_announce(
        db,
        org_id=tenant_id,
        category=AnnouncementCategory.EVENT,
        title_ta=f"♟️ {name} — பதிவு தொடங்கியது",
        title_en=f"♟️ {name} — registration open",
        body_ta=f"{name} சதுரங்கப் போட்டிக்கான பதிவு இப்போது திறந்துள்ளது. Play → Chess → Tournaments-இல் பதிவு செய்யுங்கள்.",
        body_en=f"Registration for the {name} chess tournament is now open. Register in Play → Chess → Tournaments.",
        expires_at=payload.registration_deadline,
        created_by_user_id=current_user.id,
    )
    return _serialize(db, tour, current_user.id)


@router.post("/{tour_id}/register", response_model=ChessTournamentOut)
def register(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    tour = _get_tour(db, tour_id, tenant_id)
    if tour.status != "REGISTRATION_OPEN":
        raise HTTPException(status_code=400, detail="Registration is closed")
    # SQLite drops tzinfo on DateTime(timezone=True) columns, so the deadline
    # comes back naive; normalise to UTC before comparing to an aware now() or
    # Python raises "can't compare offset-naive and offset-aware datetimes".
    deadline = tour.registration_deadline
    if deadline is not None:
        if deadline.tzinfo is None:
            deadline = deadline.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > deadline:
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
                status="PENDING",
            )
        )
        db.commit()
        # Let the organizer know a registration is awaiting approval.
        _notify(
            db, tenant_id, tour.created_by_user_id,
            "New chess registration", "புதிய செஸ் பதிவு",
            f"{_name(current_user)} registered for {tour.name}. Approve to let them play.",
            f"{_name(current_user)} {tour.name} போட்டியில் பதிவு செய்தார்.",
            {"route": f"/chess/tournaments/{tour_id}"},
        )
    return _serialize(db, tour, current_user.id)


@router.post("/{tour_id}/registrations/{user_id}/decision", response_model=ChessTournamentDetailOut)
def decide_registration(
    tour_id: uuid.UUID,
    user_id: uuid.UUID,
    payload: RegistrationDecisionIn,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Manager approves or rejects a pending registration. Only allowed before the
    tournament starts (bracket is drawn from approved players)."""
    tour = _get_tour(db, tour_id, tenant_id)
    if tour.status not in ("REGISTRATION_OPEN", "REGISTRATION_CLOSED"):
        raise HTTPException(status_code=400, detail="Registrations are locked — tournament has started")
    entry = (
        db.query(ChessTournamentEntry)
        .filter(
            ChessTournamentEntry.tournament_id == tour_id,
            ChessTournamentEntry.user_id == user_id,
        )
        .first()
    )
    if not entry:
        raise HTTPException(status_code=404, detail="Registration not found")
    entry.status = "APPROVED" if payload.approve else "REJECTED"
    db.commit()
    if payload.approve:
        _notify(
            db, tenant_id, user_id,
            "You're in! ♟️", "நீங்கள் தேர்ந்தெடுக்கப்பட்டீர்கள்! ♟️",
            f"Your registration for {tour.name} was approved.",
            f"{tour.name} போட்டியில் உங்கள் பதிவு அங்கீகரிக்கப்பட்டது.",
            {"route": f"/chess/tournaments/{tour_id}"},
        )
    else:
        _notify(
            db, tenant_id, user_id,
            "Registration update", "பதிவு புதுப்பிப்பு",
            f"Your registration for {tour.name} was not accepted this time.",
            f"{tour.name} போட்டியில் உங்கள் பதிவு ஏற்கப்படவில்லை.",
            {"route": f"/chess/tournaments/{tour_id}"},
        )
    return _detail(db, tour, current_user.id)


@router.post("/{tour_id}/close", response_model=ChessTournamentDetailOut)
def close_registration(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Manager manually closes registration (independent of any deadline). No new
    players can register; the manager then draws the bracket via /start."""
    tour = _get_tour(db, tour_id, tenant_id)
    if tour.status != "REGISTRATION_OPEN":
        raise HTTPException(status_code=400, detail="Registration is not open")
    tour.status = "REGISTRATION_CLOSED"
    db.commit()
    return _detail(db, tour, current_user.id)


@router.post("/{tour_id}/reopen", response_model=ChessTournamentDetailOut)
def reopen_registration(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Reopen a prematurely-closed registration (before the bracket is drawn)."""
    tour = _get_tour(db, tour_id, tenant_id)
    if tour.status != "REGISTRATION_CLOSED":
        raise HTTPException(status_code=400, detail="Registration is not closed")
    tour.status = "REGISTRATION_OPEN"
    db.commit()
    return _detail(db, tour, current_user.id)


@router.post("/{tour_id}/start", response_model=ChessTournamentDetailOut)
def start_tournament(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Lock the approved list, draw the single-elimination bracket, activate
    round 1 and notify every player. Registration must be closed first."""
    tour = _get_tour(db, tour_id, tenant_id)
    # Registration may be open or already closed — closing first is recommended
    # but not required. Once IN_PROGRESS/COMPLETED it cannot be started again.
    if tour.status not in ("REGISTRATION_OPEN", "REGISTRATION_CLOSED"):
        raise HTTPException(status_code=400, detail="Tournament already started")

    entries = _entries(db, tour_id)
    players = [e.user_id for e in entries if _estatus(e) == "APPROVED"]
    if len(players) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 approved players")

    # Optimistic lock: ensure we are the only ones starting it
    updated = db.query(ChessTournament).filter(
        ChessTournament.id == tour_id,
        ChessTournament.status.in_(["REGISTRATION_OPEN", "REGISTRATION_CLOSED"])
    ).update({"status": "STARTING_LOCK"}, synchronize_session=False)
    
    if updated == 0:
        db.rollback()
        raise HTTPException(status_code=400, detail="Tournament already starting or started")

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
                activated=False,
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
        m.activated = True  # round 1 goes live when the tournament starts
        if a and b:
            m.status = "READY"
        elif a and not b:
            m.status = "BYE"  # auto-advance below
        else:
            m.status = "PENDING"

    tour.status = "IN_PROGRESS"
    tour.current_round = 1
    db.flush()

    # Auto-advance byes into round 2 (slot filled, round 2 not yet activated).
    for s in range(size // 2):
        m = matches[(1, s)]
        if m.status == "BYE" and m.player_a_id:
            _advance(db, tour, m, m.player_a_id)

    db.commit()

    # Notify every approved player the tournament has begun.
    for pid in players:
        _notify(
            db, tenant_id, pid,
            "♟️ Tournament started!", "♟️ போட்டி தொடங்கியது!",
            f"{tour.name} has begun. Open the app to see your match.",
            f"{tour.name} தொடங்கியது. உங்கள் ஆட்டத்தைப் பார்க்க ஆப்பைத் திறக்கவும்.",
            {"route": f"/chess/tournaments/{tour_id}"},
        )
    return _detail(db, tour, current_user.id)


@router.post("/{tour_id}/next-round", response_model=ChessTournamentDetailOut)
def start_next_round(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Manager activates the next round once the current one is fully decided."""
    tour = _get_tour(db, tour_id, tenant_id)
    if tour.status != "IN_PROGRESS":
        raise HTTPException(status_code=400, detail="Tournament is not in progress")
    # Pick up any Arena games that just finished before validating.
    _auto_resolve(db, tour)

    all_matches = (
        db.query(ChessTournamentMatch)
        .filter(ChessTournamentMatch.tournament_id == tour_id)
        .all()
    )
    total_rounds = max((m.round for m in all_matches), default=0)
    cur = tour.current_round or 0
    nxt = cur + 1
    if nxt > total_rounds:
        raise HTTPException(status_code=400, detail="No further rounds")

    # Every match in the current round must be decided first.
    undecided = [
        m for m in all_matches
        if m.round == cur and m.winner_id is None and m.status != "BYE"
    ]
    if undecided:
        raise HTTPException(status_code=400, detail="Finish the current round first")

    activated_players = []
    for m in all_matches:
        if m.round != nxt:
            continue
        m.activated = True
        if m.player_a_id and m.player_b_id and m.winner_id is None:
            m.status = "READY"
            activated_players += [m.player_a_id, m.player_b_id]
    tour.current_round = nxt
    db.commit()

    for pid in set(activated_players):
        _notify(
            db, tenant_id, pid,
            "Your next match is ready ♟️", "உங்கள் அடுத்த ஆட்டம் தயார் ♟️",
            f"Round {nxt} of {tour.name} has started. Mark ready and play.",
            f"{tour.name} போட்டியின் சுற்று {nxt} தொடங்கியது.",
            {"route": f"/chess/tournaments/{tour_id}"},
        )
    return _detail(db, tour, current_user.id)


@router.get("/{tour_id}", response_model=ChessTournamentDetailOut)
def get_tournament(
    tour_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    tour = _get_tour(db, tour_id, tenant_id)
    _auto_resolve(db, tour)  # pick up finished Arena games
    return _detail(db, tour, current_user.id if current_user else None)


@router.post("/{tour_id}/matches/{match_id}/ready", response_model=ChessTournamentDetailOut)
def mark_ready(
    tour_id: uuid.UUID,
    match_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """A player marks themselves ready for their (activated) online match. Both
    players must be ready before the board opens."""
    tour = _get_tour(db, tour_id, tenant_id)
    m = (
        db.query(ChessTournamentMatch)
        .filter(
            ChessTournamentMatch.id == match_id,
            ChessTournamentMatch.tournament_id == tour_id,
        )
        .first()
    )
    if not m:
        raise HTTPException(status_code=404, detail="Match not found")
    if current_user.id not in (m.player_a_id, m.player_b_id):
        raise HTTPException(status_code=403, detail="You are not in this match")
    if not _bool(m.activated):
        raise HTTPException(status_code=400, detail="This round has not started yet")
    if m.winner_id:
        raise HTTPException(status_code=400, detail="Match already decided")
    if current_user.id == m.player_a_id:
        m.a_ready = True
    else:
        m.b_ready = True
    db.commit()
    return _detail(db, tour, current_user.id)


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
    if not _bool(m.activated):
        raise HTTPException(status_code=400, detail="This round has not started yet")
    if (m.conduct_mode or "APP") == "PHYSICAL":
        raise HTTPException(
            status_code=400,
            detail="This match is played in person; the organizer records the result",
        )
    if current_user.id not in (m.player_a_id, m.player_b_id):
        raise HTTPException(status_code=403, detail="You are not in this match")
    # Playing implies you are ready; require the opponent to be ready too.
    if current_user.id == m.player_a_id:
        m.a_ready = True
    else:
        m.b_ready = True
    if not (_bool(m.a_ready) and _bool(m.b_ready)):
        db.commit()
        raise HTTPException(status_code=409, detail="Waiting for your opponent to be ready")

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
        db.flush()
        
        # Optimistic concurrency: ensure no other thread just created the game
        updated = db.query(ChessTournamentMatch).filter(
            ChessTournamentMatch.id == match_id,
            ChessTournamentMatch.game_id.is_(None)
        ).update({"game_id": game.id, "status": "LIVE"})
        
        if updated == 0:
            db.rollback()
            m = db.query(ChessTournamentMatch).filter(ChessTournamentMatch.id == match_id).first()
        else:
            m.game_id = game.id

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
    tour = _get_tour(db, tour_id, tenant_id)
    m = (
        db.query(ChessTournamentMatch)
        .filter(ChessTournamentMatch.id == match_id, ChessTournamentMatch.tournament_id == tour_id)
        .first()
    )
    if not m:
        raise HTTPException(status_code=404, detail="Match not found")
    if m.winner_id:
        raise HTTPException(status_code=400, detail="Match already decided")
    if payload.winner_id not in (m.player_a_id, m.player_b_id):
        raise HTTPException(status_code=400, detail="Winner must be one of the two players")
    _advance(db, tour, m, payload.winner_id)
    db.commit()
    return _detail(db, tour, current_user.id)


@router.post("/{tour_id}/matches/{match_id}/conduct", response_model=ChessTournamentDetailOut)
def set_conduct_mode(
    tour_id: uuid.UUID,
    match_id: uuid.UUID,
    payload: ConductModeIn,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(require_exec),
):
    """Organizer chooses how a match is conducted — APP (online Arena game) or
    PHYSICAL (played in person, organizer records the result). For a physical
    match the organizer can attach a venue + reporting time, and both players
    are notified. Used mainly for semi-final / final matches."""
    mode = (payload.mode or "").strip().upper()
    if mode not in ("APP", "PHYSICAL"):
        raise HTTPException(status_code=400, detail="mode must be APP or PHYSICAL")
    tour = _get_tour(db, tour_id, tenant_id)
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
    m.conduct_mode = mode
    if mode == "PHYSICAL":
        m.venue = (payload.venue or "").strip() or None
        m.reporting_time = payload.reporting_time
    else:
        m.venue = None
        m.reporting_time = None
    db.commit()

    if mode == "PHYSICAL":
        when = ""
        if m.venue:
            when = f" at {m.venue}"
        for pid in (m.player_a_id, m.player_b_id):
            _notify(
                db, tenant_id, pid,
                "Match moved in-person", "ஆட்டம் நேரில் நடத்தப்படும்",
                f"Your {tour.name} match will be played in person{when}.",
                f"{tour.name} போட்டியில் உங்கள் ஆட்டம் நேரில் நடத்தப்படும்{when}.",
                {"route": f"/chess/tournaments/{tour_id}"},
            )
    return _detail(db, tour, current_user.id)


def _detail(db: Session, tour: ChessTournament, user_id) -> ChessTournamentDetailOut:
    base = _serialize(db, tour, user_id)
    entries = _entries(db, tour.id)
    entry_out = []
    for e in entries:
        ref = _ref(db, e.user_id)
        if ref:
            entry_out.append(EntryOut(id=ref.id, name=ref.name, status=_estatus(e)))
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
            conduct_mode=m.conduct_mode or "APP",
            activated=_bool(m.activated),
            a_ready=_bool(m.a_ready),
            b_ready=_bool(m.b_ready),
            venue=m.venue,
            reporting_time=m.reporting_time,
        )
        for m in matches
    ]
    return ChessTournamentDetailOut(
        **base.model_dump(),
        entries=entry_out,
        rounds=rounds,
        matches=match_out,
    )
