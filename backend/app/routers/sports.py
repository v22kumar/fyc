from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.sports import Tournament, Team, Fixture, ChallengeMatch, LiveScoreEntry
from app.models.user import User
from app.schemas.sports import (
    TournamentCreate, TournamentOut,
    TeamCreate, TeamOut,
    FixtureCreate, FixtureResultUpdate, FixtureOut,
    ChallengeCreate, ChallengeOut, ChallengeStatusUpdate,
    LiveScoreEntryCreate, LiveScoreReview, LiveScoreEntryOut,
)
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/sports", tags=["Sports Hub"])

require_exec = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])
# Club members (and above) may submit live scores for admin approval
require_member = RoleChecker(["CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


def _apply_result(db: Session, f: Fixture, team_a_score, team_b_score, winner_id, notes):
    """Apply a final result to a fixture and update team standings. Shared by
    direct executive result entry and approved club-member live entries."""
    if team_a_score is not None:
        f.team_a_score = team_a_score
    if team_b_score is not None:
        f.team_b_score = team_b_score
    if notes is not None:
        f.result_notes = notes
    if winner_id is not None:
        f.winner_id = winner_id
        winner_team = db.query(Team).filter(Team.id == str(winner_id)).first()
        loser_id = f.team_b_id if str(winner_id) == str(f.team_a_id) else f.team_a_id
        loser_team = db.query(Team).filter(Team.id == str(loser_id)).first()
        if winner_team:
            winner_team.wins += 1
            winner_team.points += 3
        if loser_team:
            loser_team.losses += 1
    f.status = "COMPLETED"


def _fixture_out(f: Fixture) -> FixtureOut:
    return FixtureOut(
        id=f.id,
        tournament_id=f.tournament_id,
        team_a_id=f.team_a_id,
        team_b_id=f.team_b_id,
        team_a_name=f.team_a.name if f.team_a else None,
        team_b_name=f.team_b.name if f.team_b else None,
        match_number=f.match_number,
        scheduled_at=f.scheduled_at,
        venue=f.venue,
        status=f.status,
        team_a_score=f.team_a_score,
        team_b_score=f.team_b_score,
        winner_id=f.winner_id,
        result_notes=f.result_notes,
    )


# ── Tournaments ───────────────────────────────────────────────────────────────

@router.get("/tournaments", response_model=List[TournamentOut])
def list_tournaments(
    sport: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    q = db.query(Tournament).filter(Tournament.organization_id == tenant_id)
    if sport:
        q = q.filter(Tournament.sport == sport.lower())
    if status:
        q = q.filter(Tournament.status == status.upper())
    return q.order_by(Tournament.year.desc()).all()


@router.post("/tournaments", response_model=TournamentOut, status_code=201)
def create_tournament(
    payload: TournamentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    t = Tournament(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        created_by_id=current_user.id,
        **payload.model_dump(),
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    return t


@router.get("/tournaments/{tournament_id}", response_model=TournamentOut)
def get_tournament(
    tournament_id: str,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    t = db.query(Tournament).filter(
        Tournament.id == tournament_id,
        Tournament.organization_id == tenant_id,
    ).first()
    if not t:
        raise HTTPException(404, "Tournament not found")
    return t


@router.patch("/tournaments/{tournament_id}/status")
def update_tournament_status(
    tournament_id: str,
    new_status: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    t = db.query(Tournament).filter(
        Tournament.id == tournament_id,
        Tournament.organization_id == current_user.organization_id,
    ).first()
    if not t:
        raise HTTPException(404, "Tournament not found")
    if new_status.upper() not in ["UPCOMING", "ONGOING", "COMPLETED"]:
        raise HTTPException(400, "Invalid status")
    t.status = new_status.upper()
    db.commit()
    return {"status": t.status}


# ── Teams ─────────────────────────────────────────────────────────────────────

def _get_tenant_tournament(db: Session, tournament_id: str, tenant_id: uuid.UUID) -> Tournament:
    """Fetch a tournament, raising 404 if it doesn't exist or belongs to a different tenant."""
    t = db.query(Tournament).filter(
        Tournament.id == tournament_id,
        Tournament.organization_id == tenant_id,
    ).first()
    if not t:
        raise HTTPException(404, "Tournament not found")
    return t


@router.get("/tournaments/{tournament_id}/teams", response_model=List[TeamOut])
def list_teams(
    tournament_id: str,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    _get_tenant_tournament(db, tournament_id, tenant_id)
    return db.query(Team).filter(Team.tournament_id == tournament_id).order_by(Team.points.desc(), Team.wins.desc()).all()


@router.post("/tournaments/{tournament_id}/teams", response_model=TeamOut, status_code=201)
def register_team(
    tournament_id: str,
    payload: TeamCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    team = Team(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        tournament_id=tournament_id,
        **payload.model_dump(),
    )
    db.add(team)
    db.commit()
    db.refresh(team)
    return team


# ── Fixtures ──────────────────────────────────────────────────────────────────

@router.get("/tournaments/{tournament_id}/fixtures", response_model=List[FixtureOut])
def list_fixtures(
    tournament_id: str,
    fixture_status: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    _get_tenant_tournament(db, tournament_id, tenant_id)
    q = db.query(Fixture).filter(Fixture.tournament_id == tournament_id)
    if fixture_status:
        q = q.filter(Fixture.status == fixture_status.upper())
    fixtures = q.order_by(Fixture.match_number).all()
    return [_fixture_out(f) for f in fixtures]


@router.post("/tournaments/{tournament_id}/fixtures", response_model=FixtureOut, status_code=201)
def create_fixture(
    tournament_id: str,
    payload: FixtureCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    for team_id in [payload.team_a_id, payload.team_b_id]:
        if not db.query(Team).filter(Team.id == str(team_id), Team.tournament_id == tournament_id).first():
            raise HTTPException(400, f"Team {team_id} not found in this tournament")
    f = Fixture(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        tournament_id=tournament_id,
        **payload.model_dump(),
    )
    db.add(f)
    db.commit()
    db.refresh(f)
    return _fixture_out(f)


@router.post("/tournaments/{tournament_id}/fixtures/{fixture_id}/result", response_model=FixtureOut)
def submit_result(
    tournament_id: str,
    fixture_id: str,
    payload: FixtureResultUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    f = db.query(Fixture).filter(Fixture.id == fixture_id, Fixture.tournament_id == tournament_id).first()
    if not f:
        raise HTTPException(404, "Fixture not found")
    _apply_result(db, f, payload.team_a_score, payload.team_b_score, payload.winner_id, payload.result_notes)
    db.commit()
    db.refresh(f)
    return _fixture_out(f)


@router.get("/tournaments/{tournament_id}/standings", response_model=List[TeamOut])
def get_standings(
    tournament_id: str,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    _get_tenant_tournament(db, tournament_id, tenant_id)
    return db.query(Team).filter(Team.tournament_id == tournament_id).order_by(
        Team.points.desc(), Team.wins.desc(), Team.draws.desc()
    ).all()


@router.post("/tournaments/{tournament_id}/generate-fixtures", response_model=List[FixtureOut])
def generate_fixtures(
    tournament_id: str,
    double_round: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """Auto-generate round-robin fixtures from the registered teams.
    Set double_round=true for home-and-away. Skips if fixtures already exist."""
    t = _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    teams = db.query(Team).filter(Team.tournament_id == tournament_id).all()
    if len(teams) < 2:
        raise HTTPException(400, "Need at least 2 registered teams to generate fixtures")

    existing = db.query(Fixture).filter(Fixture.tournament_id == tournament_id).count()
    if existing > 0:
        raise HTTPException(400, "Fixtures already exist for this tournament")

    match_no = 1
    created: List[Fixture] = []
    rounds = 2 if double_round else 1
    for r in range(rounds):
        for i in range(len(teams)):
            for j in range(i + 1, len(teams)):
                a, b = (teams[i], teams[j]) if r == 0 else (teams[j], teams[i])
                f = Fixture(
                    id=uuid.uuid4(),
                    organization_id=current_user.organization_id,
                    tournament_id=tournament_id,
                    team_a_id=a.id,
                    team_b_id=b.id,
                    match_number=match_no,
                    venue=t.venue,
                    status="SCHEDULED",
                )
                db.add(f)
                created.append(f)
                match_no += 1
    db.commit()
    for f in created:
        db.refresh(f)
    return [_fixture_out(f) for f in created]


# ── Live Score Entry (club-member submission → admin approval) ─────────────────

def _live_entry_out(e: LiveScoreEntry, db: Session) -> LiveScoreEntryOut:
    f = e.fixture
    submitter_name = None
    if e.submitted_by and e.submitted_by.profile:
        submitter_name = (e.submitted_by.profile.full_name_en
                          or e.submitted_by.profile.full_name_ta)
    return LiveScoreEntryOut(
        id=e.id,
        fixture_id=e.fixture_id,
        tournament_id=e.tournament_id,
        submitted_by_id=e.submitted_by_id,
        submitted_by_name=submitter_name,
        team_a_name=f.team_a.name if f and f.team_a else None,
        team_b_name=f.team_b.name if f and f.team_b else None,
        team_a_score=e.team_a_score,
        team_b_score=e.team_b_score,
        winner_id=e.winner_id,
        notes=e.notes,
        status=e.status,
        review_notes=e.review_notes,
        created_at=e.created_at,
    )


@router.post("/fixtures/{fixture_id}/live-entry", response_model=LiveScoreEntryOut, status_code=201)
def submit_live_entry(
    fixture_id: str,
    payload: LiveScoreEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member),
):
    """A club member submits a live/final score. Stays PENDING until an
    executive/admin approves it. Marks the fixture LIVE while pending."""
    f = db.query(Fixture).filter(
        Fixture.id == fixture_id,
        Fixture.organization_id == current_user.organization_id,
    ).first()
    if not f:
        raise HTTPException(404, "Fixture not found")

    entry = LiveScoreEntry(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        fixture_id=f.id,
        tournament_id=f.tournament_id,
        submitted_by_id=current_user.id,
        team_a_score=payload.team_a_score,
        team_b_score=payload.team_b_score,
        winner_id=payload.winner_id,
        notes=payload.notes,
        status="PENDING",
    )
    # Reflect live scores on the fixture immediately (unverified) so viewers see motion
    if f.status == "SCHEDULED":
        f.status = "LIVE"
    if payload.team_a_score is not None:
        f.team_a_score = payload.team_a_score
    if payload.team_b_score is not None:
        f.team_b_score = payload.team_b_score
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return _live_entry_out(entry, db)


@router.get("/live-entries", response_model=List[LiveScoreEntryOut])
def list_live_entries(
    entry_status: Optional[str] = None,
    tournament_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """List live-score entries for review. Defaults to all; filter by status."""
    q = db.query(LiveScoreEntry).filter(
        LiveScoreEntry.organization_id == current_user.organization_id
    )
    if entry_status:
        q = q.filter(LiveScoreEntry.status == entry_status.upper())
    if tournament_id:
        q = q.filter(LiveScoreEntry.tournament_id == tournament_id)
    entries = q.order_by(LiveScoreEntry.created_at.desc()).all()
    return [_live_entry_out(e, db) for e in entries]


@router.patch("/live-entries/{entry_id}", response_model=LiveScoreEntryOut)
def review_live_entry(
    entry_id: str,
    payload: LiveScoreReview,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """Approve or reject a club-member live-score entry. On APPROVED the
    scores are committed to the fixture and team standings are updated."""
    e = db.query(LiveScoreEntry).filter(
        LiveScoreEntry.id == entry_id,
        LiveScoreEntry.organization_id == current_user.organization_id,
    ).first()
    if not e:
        raise HTTPException(404, "Live entry not found")
    if e.status != "PENDING":
        raise HTTPException(400, f"Entry already {e.status}")

    new_status = payload.status.upper()
    if new_status not in ["APPROVED", "REJECTED"]:
        raise HTTPException(400, "status must be APPROVED or REJECTED")

    e.status = new_status
    e.reviewed_by_id = current_user.id
    e.review_notes = payload.review_notes

    if new_status == "APPROVED":
        f = db.query(Fixture).filter(Fixture.id == e.fixture_id).first()
        if f:
            if f.status == "COMPLETED":
                # Fixture already finalised (a prior entry was approved): update the
                # displayed score but do NOT re-apply standings to avoid double counting.
                if e.team_a_score is not None:
                    f.team_a_score = e.team_a_score
                if e.team_b_score is not None:
                    f.team_b_score = e.team_b_score
            else:
                _apply_result(db, f, e.team_a_score, e.team_b_score, e.winner_id, e.notes)

    db.commit()
    db.refresh(e)
    return _live_entry_out(e, db)


# ── Challenge Matches ─────────────────────────────────────────────────────────

@router.get("/challenges", response_model=List[ChallengeOut])
def list_challenges(
    challenge_status: Optional[str] = None,
    sport: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    q = db.query(ChallengeMatch).filter(ChallengeMatch.organization_id == tenant_id)
    if challenge_status:
        q = q.filter(ChallengeMatch.status == challenge_status.upper())
    if sport:
        q = q.filter(ChallengeMatch.sport == sport.lower())
    return q.order_by(ChallengeMatch.created_at.desc()).all()


@router.post("/challenges", response_model=ChallengeOut, status_code=201)
def submit_challenge(
    payload: ChallengeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Submit a challenge match. Requires authentication (was previously fully open)."""
    c = ChallengeMatch(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        **payload.model_dump(),
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


@router.patch("/challenges/{challenge_id}", response_model=ChallengeOut)
def respond_to_challenge(
    challenge_id: str,
    payload: ChallengeStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    c = db.query(ChallengeMatch).filter(
        ChallengeMatch.id == challenge_id,
        ChallengeMatch.organization_id == current_user.organization_id,
    ).first()
    if not c:
        raise HTTPException(404, "Challenge not found")
    if payload.status.upper() not in ["ACCEPTED", "REJECTED", "COMPLETED", "OPEN"]:
        raise HTTPException(400, "Invalid status")
    c.status = payload.status.upper()
    if payload.admin_response:
        c.admin_response = payload.admin_response
    db.commit()
    db.refresh(c)
    return c
