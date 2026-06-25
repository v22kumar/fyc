import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.models.user import User
from app.models.sports import Fixture, Team
from app.models.cricket import CricketMatch, CricketPlayer, CricketBall
from app.dependencies import get_current_user, RoleChecker

require_exec = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

router = APIRouter(tags=["Cricket Scoring"])

# ── Schemas ──────────────────────────────────────────────────────────

class CricketInitRequest(BaseModel):
    toss_winner_id: str
    toss_decision: str  # "BAT" or "BOWL"
    overs: int = 20
    striker_name: str
    non_striker_name: str
    bowler_name: str

class CricketBallRequest(BaseModel):
    striker_id: str
    non_striker_id: str
    bowler_id: str
    runs_batter: int = 0
    extras_type: Optional[str] = "NONE"
    extras_runs: int = 0
    is_wicket: bool = False
    wicket_type: Optional[str] = None
    player_dismissed_id: Optional[str] = None
    new_batter_name: Optional[str] = None
    new_bowler_name: Optional[str] = None

# ── Helpers ──────────────────────────────────────────────────────────

def _get_or_create_player(db: Session, team_id: str, name: str) -> CricketPlayer:
    if not name:
        return None
    player = db.query(CricketPlayer).filter(CricketPlayer.team_id == team_id, CricketPlayer.name == name).first()
    if not player:
        player = CricketPlayer(id=uuid.uuid4(), team_id=team_id, name=name)
        db.add(player)
        db.commit()
    return player

def recalculate_match_state(db: Session, match: CricketMatch):
    balls = db.query(CricketBall).filter(CricketBall.match_id == match.id).order_by(CricketBall.ball_index).all()
    
    # Base state
    state = {
        "innings": 1,
        "batting_team_id": None,
        "bowling_team_id": None,
        "score": 0,
        "wickets": 0,
        "overs": 0,
        "balls": 0,
        "target": None,
        "batters": {}, # {id: {name, runs, balls, 4s, 6s, out}}
        "bowlers": {}, # {id: {name, overs, balls, runs, wickets, maidens}}
        "extras": {"w": 0, "nb": 0, "b": 0, "lb": 0}
    }
    
    if match.toss_decision == "BAT":
        state["batting_team_id"] = str(match.toss_winner_id)
        state["bowling_team_id"] = str(match.fixture.team_a_id if str(match.fixture.team_b_id) == str(match.toss_winner_id) else match.fixture.team_b_id)
    else:
        state["bowling_team_id"] = str(match.toss_winner_id)
        state["batting_team_id"] = str(match.fixture.team_a_id if str(match.fixture.team_b_id) == str(match.toss_winner_id) else match.fixture.team_b_id)

    current_innings = 1
    
    def ensure_batter(pid, name):
        if str(pid) not in state["batters"]:
            state["batters"][str(pid)] = {"name": name, "runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": False}
    
    def ensure_bowler(pid, name):
        if str(pid) not in state["bowlers"]:
            state["bowlers"][str(pid)] = {"name": name, "legal_balls": 0, "runs": 0, "wickets": 0}

    for b in balls:
        if b.innings_number > current_innings:
            current_innings = b.innings_number
            state["innings"] = current_innings
            state["target"] = state["score"] + 1
            state["score"] = 0
            state["wickets"] = 0
            state["overs"] = 0
            state["balls"] = 0
            state["batting_team_id"], state["bowling_team_id"] = state["bowling_team_id"], state["batting_team_id"]
            state["extras"] = {"w": 0, "nb": 0, "b": 0, "lb": 0}

        ensure_batter(b.striker_id, b.striker.name)
        ensure_batter(b.non_striker_id, b.non_striker.name)
        ensure_bowler(b.bowler_id, b.bowler.name)

        is_legal = b.extras_type not in ["WIDE", "NO_BALL"]
        
        ball_runs = b.runs_batter
        bowler_runs = b.runs_batter
        
        if b.extras_type == "WIDE":
            ball_runs += 1 + b.extras_runs
            bowler_runs += 1 + b.extras_runs
            state["extras"]["w"] += 1 + b.extras_runs
        elif b.extras_type == "NO_BALL":
            ball_runs += 1 + b.extras_runs
            bowler_runs += 1 + b.runs_batter
            state["extras"]["nb"] += 1 + b.extras_runs
        elif b.extras_type == "BYE":
            ball_runs = b.extras_runs
            bowler_runs = 0
            state["extras"]["b"] += b.extras_runs
        elif b.extras_type == "LEG_BYE":
            ball_runs = b.extras_runs
            bowler_runs = 0
            state["extras"]["lb"] += b.extras_runs

        state["score"] += ball_runs
        
        if b.extras_type not in ["WIDE"]:
            state["batters"][str(b.striker_id)]["balls"] += 1
            
        state["batters"][str(b.striker_id)]["runs"] += b.runs_batter
        if b.runs_batter == 4: state["batters"][str(b.striker_id)]["fours"] += 1
        if b.runs_batter == 6: state["batters"][str(b.striker_id)]["sixes"] += 1

        state["bowlers"][str(b.bowler_id)]["runs"] += bowler_runs
        if is_legal:
            state["balls"] += 1
            state["bowlers"][str(b.bowler_id)]["legal_balls"] += 1
            if state["balls"] == 6:
                state["overs"] += 1
                state["balls"] = 0

        if b.is_wicket:
            state["wickets"] += 1
            state["batters"][str(b.player_dismissed_id)]["out"] = True
            if b.wicket_type in ["BOWLED", "CAUGHT", "LBW", "STUMPED", "HIT_WICKET"]:
                state["bowlers"][str(b.bowler_id)]["wickets"] += 1

    match.match_state = state
    
    if state["wickets"] >= 10 or (state["overs"] == match.overs_per_innings and state["balls"] == 0):
        if state["innings"] == 1:
            match.status = "INNINGS_BREAK"
        else:
            match.status = "COMPLETED"
            if state["score"] > state["target"]:
                match.fixture.winner_id = match.fixture.team_b_id if str(match.fixture.team_a_id) == state["batting_team_id"] else match.fixture.team_a_id
            elif state["score"] == state["target"] - 1:
                match.fixture.winner_id = None
            else:
                match.fixture.winner_id = match.fixture.team_a_id if str(match.fixture.team_a_id) == state["bowling_team_id"] else match.fixture.team_b_id
            
            match.fixture.status = "COMPLETED"
            match.fixture.team_a_score = "Completed"
            match.fixture.team_b_score = "Completed"

    db.commit()
    return state

