from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.sports import Tournament, Team, Fixture, ChallengeMatch
from app.models.user import User
from app.schemas.sports import (
    TournamentCreate, TournamentOut,
    TeamCreate, TeamOut,
    FixtureCreate, FixtureResultUpdate, FixtureOut,
    ChallengeCreate, ChallengeOut, ChallengeStatusUpdate,
)
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/sports", tags=["Sports Hub"])

require_exec = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


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
    if payload.team_a_score is not None:
        f.team_a_score = payload.team_a_score
    if payload.team_b_score is not None:
        f.team_b_score = payload.team_b_score
    if payload.result_notes is not None:
        f.result_notes = payload.result_notes
    if payload.winner_id is not None:
        f.winner_id = payload.winner_id
        winner_team = db.query(Team).filter(Team.id == str(payload.winner_id)).first()
        loser_id = f.team_b_id if str(payload.winner_id) == str(f.team_a_id) else f.team_a_id
        loser_team = db.query(Team).filter(Team.id == str(loser_id)).first()
        if winner_team:
            winner_team.wins += 1
            winner_team.points += 3
        if loser_team:
            loser_team.losses += 1
    f.status = "COMPLETED"
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
