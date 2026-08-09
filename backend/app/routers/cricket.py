import asyncio
import json
import logging
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload
from pydantic import BaseModel

logger = logging.getLogger(__name__)

from app.core.database import get_db, SessionLocal
from app.models.user import User
from app.models.sports import Fixture, Team, Tournament
from app.models.cricket import CricketMatch, CricketBall
from app.models.sports import Player
from app.dependencies import get_current_user, RoleChecker
# The engine — ball/over/innings rules, standings, score formatting — lives in
# the service; the router keeps HTTP: auth, tenancy, request shapes, codes.
from app.services.cricket_engine import (
    _apply_cricket_standings,
    _cricket_result_notes,
    _get_or_create_player,
    _write_cricket_scores,
    recalculate_match_state,
)

require_exec = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

router = APIRouter(tags=["Cricket Scoring"])

# ── Schemas ──────────────────────────────────────────────────────────

class CricketInitRequest(BaseModel):
    toss_winner_id: str
    toss_decision: str  # "BAT" or "BOWL"
    overs: int = 20
    village_wides: bool = False  # first two wides per over carry no penalty run
    striker_name: str
    non_striker_name: str
    bowler_name: str

class CricketBallEditRequest(BaseModel):
    runs_batter: Optional[int] = None
    extras_type: Optional[str] = None
    extras_runs: Optional[int] = None
    is_wicket: Optional[bool] = None
    wicket_type: Optional[str] = None
    player_dismissed_id: Optional[str] = None
    striker_id: Optional[str] = None
    non_striker_id: Optional[str] = None
    bowler_id: Optional[str] = None
    notes: Optional[str] = None

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
    # Client-generated idempotency key so an offline-queued ball that is retried
    # (or arrives twice) is recorded exactly once.
    client_ball_id: Optional[str] = None

# ── Helpers ──────────────────────────────────────────────────────────

def _tenant_match(db: Session, fixture_id: str, user: User) -> Optional[CricketMatch]:
    """The org gate for every scoring mutation.

    require_exec proves the caller is an exec of *their* organization — not
    that this fixture belongs to it. Joining through the fixture's
    organization_id closes that gap; a cross-org fixture id looks exactly
    like an unknown one."""
    return (
        db.query(CricketMatch)
        .join(Fixture, Fixture.id == CricketMatch.fixture_id)
        .filter(
            CricketMatch.fixture_id == fixture_id,
            Fixture.organization_id == user.organization_id,
        )
        .first()
    )


def _reject_if_same_name(a: Optional[str], b: Optional[str]) -> None:
    """Two people at the crease (or two openers) must be distinct players.
    Names are matched case-insensitively/trimmed because that's how
    _get_or_create_player resolves identity — if two different physical
    players are given the same name on the same team, the lookup silently
    collapses them into one Player row and their stats merge (each shows the
    other's runs/balls). Reject the request instead of corrupting the match."""
    if a is None or b is None:
        return
    if a.strip().lower() == b.strip().lower():
        raise HTTPException(
            status_code=400,
            detail="Striker and non-striker must be different players — "
                   "they can't share the same name.",
        )


# ── Endpoints ────────────────────────────────────────────────────────