# ── Endpoints ────────────────────────────────────────────────────────

@router.post("/fixtures/{fixture_id}/cricket/init")
def init_cricket_match(
    fixture_id: str,
    payload: CricketInitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    fixture = db.query(Fixture).filter(Fixture.id == fixture_id).first()
    if not fixture:
        raise HTTPException(404, "Fixture not found")
        
    match = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
    if match:
        return match

    match = CricketMatch(
        id=uuid.uuid4(),
        fixture_id=fixture_id,
        toss_winner_id=payload.toss_winner_id,
        toss_decision=payload.toss_decision,
        overs_per_innings=payload.overs,
        scorer_id=current_user.id,
        status="FIRST_INNINGS"
    )
    db.add(match)
    db.commit()
    
    fixture.status = "LIVE"
    db.commit()

    batting_team_id = payload.toss_winner_id if payload.toss_decision == "BAT" else (str(fixture.team_a_id) if str(fixture.team_b_id) == payload.toss_winner_id else str(fixture.team_b_id))
    bowling_team_id = payload.toss_winner_id if payload.toss_decision == "BOWL" else (str(fixture.team_a_id) if str(fixture.team_b_id) == payload.toss_winner_id else str(fixture.team_b_id))
    
    striker = _get_or_create_player(db, batting_team_id, payload.striker_name)
    non_striker = _get_or_create_player(db, batting_team_id, payload.non_striker_name)
    bowler = _get_or_create_player(db, bowling_team_id, payload.bowler_name)
    
    recalculate_match_state(db, match)
    
    return {
        "match": match, 
        "current_players": {
            "striker_id": str(striker.id),
            "non_striker_id": str(non_striker.id),
            "bowler_id": str(bowler.id),
            "striker_name": striker.name,
            "non_striker_name": non_striker.name,
            "bowler_name": bowler.name
        }
    }


@router.get("/fixtures/{fixture_id}/cricket")
def get_cricket_match(
    fixture_id: str,
    db: Session = Depends(get_db)
):
    match = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
    if not match:
        raise HTTPException(404, "Cricket match not initialized")
    return match


@router.post("/fixtures/{fixture_id}/cricket/ball")
def score_ball(
    fixture_id: str,
    payload: CricketBallRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
    if not match:
        raise HTTPException(404, "Match not initialized")
        
    if match.scorer_id and str(match.scorer_id) != str(current_user.id) and current_user.role != "SUPER_ADMIN":
        raise HTTPException(403, "Only the assigned scorer can update this match")

    state = match.match_state or {}
    innings_num = state.get("innings", 1)
    
    batting_team_id = state.get("batting_team_id")
    bowling_team_id = state.get("bowling_team_id")
    
    striker_id = payload.striker_id
    if payload.new_batter_name and payload.player_dismissed_id == payload.striker_id:
        p = _get_or_create_player(db, batting_team_id, payload.new_batter_name)
        striker_id = str(p.id)
        
    non_striker_id = payload.non_striker_id
    if payload.new_batter_name and payload.player_dismissed_id == payload.non_striker_id:
        p = _get_or_create_player(db, batting_team_id, payload.new_batter_name)
        non_striker_id = str(p.id)
        
    bowler_id = payload.bowler_id
    if payload.new_bowler_name:
        p = _get_or_create_player(db, bowling_team_id, payload.new_bowler_name)
        bowler_id = str(p.id)

    ball_index = db.query(CricketBall).filter(CricketBall.match_id == match.id).count() + 1

    ball = CricketBall(
        id=uuid.uuid4(),
        match_id=match.id,
        innings_number=innings_num,
        ball_index=ball_index,
        striker_id=striker_id,
        non_striker_id=non_striker_id,
        bowler_id=bowler_id,
        runs_batter=payload.runs_batter,
        extras_type=payload.extras_type,
        extras_runs=payload.extras_runs,
        is_wicket=payload.is_wicket,
        wicket_type=payload.wicket_type,
        player_dismissed_id=payload.player_dismissed_id,
        scorer_id=current_user.id
    )
    db.add(ball)
    db.commit()
    
    new_state = recalculate_match_state(db, match)
    return {"status": "success", "match_state": new_state}


@router.post("/fixtures/{fixture_id}/cricket/undo")
def undo_last_ball(
    fixture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
    if not match:
        raise HTTPException(404, "Match not initialized")
        
    if match.scorer_id and str(match.scorer_id) != str(current_user.id) and current_user.role != "SUPER_ADMIN":
        raise HTTPException(403, "Only the assigned scorer can update this match")

    last_ball = db.query(CricketBall).filter(CricketBall.match_id == match.id).order_by(CricketBall.ball_index.desc()).first()
    if not last_ball:
        raise HTTPException(400, "No balls to undo")
        
    db.delete(last_ball)
    db.commit()
    
    new_state = recalculate_match_state(db, match)
    return {"status": "success", "match_state": new_state}

@router.post("/fixtures/{fixture_id}/cricket/second-innings")
def start_second_innings(
    fixture_id: str,
    payload: CricketInitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
    if match.status != "INNINGS_BREAK":
        raise HTTPException(400, "Match is not in innings break")
        
    match.status = "SECOND_INNINGS"
    db.commit()
    
    state = match.match_state
    batting_team = state["bowling_team_id"]
    bowling_team = state["batting_team_id"]
    
    s = _get_or_create_player(db, batting_team, payload.striker_name)
    ns = _get_or_create_player(db, batting_team, payload.non_striker_name)
    b = _get_or_create_player(db, bowling_team, payload.bowler_name)
    
    state["innings"] = 2
    state["target"] = state["score"] + 1
    state["score"] = 0
    state["wickets"] = 0
    state["overs"] = 0
    state["balls"] = 0
    state["batting_team_id"] = batting_team
    state["bowling_team_id"] = bowling_team
    state["extras"] = {"w": 0, "nb": 0, "b": 0, "lb": 0}
    
    match.match_state = state
    db.commit()
    
    return {
        "status": "success",
        "match_state": state,
        "current_players": {
            "striker_id": str(s.id),
            "non_striker_id": str(ns.id),
            "bowler_id": str(b.id),
            "striker_name": s.name,
            "non_striker_name": ns.name,
            "bowler_name": b.name
        }
    }
