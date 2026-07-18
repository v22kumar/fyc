from typing import List, Optional
from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.etag import etag_not_modified, set_etag
from app.models.sports import Tournament, Team, Fixture, ChallengeMatch, LiveScoreEntry, Player
from app.models.user import User
from app.schemas.sports import (
    TournamentCreate, TournamentOut,
    TeamCreate, TeamOut, TeamStatusUpdate, TeamUpdate,
    PlayerCreate, PlayerOut,
    FixtureCreate, FixtureResultUpdate, FixtureOut, FixtureUpdate,
    ChallengeCreate, ChallengeOut, ChallengeStatusUpdate,
    LiveScoreEntryCreate, LiveScoreReview, LiveScoreEntryOut,
    TournamentQuickComplete,
)
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id
from app.services.nrr import compute_nrr
from app.services.notification_service import NotificationService
from app.schemas.notification import NotificationCategory
from app.services.whatsapp_service import whatsapp_queue

router = APIRouter(prefix="/sports", tags=["Sports Hub"])

require_exec = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])
# Club members (and above) may submit live scores for admin approval
require_member = RoleChecker(["CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


def _registration_closed(t) -> bool:
    """Registration is closed once an admin closed it early, or the due date
    (registration_close_date) has passed."""
    if t.registration_closed_at is not None:
        return True
    close = t.registration_close_date
    if close is None:
        return False
    if close.tzinfo is None:  # SQLite hands back naive datetimes
        close = close.replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc) >= close


def _tournament_phase(db: Session, t) -> str:
    """Single source of truth for a tournament's lifecycle phase, derived so the
    stored status can't contradict reality (e.g. UPCOMING with a live match):
      REGISTRATION_OPEN → REGISTRATION_CLOSED → ONGOING → COMPLETED.
    """
    if str(t.status or "").upper() in ("COMPLETED", "ARCHIVED"):
        return "COMPLETED"
    fixtures = db.query(Fixture).filter(Fixture.tournament_id == t.id).all()
    if fixtures:
        if all(f.status == "COMPLETED" for f in fixtures):
            return "COMPLETED"
        return "ONGOING"
    return "REGISTRATION_CLOSED" if _registration_closed(t) else "REGISTRATION_OPEN"


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
    
    t = db.query(Tournament).filter(Tournament.id == f.tournament_id).first()
    if t:
        NotificationService.broadcast_to_tenant(
            db=db,
            tenant_id=t.organization_id,
            category=NotificationCategory.SPORTS,
            title_en=f"Match Result: {t.name_en}",
            title_ta=f"போட்டி முடிவு: {t.name_ta}",
            body_en=f"{f.team_a.name} vs {f.team_b.name} has concluded.",
            body_ta=f"{f.team_a.name} vs {f.team_b.name} போட்டி முடிவடைந்தது.",
            route=f"/sports/{t.id}/fixtures/{f.id}"
        )


def _standings_with_nrr(db: Session, t: Tournament):
    """Teams for a tournament with net_run_rate attached, ranked by points then
    NRR then wins. Shared by the /teams and /standings endpoints so both carry
    NRR (the mobile standings screen uses /standings)."""
    teams = db.query(Team).filter(Team.tournament_id == t.id).all()
    fixtures = db.query(Fixture).filter(Fixture.tournament_id == t.id).all()
    nrr = compute_nrr(fixtures, t.match_config)
    for tm in teams:
        tm.net_run_rate = nrr.get(tm.id)
    teams.sort(
        key=lambda tm: (
            tm.points or 0,
            tm.net_run_rate if tm.net_run_rate is not None else -999,
            tm.wins or 0,
        ),
        reverse=True,
    )
    return teams


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
    request: Request,
    response: Response,
    sport: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    q = db.query(Tournament).filter(Tournament.organization_id == tenant_id, Tournament.format != "WEEKLY_GAME")
    if sport:
        q = q.filter(Tournament.sport == sport.lower())
    if status:
        q = q.filter(Tournament.status == status.upper())
    tournaments = q.order_by(Tournament.year.desc()).all()
    for t in tournaments:
        t.phase = _tournament_phase(db, t)
    result = [TournamentOut.model_validate(t) for t in tournaments]

    cached = etag_not_modified(request, result)
    if cached is not None:
        return cached
    set_etag(response, result)
    return result


require_member_or_exec = RoleChecker(["CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

@router.post("/tournaments", response_model=TournamentOut, status_code=201)
def create_tournament(
    payload: TournamentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member_or_exec),
):
    # Members create DRAFT tournaments. Admins create UPCOMING (official) tournaments.
    is_admin = current_user.role in ["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"]
    status = "UPCOMING" if is_admin else "DRAFT"
    
    t = Tournament(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        created_by_id=current_user.id,
        status=status,
        **payload.model_dump(),
    )
    db.add(t)
    db.commit()
    db.refresh(t)

    # Official tournaments go straight onto the notice board; member DRAFTs
    # stay silent until an admin publishes them.
    if status == "UPCOMING":
        from app.services.auto_announce import auto_announce
        from app.models.announcement import AnnouncementCategory
        sport = (payload.sport or "").title()
        auto_announce(
            db,
            org_id=current_user.organization_id,
            category=AnnouncementCategory.EVENT,
            title_ta=f"🏆 {payload.name_ta} — பதிவு தொடங்கியது",
            title_en=f"🏆 {payload.name_en} — registration open",
            body_ta=f"{payload.name_ta} ({sport}) போட்டிக்கான பதிவு தொடங்கிவிட்டது. Play → Sports Hub-இல் அணியை பதிவு செய்யுங்கள்.",
            body_en=f"Registration for {payload.name_en} ({sport}) has opened. Register your team in Play → Sports Hub.",
            expires_at=payload.registration_close_date,
            created_by_user_id=current_user.id,
        )
    t.phase = _tournament_phase(db, t)
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
    t.phase = _tournament_phase(db, t)
    return t


@router.post("/tournaments/{tournament_id}/close-registration", response_model=TournamentOut)
def close_registration(
    tournament_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """Manually close registration early (admin). After this, no new teams can
    register and fixtures can be generated. Registration also closes on its own
    once registration_close_date passes."""
    t = _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    if t.registration_closed_at is None:
        t.registration_closed_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(t)
    t.phase = _tournament_phase(db, t)
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
    if new_status.upper() not in ["DRAFT", "UPCOMING", "ONGOING", "COMPLETED", "ARCHIVED", "PUBLISHED"]:
        raise HTTPException(400, "Invalid status")
    t.status = new_status.upper()
    db.commit()
    
    if t.status == "PUBLISHED":
        NotificationService.broadcast_to_tenant(
            db=db,
            tenant_id=t.organization_id,
            category=NotificationCategory.SPORTS,
            title_en=f"New Tournament: {t.name_en}",
            title_ta=f"புதிய போட்டி: {t.name_ta}",
            body_en=f"Registration is now open for {t.name_en} ({t.sport}).",
            body_ta=f"{t.name_ta} ({t.sport}) பதிவு துவங்கியுள்ளது.",
            route=f"/sports/{t.id}"
        )
        
    return {"status": t.status}

@router.put("/tournaments/{tournament_id}", response_model=TournamentOut)
def update_tournament(
    tournament_id: str,
    payload: TournamentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    t = db.query(Tournament).filter(
        Tournament.id == tournament_id,
        Tournament.organization_id == current_user.organization_id,
    ).first()
    if not t:
        raise HTTPException(404, "Tournament not found")
    
    for k, v in payload.model_dump().items():
        setattr(t, k, v)
    db.commit()
    db.refresh(t)
    return t

@router.post("/tournaments/{tournament_id}/quick-complete", response_model=TournamentOut)
def quick_complete_tournament(
    tournament_id: str,
    payload: TournamentQuickComplete,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """
    Skip all fixtures and ball-by-ball. Just declare a winner and finish.
    """
    t = db.query(Tournament).filter(
        Tournament.id == tournament_id,
        Tournament.organization_id == current_user.organization_id,
    ).first()
    if not t:
        raise HTTPException(404, "Tournament not found")
        
    winner = db.query(Team).filter(Team.id == str(payload.winner_id), Team.tournament_id == tournament_id).first()
    if not winner:
        raise HTTPException(400, "Winner team not found in this tournament")
        
    if payload.runner_up_id:
        runner_up = db.query(Team).filter(Team.id == str(payload.runner_up_id), Team.tournament_id == tournament_id).first()
        if not runner_up:
            raise HTTPException(400, "Runner up team not found in this tournament")
        t.runner_up_id = payload.runner_up_id
        
    t.winner_id = payload.winner_id
    t.status = "COMPLETED"
    db.commit()
    db.refresh(t)
    return t

@router.delete("/tournaments/{tournament_id}")
def delete_tournament(
    tournament_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    t = db.query(Tournament).filter(
        Tournament.id == tournament_id,
        Tournament.organization_id == current_user.organization_id,
    ).first()
    if not t:
        raise HTTPException(404, "Tournament not found")
    db.delete(t)
    db.commit()
    return {"status": "deleted"}


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
    t = _get_tenant_tournament(db, tournament_id, tenant_id)
    return _standings_with_nrr(db, t)


_LIVE_MATCH_STATUSES = ("FIRST_INNINGS", "INNINGS_BREAK", "SECOND_INNINGS")


@router.get("/live")
def live_scores(
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Public cross-tournament live cricket scores for the Home strip — visible to
    everyone (tenant-scoped, no auth). Returns in-progress matches with their
    current score, plus recent results and upcoming fixtures so the widget always
    has something to show."""
    from app.models.cricket import CricketMatch

    live = []
    live_fixture_ids = set()
    # Eager-load fixture + its teams/tournament: this endpoint is polled every
    # ~20s by every client, so avoid an N+1 per live match.
    matches = (
        db.query(CricketMatch)
        .join(Fixture, CricketMatch.fixture_id == Fixture.id)
        .options(
            joinedload(CricketMatch.fixture).joinedload(Fixture.team_a),
            joinedload(CricketMatch.fixture).joinedload(Fixture.team_b),
            joinedload(CricketMatch.fixture).joinedload(Fixture.tournament),
        )
        .filter(Fixture.organization_id == tenant_id,
                CricketMatch.status.in_(_LIVE_MATCH_STATUSES))
        .all()
    )
    for m in matches:
        f = m.fixture
        if not f:
            continue
        live_fixture_ids.add(f.id)
        st = m.match_state or {}
        team_a = f.team_a.name if f.team_a else "?"
        team_b = f.team_b.name if f.team_b else "?"
        bat_id = str(st.get("batting_team_id") or "")
        batting = team_a if bat_id == str(f.team_a_id) else (team_b if bat_id == str(f.team_b_id) else None)
        score = int(st.get("score", 0) or 0)
        wickets = int(st.get("wickets", 0) or 0)
        overs = int(st.get("overs", 0) or 0)
        balls = int(st.get("balls", 0) or 0)
        target = st.get("target")
        # Structured chase state — the client localizes it (no server-authored
        # English). runs_needed 0 == target reached.
        runs_needed = None
        if m.status == "SECOND_INNINGS" and target:
            runs_needed = max(0, int(target) - score)
        t = f.tournament
        live.append({
            "fixture_id": str(f.id),
            "tournament_id": str(f.tournament_id),
            "tournament_name": t.name_en if t else None,
            "team_a": team_a,
            "team_b": team_b,
            "batting_team": batting,
            "score": score,
            "wickets": wickets,
            "overs": f"{overs}.{balls}",
            "target": int(target) if target else None,
            "summary": f"{score}/{wickets} ({overs}.{balls})",
            "runs_needed": runs_needed,
            "innings_break": m.status == "INNINGS_BREAK",
            "status": m.status,
        })

    # Recently completed — most recent first, excluding anything currently live.
    recent = []
    done_q = (
        db.query(Fixture)
        .options(joinedload(Fixture.team_a), joinedload(Fixture.team_b), joinedload(Fixture.tournament))
        .filter(Fixture.organization_id == tenant_id, Fixture.status == "COMPLETED")
    )
    if live_fixture_ids:
        done_q = done_q.filter(~Fixture.id.in_(live_fixture_ids))
    done = done_q.order_by(Fixture.updated_at.desc()).limit(6).all()
    for f in done:
        recent.append({
            "fixture_id": str(f.id),
            "tournament_id": str(f.tournament_id),
            "tournament_name": f.tournament.name_en if f.tournament else None,
            "team_a": f.team_a.name if f.team_a else "?",
            "team_b": f.team_b.name if f.team_b else "?",
            "team_a_score": f.team_a_score,
            "team_b_score": f.team_b_score,
            "result": f.result_notes,
        })

    # Next scheduled — excluding any fixture already shown as live (a fixture's
    # own status stays SCHEDULED while its cricket match is in progress).
    upcoming = []
    sched_q = (
        db.query(Fixture)
        .options(joinedload(Fixture.team_a), joinedload(Fixture.team_b), joinedload(Fixture.tournament))
        .filter(Fixture.organization_id == tenant_id, Fixture.status == "SCHEDULED")
    )
    if live_fixture_ids:
        sched_q = sched_q.filter(~Fixture.id.in_(live_fixture_ids))
    sched = sched_q.order_by(Fixture.scheduled_at.asc()).limit(6).all()
    for f in sched:
        upcoming.append({
            "fixture_id": str(f.id),
            "tournament_id": str(f.tournament_id),
            "tournament_name": f.tournament.name_en if f.tournament else None,
            "team_a": f.team_a.name if f.team_a else "?",
            "team_b": f.team_b.name if f.team_b else "?",
            "scheduled_at": f.scheduled_at.isoformat() if f.scheduled_at else None,
            "venue": f.venue,
        })

    return {"live": live, "recent": recent, "upcoming": upcoming}


@router.post("/tournaments/{tournament_id}/teams", response_model=TeamOut, status_code=201)
def register_team(
    tournament_id: str,
    payload: TeamCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    t = _get_tenant_tournament(db, tournament_id, current_user.organization_id)

    # Registration must be open — no new teams once it's closed or fixtures exist.
    is_admin = current_user.role in ["ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER"]
    if not is_admin and _tournament_phase(db, t) != "REGISTRATION_OPEN":
        raise HTTPException(400, "Registration is closed for this tournament.")

    # Auto-approve if OPEN, else PENDING
    status = "APPROVED" if t.registration_mode == "OPEN" else "PENDING"
    
    team = Team(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        tournament_id=tournament_id,
        status=status,
        **payload.model_dump(),
    )
    db.add(team)
    db.commit()
    db.refresh(team)
    return team


@router.delete("/tournaments/{tournament_id}/teams/{team_id}", status_code=204)
def delete_team(
    tournament_id: str,
    team_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    team = db.query(Team).filter(
        Team.id == team_id,
        Team.tournament_id == tournament_id
    ).first()
    if not team:
        raise HTTPException(404, "Team not found")
    
    db.delete(team)
    db.commit()
    return None

@router.patch("/tournaments/{tournament_id}/teams/{team_id}/status", response_model=TeamOut)
def update_team_status(
    tournament_id: str,
    team_id: str,
    payload: TeamStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    team = db.query(Team).filter(
        Team.id == team_id,
        Team.tournament_id == tournament_id
    ).first()
    if not team:
        raise HTTPException(404, "Team not found")
    
    if payload.status.upper() not in ["PENDING", "APPROVED", "REJECTED"]:
        raise HTTPException(400, "Invalid status")
        
    team.status = payload.status.upper()
    db.commit()
    db.refresh(team)
    
    if team.status == "APPROVED" and team.contact_phone:
        t = db.query(Tournament).filter(Tournament.id == tournament_id).first()
        whatsapp_queue.enqueue_template(
            phone=team.contact_phone,
            template_name="team_registration_approved",
            parameters={
                "team_name": team.name,
                "tournament_name": t.name_en if t else "Tournament",
            }
        )
        
    return team


@router.patch("/tournaments/{tournament_id}/teams/{team_id}", response_model=TeamOut)
def update_team(
    tournament_id: str,
    team_id: str,
    payload: TeamUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    team = db.query(Team).filter(
        Team.id == team_id,
        Team.tournament_id == tournament_id
    ).first()
    if not team:
        raise HTTPException(404, "Team not found")
        
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(team, field, value)
        
    db.commit()
    db.refresh(team)
    return team


# ── Players ───────────────────────────────────────────────────────────────────

@router.get("/teams/{team_id}/players", response_model=List[PlayerOut])
def list_players(
    team_id: str,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    team = db.query(Team).filter(Team.id == team_id, Team.organization_id == tenant_id).first()
    if not team:
        raise HTTPException(404, "Team not found")
    return db.query(Player).filter(Player.team_id == team_id).all()


@router.post("/teams/{team_id}/players", response_model=PlayerOut, status_code=201)
def register_player(
    team_id: str,
    payload: PlayerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    team = db.query(Team).filter(Team.id == team_id, Team.organization_id == current_user.organization_id).first()
    if not team:
        raise HTTPException(404, "Team not found")
    
    player = Player(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
        team_id=team_id,
        **payload.model_dump(),
    )
    db.add(player)
    db.commit()
    db.refresh(player)
    return player

@router.delete("/players/{player_id}", status_code=204)
def delete_player(
    player_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    player = db.query(Player).filter(Player.id == player_id, Player.organization_id == current_user.organization_id).first()
    if not player:
        raise HTTPException(404, "Player not found")
    db.delete(player)
    db.commit()
    return None

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
    t = _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    # Allow creating fixtures at any time by admin
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


@router.patch("/tournaments/{tournament_id}/fixtures/{fixture_id}", response_model=FixtureOut)
def update_fixture(
    tournament_id: str,
    fixture_id: str,
    payload: FixtureUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """Admin: update a fixture's details, schedule, teams, or status/results."""
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    f = db.query(Fixture).filter(Fixture.id == fixture_id, Fixture.tournament_id == tournament_id).first()
    if not f:
        raise HTTPException(404, "Fixture not found")

    if payload.team_a_id is not None:
        f.team_a_id = payload.team_a_id
    if payload.team_b_id is not None:
        f.team_b_id = payload.team_b_id
    if payload.match_number is not None:
        f.match_number = payload.match_number
    if payload.scheduled_at is not None:
        f.scheduled_at = payload.scheduled_at
    if payload.venue is not None:
        f.venue = payload.venue
    if payload.status is not None:
        f.status = payload.status
    if payload.team_a_score is not None:
        f.team_a_score = payload.team_a_score
    if payload.team_b_score is not None:
        f.team_b_score = payload.team_b_score
    if payload.winner_id is not None:
        f.winner_id = payload.winner_id
    if payload.result_notes is not None:
        f.result_notes = payload.result_notes

    db.commit()
    db.refresh(f)
    return _fixture_out(f)


@router.delete("/tournaments/{tournament_id}/fixtures/{fixture_id}", status_code=204)
def delete_fixture(
    tournament_id: str,
    fixture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """Admin: delete a fixture entirely."""
    _get_tenant_tournament(db, tournament_id, current_user.organization_id)
    f = db.query(Fixture).filter(Fixture.id == fixture_id, Fixture.tournament_id == tournament_id).first()
    if not f:
        raise HTTPException(404, "Fixture not found")
    db.delete(f)
    db.commit()
    return None


@router.get("/tournaments/{tournament_id}/standings", response_model=List[TeamOut])
def get_standings(
    tournament_id: str,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    t = _get_tenant_tournament(db, tournament_id, tenant_id)
    return _standings_with_nrr(db, t)


@router.post("/tournaments/{tournament_id}/generate-fixtures", response_model=List[FixtureOut])
def generate_fixtures(
    tournament_id: str,
    double_round: bool = False,
    force: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec),
):
    """Auto-generate round-robin fixtures from the APPROVED registered teams.
    Set double_round=true for home-and-away. Skips if fixtures already exist.

    Fixtures cannot be generated while registration is still open. Registration
    closes automatically once registration_close_date passes, or immediately when
    an admin closes it early. Passing force=true closes registration now and
    generates in one step."""
    t = _get_tenant_tournament(db, tournament_id, current_user.organization_id)

    # Auto-close registration if open when generating fixtures, without raising errors
    if _tournament_phase(db, t) == "REGISTRATION_OPEN":
        if t.registration_closed_at is None:
            t.registration_closed_at = datetime.now(timezone.utc)
            db.commit()

    teams = db.query(Team).filter(Team.tournament_id == tournament_id, Team.status == "APPROVED").all()
    if len(teams) < 2:
        raise HTTPException(400, "Need at least 2 APPROVED teams to generate fixtures")

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
    # Fixtures are out → the tournament is now ONGOING.
    t.status = "ONGOING"
    db.commit()
    for f in created:
        db.refresh(f)
        
    NotificationService.broadcast_to_tenant(
        db=db,
        tenant_id=current_user.organization_id,
        category=NotificationCategory.SPORTS,
        title_en=f"Fixtures Released: {t.name_en}",
        title_ta=f"போட்டி அட்டவணை: {t.name_ta}",
        body_en=f"The match schedule for {t.name_en} is now available.",
        body_ta=f"{t.name_ta} க்கான போட்டி அட்டவணை வெளியிடப்பட்டுள்ளது.",
        route=f"/sports/{t.id}/fixtures"
    )
        
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
    """Submit a live/final score for a non-cricket fixture.

    Managers (EXECUTIVE_MEMBER and above) are trusted scorers: their entry is
    APPROVED and applied to standings immediately. A plain club member's entry
    stays PENDING until an admin approves it. Either way the running score shows
    on the fixture right away."""
    f = db.query(Fixture).filter(
        Fixture.id == fixture_id,
        Fixture.organization_id == current_user.organization_id,
    ).first()
    if not f:
        raise HTTPException(404, "Fixture not found")

    is_manager = current_user.role in ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")

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
        status="APPROVED" if is_manager else "PENDING",
    )
    db.add(entry)

    if is_manager:
        # Trusted scorer → finalize the result and update standings now.
        _apply_result(db, f, payload.team_a_score, payload.team_b_score,
                      payload.winner_id, payload.notes)
    else:
        # Reflect the running score immediately (unverified) so viewers see motion,
        # but leave the result unapplied until an admin approves.
        if f.status == "SCHEDULED":
            f.status = "LIVE"
        if payload.team_a_score is not None:
            f.team_a_score = payload.team_a_score
        if payload.team_b_score is not None:
            f.team_b_score = payload.team_b_score

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