@router.post("/fixtures/{fixture_id}/cricket/init")
def init_cricket_match(
    fixture_id: str,
    payload: CricketInitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    fixture = db.query(Fixture).filter(
        Fixture.id == fixture_id,
        Fixture.organization_id == current_user.organization_id,
    ).first()
    if not fixture:
        raise HTTPException(404, "Fixture not found")

    match = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
    if match:
        # Already initialized — keep the response shape consistent with a fresh
        # init so the client has a single contract to parse.
        return {"match": match, "current_players": None}

    _reject_if_same_name(payload.striker_name, payload.non_striker_name)

    # Village-wides is pinned at the tournament level: if the tournament has the
    # rule on, every match uses it (a per-match toggle can also enable it).
    tournament = db.query(Tournament).filter(Tournament.id == fixture.tournament_id).first()
    village_wides = bool(payload.village_wides) or bool(getattr(tournament, "village_wides", False))

    match = CricketMatch(
        id=uuid.uuid4(),
        fixture_id=fixture_id,
        toss_winner_id=payload.toss_winner_id,
        toss_decision=payload.toss_decision,
        overs_per_innings=payload.overs,
        village_wides=village_wides,
        scorer_id=current_user.id,
        status="FIRST_INNINGS",
        organization_id=current_user.organization_id,
    )
    db.add(match)
    db.commit()
    
    fixture.status = "LIVE"
    db.commit()

    batting_team_id = payload.toss_winner_id if payload.toss_decision == "BAT" else (str(fixture.team_a_id) if str(fixture.team_b_id) == payload.toss_winner_id else str(fixture.team_b_id))
    bowling_team_id = payload.toss_winner_id if payload.toss_decision == "BOWL" else (str(fixture.team_a_id) if str(fixture.team_b_id) == payload.toss_winner_id else str(fixture.team_b_id))
    
    striker = _get_or_create_player(db, batting_team_id, payload.striker_name, org_id=current_user.organization_id)
    non_striker = _get_or_create_player(db, batting_team_id, payload.non_striker_name, org_id=current_user.organization_id)
    bowler = _get_or_create_player(db, bowling_team_id, payload.bowler_name, org_id=current_user.organization_id)
    
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


def _cricket_live_snapshot(fixture_id: str):
    """The public live payload for a fixture (status + scoreboard state), read in
    a short-lived session so a long-running stream never holds a DB connection.
    Returns None when the match isn't initialised yet — or on any DB error, so a
    transient blip skips a tick instead of tearing down every viewer's stream.

    Cache-aside with a 1s TTL: every viewer's stream polls this every second,
    so 200 spectators of one match meant 200 identical queries and pool
    checkouts per second. The cache collapses that to one DB pass per tick,
    shared by everyone. Bypassed under tests so a just-scored ball is never
    hidden behind a cached response."""
    from app.core import livecache
    from app.core.config import settings

    cache_key = f"cricket:sse:{fixture_id}"
    if not settings.TESTING:
        cached = livecache.get_json(cache_key)
        if cached is not None:
            return cached

    db = SessionLocal()
    try:
        m = db.query(CricketMatch).filter(CricketMatch.fixture_id == fixture_id).first()
        if not m:
            return None
        snap = {
            "status": m.status,
            "overs_per_innings": m.overs_per_innings,
            "match_state": m.match_state,
        }
        if not settings.TESTING:
            livecache.set_json(cache_key, snap, ttl_seconds=1)
        return snap
    except Exception:
        logger.debug("cricket live snapshot read failed for %s", fixture_id, exc_info=True)
        return None
    finally:
        db.close()


@router.get("/fixtures/{fixture_id}/cricket/stream")
async def stream_cricket_match(fixture_id: str, request: Request):
    """Server-Sent Events stream of a live cricket match.

    Viewers open one long-lived connection instead of re-polling every few
    seconds, so a new ball reaches every phone/browser within ~1s over a single
    connection — no repeated India↔Singapore TLS handshakes. The server reads
    the shared DB (so it works across Fly instances without extra infra) and
    emits only when the scoreboard actually changes; clients keep their existing
    poll as a fallback if the stream can't be established. No auth/tenant header
    is required — EventSource can't send custom headers and this is public data,
    exactly like the GET endpoint above.
    """
    async def event_gen():
        # Tell EventSource to reconnect ~3s after any drop.
        yield "retry: 3000\n\n"
        last_sig = None
        ticks_since_emit = 0
        while True:
            if await request.is_disconnected():
                break
            try:
                snap = await run_in_threadpool(_cricket_live_snapshot, fixture_id)
            except Exception:
                # A transient DB hiccup must not tear down every viewer's stream —
                # skip this tick, keep the connection alive, try again next second.
                snap = None
            if snap is not None:
                sig = json.dumps(snap, sort_keys=True, default=str)
                if sig != last_sig:
                    last_sig = sig
                    ticks_since_emit = 0
                    yield f"data: {json.dumps(snap, default=str)}\n\n"
                    await asyncio.sleep(1.0)
                    continue
            # Heartbeat roughly every 15s of no change so proxies keep the pipe open.
            ticks_since_emit += 1
            if ticks_since_emit % 15 == 0:
                yield ": ping\n\n"
            await asyncio.sleep(1.0)

    return StreamingResponse(
        event_gen(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # don't let nginx buffer the stream
        },
    )


@router.post("/fixtures/{fixture_id}/cricket/ball")
def score_ball(
    fixture_id: str,
    payload: CricketBallRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = _tenant_match(db, fixture_id, current_user)
    if not match:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match not initialized"})
        
    if match.scorer_id and str(match.scorer_id) != str(current_user.id) and current_user.role != "SUPER_ADMIN":
        raise HTTPException(403, "Only the assigned scorer can update this match")

    # A COMPLETED match stays editable: adding/correcting a delivery re-runs
    # recalculate_match_state, which reopens the match and reverses standings if
    # the edit changes the outcome. Only a fixture that never started (SCHEDULED)
    # is blocked here.
    if match.fixture.status not in ["LIVE", "IN_PROGRESS", "COMPLETED"]:
        return JSONResponse(status_code=400, content={"code": "MATCH_NOT_LIVE", "message": "Match is not in LIVE state."})

    state = match.match_state or {}
    innings_num = state.get("innings")
    if not innings_num:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match setup incomplete: innings not initialized."})
    
    batting_team_id = state.get("batting_team_id")
    bowling_team_id = state.get("bowling_team_id")
    if not batting_team_id or not bowling_team_id:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match setup incomplete: batting and bowling teams must be assigned."})
    
    batting_team = db.query(Team).filter(Team.id == batting_team_id).first()
    bowling_team = db.query(Team).filter(Team.id == bowling_team_id).first()
    if not batting_team or not bowling_team:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match setup incomplete: Batting or bowling team does not exist."})

    # A wicket requires a genuine replacement batter (unless the innings ends
    # with this dismissal). Without this, the dismissed player's id silently
    # carries over to the next ball — the batting order gets corrupted and the
    # resume screen is later left with no valid non-striker to pick from.
    if payload.is_wicket:
        current_wickets = state.get("wickets", 0)
        # A wicket on the innings' final legal ball ends play immediately (the
        # over limit closes the innings just like a 10th wicket) — mirror
        # recalculate_match_state's own innings_over predicate so that case
        # doesn't wrongly demand a replacement batter who'll never bat.
        is_legal_ball = payload.extras_type not in ("WIDE", "NO_BALL")
        overs_after, balls_after = state.get("overs", 0), state.get("balls", 0)
        if is_legal_ball:
            balls_after += 1
            if balls_after == 6:
                overs_after += 1
                balls_after = 0
        over_limit_reached = overs_after == match.overs_per_innings and balls_after == 0 and overs_after > 0
        innings_continues = (current_wickets + 1) < 10 and not over_limit_reached
        new_batter_name = (payload.new_batter_name or "").strip()
        if innings_continues and not new_batter_name:
            raise HTTPException(
                status_code=400,
                detail="A new batter name is required to continue this innings.",
            )
        if new_batter_name:
            surviving_id = (
                payload.non_striker_id
                if payload.player_dismissed_id == payload.striker_id
                else payload.striker_id
            )
            surviving = db.query(Player).filter(Player.id == surviving_id).first()
            if surviving:
                _reject_if_same_name(new_batter_name, surviving.name)

    striker_id = payload.striker_id
    if payload.new_batter_name and payload.player_dismissed_id == payload.striker_id:
        p = _get_or_create_player(db, batting_team_id, payload.new_batter_name, org_id=current_user.organization_id)
        striker_id = str(p.id)
        
    non_striker_id = payload.non_striker_id
    if payload.new_batter_name and payload.player_dismissed_id == payload.non_striker_id:
        p = _get_or_create_player(db, batting_team_id, payload.new_batter_name, org_id=current_user.organization_id)
        non_striker_id = str(p.id)
        
    bowler_id = payload.bowler_id
    if payload.new_bowler_name:
        p = _get_or_create_player(db, bowling_team_id, payload.new_bowler_name, org_id=current_user.organization_id)
        bowler_id = str(p.id)

    if not striker_id or not non_striker_id:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match setup incomplete: opening batters must be selected."})
    if not bowler_id:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match setup incomplete: current bowler must be selected."})

    striker = db.query(Player).filter(Player.id == striker_id).first()
    non_striker = db.query(Player).filter(Player.id == non_striker_id).first()
    bowler = db.query(Player).filter(Player.id == bowler_id).first()

    if not striker or not non_striker or not bowler:
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Match setup incomplete: One or more players do not exist."})

    if str(striker.team_id) != str(batting_team_id) or str(non_striker.team_id) != str(batting_team_id):
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Batters do not belong to the batting team."})
    
    if str(bowler.team_id) != str(bowling_team_id):
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Bowler does not belong to the bowling team."})

    if str(striker.organization_id) != str(current_user.organization_id) or str(bowler.organization_id) != str(current_user.organization_id):
        return JSONResponse(status_code=400, content={"code": "MATCH_SETUP_INCOMPLETE", "message": "Players do not belong to your organization."})

    # Idempotent replay: if this exact ball was already recorded (an offline
    # queue retry or a duplicate re-sync), don't insert it again — return the
    # current scoreboard. This is what makes the offline queue safe.
    if payload.client_ball_id:
        dup = db.query(CricketBall).filter(
            CricketBall.match_id == match.id,
            CricketBall.client_ball_id == payload.client_ball_id,
        ).first()
        if dup:
            return {"status": "success", "match_state": match.match_state or recalculate_match_state(db, match)}

    # MAX(ball_index)+1, not COUNT(*)+1 — cheaper (indexed) and stable if a ball
    # was ever deleted.
    max_idx = db.query(func.max(CricketBall.ball_index)).filter(CricketBall.match_id == match.id).scalar() or 0
    ball_index = max_idx + 1

    ball = CricketBall(
        id=uuid.uuid4(),
        match_id=match.id,
        innings_number=innings_num,
        ball_index=ball_index,
        client_ball_id=payload.client_ball_id,
        striker_id=striker_id,
        non_striker_id=non_striker_id,
        bowler_id=bowler_id,
        runs_batter=payload.runs_batter,
        extras_type=payload.extras_type,
        extras_runs=payload.extras_runs,
        is_wicket=payload.is_wicket,
        wicket_type=payload.wicket_type,
        player_dismissed_id=payload.player_dismissed_id,
        scorer_id=current_user.id,
        organization_id=current_user.organization_id,
    )
    try:
        db.add(ball)
        db.flush()
        new_state = recalculate_match_state(db, match)
        db.commit()
    except IntegrityError:
        # A concurrent request with the same client_ball_id lost the race to the
        # unique index — treat as an idempotent success, not an error.
        db.rollback()
        return {"status": "success", "match_state": recalculate_match_state(db, match)}
    except Exception as e:
        db.rollback()
        logger.exception(f"cricket score_ball failed. Match ID: {match.id}, payload: {payload.model_dump()}")
        return JSONResponse(status_code=400, content={"code": "BALL_SCORING_FAILED", "message": f"Unable to record this ball. Reason: {str(e)}"})
    return {"status": "success", "match_state": new_state}


@router.post("/fixtures/{fixture_id}/cricket/undo")
def undo_last_ball(
    fixture_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = _tenant_match(db, fixture_id, current_user)
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
    match = _tenant_match(db, fixture_id, current_user)
    if not match:
        raise HTTPException(404, "Match not initialized")
    if match.status != "INNINGS_BREAK":
        raise HTTPException(400, "Match is not in innings break")

    _reject_if_same_name(payload.striker_name, payload.non_striker_name)

    match.status = "SECOND_INNINGS"
    db.commit()

    state = dict(match.match_state or {})
    batting_team = state["bowling_team_id"]
    bowling_team = state["batting_team_id"]
    
    s = _get_or_create_player(db, batting_team, payload.striker_name, org_id=current_user.organization_id)
    ns = _get_or_create_player(db, batting_team, payload.non_striker_name, org_id=current_user.organization_id)
    b = _get_or_create_player(db, bowling_team, payload.bowler_name, org_id=current_user.organization_id)
    
    state["innings"] = 2
    state["target"] = state["score"] + 1
    state["score"] = 0
    state["wickets"] = 0
    state["overs"] = 0
    state["balls"] = 0
    state["batting_team_id"] = batting_team
    state["bowling_team_id"] = bowling_team
    state["extras"] = {"w": 0, "nb": 0, "b": 0, "lb": 0}
    state["recent_balls"] = []
    state["status"] = "SECOND_INNINGS"

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

from datetime import datetime

@router.put("/fixtures/{fixture_id}/cricket/ball/{ball_id}")
def edit_cricket_ball(
    fixture_id: str,
    ball_id: str,
    payload: CricketBallEditRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = _tenant_match(db, fixture_id, current_user)
    if not match:
        raise HTTPException(404, "Match not initialized")
    
    if match.scorer_id and str(match.scorer_id) != str(current_user.id) and current_user.role != "SUPER_ADMIN":
        raise HTTPException(403, "Only the assigned scorer can update this match")

    ball = db.query(CricketBall).filter(CricketBall.id == ball_id, CricketBall.match_id == match.id).first()
    if not ball:
        raise HTTPException(404, "Ball not found")

    old_state = {
        "runs_batter": ball.runs_batter,
        "extras_type": ball.extras_type,
        "extras_runs": ball.extras_runs,
        "is_wicket": ball.is_wicket,
        "wicket_type": ball.wicket_type,
        "player_dismissed_id": str(ball.player_dismissed_id) if ball.player_dismissed_id else None,
        "striker_id": str(ball.striker_id),
        "non_striker_id": str(ball.non_striker_id),
        "bowler_id": str(ball.bowler_id),
        "notes": ball.notes
    }

    if payload.runs_batter is not None: ball.runs_batter = payload.runs_batter
    if payload.extras_type is not None: ball.extras_type = payload.extras_type
    if payload.extras_runs is not None: ball.extras_runs = payload.extras_runs
    if payload.is_wicket is not None: ball.is_wicket = payload.is_wicket
    if payload.wicket_type is not None: ball.wicket_type = payload.wicket_type
    if payload.player_dismissed_id is not None: ball.player_dismissed_id = payload.player_dismissed_id
    if payload.striker_id is not None: ball.striker_id = payload.striker_id
    if payload.non_striker_id is not None: ball.non_striker_id = payload.non_striker_id
    if payload.bowler_id is not None: ball.bowler_id = payload.bowler_id
    if payload.notes is not None: ball.notes = payload.notes

    new_state = {
        "runs_batter": ball.runs_batter,
        "extras_type": ball.extras_type,
        "extras_runs": ball.extras_runs,
        "is_wicket": ball.is_wicket,
        "wicket_type": ball.wicket_type,
        "player_dismissed_id": str(ball.player_dismissed_id) if ball.player_dismissed_id else None,
        "striker_id": str(ball.striker_id),
        "non_striker_id": str(ball.non_striker_id),
        "bowler_id": str(ball.bowler_id),
        "notes": ball.notes
    }

    history = ball.edit_history or []
    history.append({
        "timestamp": datetime.utcnow().isoformat(),
        "editor_id": str(current_user.id),
        "editor_name": current_user.profile.full_name_en if current_user.profile else None,
        "old": old_state,
        "new": new_state,
        "notes": payload.notes
    })
    ball.edit_history = history

    db.commit()
    
    new_match_state = recalculate_match_state(db, match)
    return {"status": "success", "match_state": new_match_state}

@router.post("/fixtures/{fixture_id}/cricket/ball/{ball_id}/undo-edit")
def undo_ball_edit(
    fixture_id: str,
    ball_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_exec)
):
    match = _tenant_match(db, fixture_id, current_user)
    if not match:
        raise HTTPException(404, "Match not initialized")
    
    if match.scorer_id and str(match.scorer_id) != str(current_user.id) and current_user.role != "SUPER_ADMIN":
        raise HTTPException(403, "Only the assigned scorer can update this match")

    ball = db.query(CricketBall).filter(CricketBall.id == ball_id, CricketBall.match_id == match.id).first()
    if not ball:
        raise HTTPException(404, "Ball not found")

    history = ball.edit_history or []
    if not history:
        raise HTTPException(400, "No edit history to undo for this ball.")

    last_edit = history.pop()
    old_state = last_edit["old"]

    ball.runs_batter = old_state.get("runs_batter", ball.runs_batter)
    ball.extras_type = old_state.get("extras_type", ball.extras_type)
    ball.extras_runs = old_state.get("extras_runs", ball.extras_runs)
    ball.is_wicket = old_state.get("is_wicket", ball.is_wicket)
    ball.wicket_type = old_state.get("wicket_type", ball.wicket_type)
    ball.player_dismissed_id = old_state.get("player_dismissed_id", ball.player_dismissed_id)
    ball.striker_id = old_state.get("striker_id", ball.striker_id)
    ball.non_striker_id = old_state.get("non_striker_id", ball.non_striker_id)
    ball.bowler_id = old_state.get("bowler_id", ball.bowler_id)
    ball.notes = old_state.get("notes", ball.notes)

    # We append a new record about the undo
    history.append({
        "timestamp": datetime.utcnow().isoformat(),
        "editor_id": str(current_user.id),
        "editor_name": current_user.profile.full_name_en if current_user.profile else None,
        "old": last_edit["new"],
        "new": old_state,
        "notes": "Undo last edit"
    })
    
    ball.edit_history = history
    db.commit()
    
    new_match_state = recalculate_match_state(db, match)
    return {"status": "success", "match_state": new_match_state}
