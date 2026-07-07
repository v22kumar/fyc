import uuid
from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.weekly_games import WeeklyGame, WeeklyGamePlayer
from app.models.sports import Tournament, Team, Player, Fixture
from app.models.user import User, UserProfile
from app.schemas.weekly_games import WeeklyGameCreate, WeeklyGameOut, WeeklyGamePlayerOut
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/weekly-games", tags=["Weekly Games"])

def _name(user: User) -> str:
    if not user:
        return "Player"
    if hasattr(user, "profile") and user.profile:
        return user.profile.full_name_en or user.profile.full_name_ta or "Player"
    return "Player"

def _serialize(db: Session, game: WeeklyGame) -> WeeklyGameOut:
    players_out = []
    for p in game.players:
        if p.status == "JOINED":
            players_out.append(WeeklyGamePlayerOut(
                id=p.id,
                user_id=p.user_id,
                user_name=_name(p.user),
                status=p.status,
                team_assigned=p.team_assigned
            ))
    return WeeklyGameOut(
        id=game.id,
        title=game.title,
        sport=game.sport,
        scheduled_at=game.scheduled_at,
        venue=game.venue,
        status=game.status,
        created_by_id=game.created_by_id,
        fixture_id=game.fixture_id,
        players=players_out
    )

@router.get("", response_model=List[WeeklyGameOut])
def list_games(
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id)
):
    games = db.query(WeeklyGame).filter(WeeklyGame.organization_id == tenant_id).order_by(WeeklyGame.scheduled_at.desc()).all()
    return [_serialize(db, g) for g in games]

@router.post("", response_model=WeeklyGameOut)
def create_game(
    payload: WeeklyGameCreate,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user)
):
    game = WeeklyGame(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        title=payload.title,
        sport=payload.sport,
        scheduled_at=payload.scheduled_at,
        venue=payload.venue,
        status="UPCOMING",
        created_by_id=current_user.id
    )
    db.add(game)
    db.commit()
    db.refresh(game)
    return _serialize(db, game)

@router.post("/{game_id}/join", response_model=WeeklyGameOut)
def join_game(
    game_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user)
):
    game = db.query(WeeklyGame).filter(WeeklyGame.id == game_id, WeeklyGame.organization_id == tenant_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")
    if game.status != "UPCOMING":
        raise HTTPException(status_code=400, detail="Cannot join a game that has started or finished")
        
    existing = db.query(WeeklyGamePlayer).filter(WeeklyGamePlayer.game_id == game_id, WeeklyGamePlayer.user_id == current_user.id).first()
    if existing:
        existing.status = "JOINED"
    else:
        player = WeeklyGamePlayer(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            game_id=game_id,
            user_id=current_user.id,
            status="JOINED"
        )
        db.add(player)
    db.commit()
    db.refresh(game)
    return _serialize(db, game)

@router.post("/{game_id}/start", response_model=WeeklyGameOut)
def start_game(
    game_id: uuid.UUID,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user)
):
    game = db.query(WeeklyGame).filter(WeeklyGame.id == game_id, WeeklyGame.organization_id == tenant_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")
    if game.status != "UPCOMING":
        raise HTTPException(status_code=400, detail="Game is already started")
    
    joined_players = [p for p in game.players if p.status == "JOINED"]
    
    # 1. Create a dummy Tournament to house the fixture
    t = Tournament(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        name_en=game.title,
        name_ta=game.title,
        sport=game.sport,
        year=datetime.now(timezone.utc).year,
        format="WEEKLY_GAME",
        status="ONGOING",
        created_by_id=current_user.id,
    )
    db.add(t)
    
    # 2. Create two Teams
    team_a = Team(id=uuid.uuid4(), organization_id=tenant_id, tournament_id=t.id, name="Team A")
    team_b = Team(id=uuid.uuid4(), organization_id=tenant_id, tournament_id=t.id, name="Team B")
    db.add(team_a)
    db.add(team_b)
    
    # 3. Randomly assign players to teams
    for i, p in enumerate(joined_players):
        assigned_team = team_a if i % 2 == 0 else team_b
        p.team_assigned = "A" if i % 2 == 0 else "B"
        player_model = Player(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            team_id=assigned_team.id,
            user_id=p.user_id,
            name=_name(p.user)
        )
        db.add(player_model)
    
    # 4. Create the Fixture
    f = Fixture(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        tournament_id=t.id,
        team_a_id=team_a.id,
        team_b_id=team_b.id,
        scheduled_at=game.scheduled_at,
        venue=game.venue,
        status="LIVE"
    )
    db.add(f)
    db.flush()
    
    # 5. Update WeeklyGame
    game.status = "LIVE"
    game.fixture_id = f.id
    db.commit()
    db.refresh(game)
    return _serialize(db, game)
