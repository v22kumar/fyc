import uuid
import logging
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.chess import ChessGame, ChessMove, ChessPlayerStats, ChessChallenge
from app.models.user import User, UserProfile
from app.schemas.chess import (
    ChessGameCreate, ChessGamePatch,
    ChessGameOut, ChessGameDetailOut,
    ChessPlayerStatsOut, ChessMemberOut,
    ChallengeCreate, ChallengeOut, ChallengeAcceptOut,
    LiveGameOut, PlayerProfileOut,
)
from app.services.chess_ws_manager import ws_manager
from app.services.glicko2 import update as glicko2_update, PlayerRating, prestige_title, title_emoji

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chess", tags=["Chess"])


# ── Helpers ────────────────────────────────────────────────────────────────────

def _display_name(db: Session, user: Optional[User]) -> Optional[str]:
    if user is None:
        return None
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    if profile:
        return profile.full_name_en or profile.full_name_ta
    return None


def _game_out(db: Session, g: ChessGame) -> ChessGameOut:
    return ChessGameOut(
        id=g.id,
        mode=g.mode,
        status=g.status,
        time_control=g.time_control,
        white_id=g.white_id,
        black_id=g.black_id,
        white_name=_display_name(db, g.white),
        black_name=_display_name(db, g.black),
        result=g.result,
        draw_reason=g.draw_reason,
        pgn=g.pgn,
        final_fen=g.final_fen,
        total_moves=g.total_moves,
        white_rating_before=g.white_rating_before,
        black_rating_before=g.black_rating_before,
        white_rating_after=g.white_rating_after,
        black_rating_after=g.black_rating_after,
        started_at=g.started_at,
        ended_at=g.ended_at,
        created_at=g.created_at,
    )


def _get_or_create_stats(db, user_id, org_id) -> ChessPlayerStats:
    stats = db.query(ChessPlayerStats).filter(
        ChessPlayerStats.user_id == user_id
    ).first()
    if not stats:
        stats = ChessPlayerStats(user_id=user_id, organization_id=org_id)
        db.add(stats)
        db.flush()
    return stats


def _update_stats(db, game: ChessGame, org_id) -> None:
    if game.result is None or game.mode == "vs_ai":
        return

    white_s = _get_or_create_stats(db, game.white_id, org_id) if game.white_id else None
    black_s = _get_or_create_stats(db, game.black_id, org_id) if game.black_id else None

    # Record pre-game ratings
    if white_s:
        game.white_rating_before = white_s.glicko_rating
    if black_s:
        game.black_rating_before = black_s.glicko_rating

    # Glicko-2 update (skip untimed casual games for rating purposes)
    if game.time_control != "untimed" and white_s and black_s:
        white_pr = PlayerRating(white_s.glicko_rating, white_s.glicko_rd, white_s.glicko_vol)
        black_pr = PlayerRating(black_s.glicko_rating, black_s.glicko_rd, black_s.glicko_vol)
        if game.result == "white_wins":
            w_score, b_score = 1.0, 0.0
        elif game.result == "black_wins":
            w_score, b_score = 0.0, 1.0
        else:
            w_score, b_score = 0.5, 0.5
        wr, wrd, wvol = glicko2_update(white_pr, black_pr, w_score)
        br, brd, bvol = glicko2_update(black_pr, white_pr, b_score)
        white_s.glicko_rating, white_s.glicko_rd, white_s.glicko_vol = wr, wrd, wvol
        black_s.glicko_rating, black_s.glicko_rd, black_s.glicko_vol = br, brd, bvol
        game.white_rating_after = wr
        game.black_rating_after = br

    # Update win/loss/draw counters and streaks
    pairs = []
    if white_s:
        pairs.append((white_s, game.result == "white_wins", game.result == "draw"))
    if black_s:
        pairs.append((black_s, game.result == "black_wins", game.result == "draw"))
    for s, won, drew in pairs:
        s.games_played += 1
        if won:
            s.wins += 1
            s.current_streak = max(s.current_streak, 0) + 1
            s.longest_win_streak = max(s.longest_win_streak, s.current_streak)
        elif drew:
            s.draws += 1
            s.current_streak = 0
        else:
            s.losses += 1
            s.current_streak = min(s.current_streak, 0) - 1


def _challenge_out(db: Session, c: ChessChallenge) -> ChallengeOut:
    return ChallengeOut(
        id=c.id,
        challenger_id=c.challenger_id,
        challenged_id=c.challenged_id,
        challenger_name=_display_name(db, c.challenger),
        challenged_name=_display_name(db, c.challenged),
        time_control=c.time_control,
        status=c.status,
        game_id=c.game_id,
        message=c.message,
        created_at=c.created_at,
    )


# ── Local game submission ──────────────────────────────────────────────────────

@router.post("/games", response_model=ChessGameOut, status_code=201)
def submit_game(
    payload: ChessGameCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    game = ChessGame(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        white_id=current_user.id,
        black_id=None,
        mode=payload.mode,
        status="ended",
        time_control=payload.time_control,
        result=payload.result,
        draw_reason=payload.draw_reason,
        pgn=payload.pgn,
        final_fen=payload.final_fen,
        total_moves=payload.total_moves,
        started_at=payload.started_at,
        ended_at=payload.ended_at or datetime.now(timezone.utc),
    )
    db.add(game)
    db.flush()
    for m in payload.moves:
        db.add(ChessMove(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            game_id=game.id,
            ply=m.ply, uci=m.uci, san=m.san, fen_after=m.fen_after,
        ))
    _update_stats(db, game, tenant_id)
    db.commit()
    db.refresh(game)
    return _game_out(db, game)


@router.get("/games/my", response_model=List[ChessGameOut])
def my_games(
    limit: int = Query(30, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    games = (
        db.query(ChessGame)
        .filter(
            ChessGame.organization_id == tenant_id,
            (ChessGame.white_id == current_user.id) | (ChessGame.black_id == current_user.id),
        )
        .order_by(ChessGame.created_at.desc())
        .limit(limit)
        .all()
    )
    return [_game_out(db, g) for g in games]


@router.get("/games/live", response_model=List[LiveGameOut])
def list_live_games(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Returns all in-progress games for this organisation."""
    games = (
        db.query(ChessGame)
        .filter(
            ChessGame.organization_id == tenant_id,
            ChessGame.status == "in_progress",
        )
        .order_by(ChessGame.started_at.desc())
        .limit(50)
        .all()
    )
    result = []
    for g in games:
        gid = str(g.id)
        session = ws_manager.get(gid)
        if session:
            ply = len(session.san_list)
            spec_count = session.spectator_count
        else:
            ply = db.query(ChessMove).filter(ChessMove.game_id == g.id).count()
            spec_count = 0
        result.append(LiveGameOut(
            id=g.id,
            white_name=_display_name(db, g.white) or "White",
            black_name=_display_name(db, g.black) or "Black",
            ply=ply,
            time_control=g.time_control,
            spectator_count=spec_count,
        ))
    return result


@router.get("/games", response_model=List[ChessGameOut])
def list_games(
    player_id: Optional[uuid.UUID] = Query(None),
    mode: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    q = db.query(ChessGame).filter(ChessGame.organization_id == tenant_id)
    if player_id:
        q = q.filter(
            (ChessGame.white_id == player_id) | (ChessGame.black_id == player_id)
        )
    if mode:
        q = q.filter(ChessGame.mode == mode)
    return [_game_out(db, g) for g in q.order_by(ChessGame.created_at.desc()).limit(limit)]


@router.get("/games/{game_id}", response_model=ChessGameDetailOut)
def get_game(
    game_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    game = db.query(ChessGame).filter(
        ChessGame.id == game_id, ChessGame.organization_id == tenant_id
    ).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")
    base = _game_out(db, game)
    return ChessGameDetailOut(
        **base.model_dump(),
        moves=[{"ply": m.ply, "uci": m.uci, "san": m.san, "fen_after": m.fen_after}
               for m in game.moves],
    )


def _maybe_advance_tournament(db: Session, game: ChessGame) -> None:
    """If this just-finished online game backs a chess-tournament match, record
    the winner and advance the bracket automatically — no manual report needed.
    Decisive results only; a draw is left for the organizer to break. Imports are
    local to avoid a router-level import cycle."""
    if game.result not in ("white_wins", "black_wins"):
        return
    from app.models.chess_tournament import ChessTournament, ChessTournamentMatch
    from app.routers.chess_tournaments import _advance

    m = (
        db.query(ChessTournamentMatch)
        .filter(
            ChessTournamentMatch.game_id == game.id,
            ChessTournamentMatch.winner_id.is_(None),
        )
        .first()
    )
    if not m:
        return
    winner_id = game.white_id if game.result == "white_wins" else game.black_id
    if winner_id not in (m.player_a_id, m.player_b_id):
        return
    tour = (
        db.query(ChessTournament)
        .filter(ChessTournament.id == m.tournament_id)
        .first()
    )
    if tour:
        _advance(db, tour, m, winner_id)


@router.patch("/games/{game_id}", response_model=ChessGameOut)
def patch_game(
    game_id: uuid.UUID,
    payload: ChessGamePatch,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    game = db.query(ChessGame).filter(
        ChessGame.id == game_id,
        ChessGame.organization_id == tenant_id,
        (ChessGame.white_id == current_user.id) | (ChessGame.black_id == current_user.id),
    ).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found or not yours")
    already_had_result = game.result is not None
    for field, val in payload.model_dump(exclude_none=True).items():
        setattr(game, field, val)
    if payload.result and not already_had_result:
        _update_stats(db, game, tenant_id)
        _maybe_advance_tournament(db, game)
    db.commit()
    db.refresh(game)
    return _game_out(db, game)


# ── Player stats ───────────────────────────────────────────────────────────────

def _stats_out(user_id, stats: Optional[ChessPlayerStats]) -> ChessPlayerStatsOut:
    if not stats:
        title = prestige_title(1500.0, 0)
        return ChessPlayerStatsOut(
            user_id=user_id, glicko_rating=1500.0, glicko_rd=350.0,
            games_played=0, wins=0, losses=0, draws=0,
            current_streak=0, longest_win_streak=0, win_rate=0.0,
            title=title, title_emoji=title_emoji(title),
        )
    wr = round(stats.wins / stats.games_played, 3) if stats.games_played else 0.0
    title = prestige_title(stats.glicko_rating, stats.games_played)
    return ChessPlayerStatsOut(
        user_id=stats.user_id,
        glicko_rating=round(stats.glicko_rating, 1),
        glicko_rd=round(stats.glicko_rd, 1),
        games_played=stats.games_played,
        wins=stats.wins, losses=stats.losses, draws=stats.draws,
        current_streak=stats.current_streak,
        longest_win_streak=stats.longest_win_streak,
        win_rate=wr,
        title=title, title_emoji=title_emoji(title),
    )


@router.get("/players/me/stats", response_model=ChessPlayerStatsOut)
def my_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    stats = db.query(ChessPlayerStats).filter(
        ChessPlayerStats.user_id == current_user.id
    ).first()
    return _stats_out(current_user.id, stats)


@router.get("/players/{user_id}/stats", response_model=ChessPlayerStatsOut)
def player_stats(
    user_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    stats = db.query(ChessPlayerStats).filter(
        ChessPlayerStats.user_id == user_id
    ).first()
    return _stats_out(user_id, stats)


@router.get("/players/{user_id}/profile", response_model=PlayerProfileOut)
def player_profile(
    user_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Full prestige profile: rating, title, rival, recent form."""
    stats = db.query(ChessPlayerStats).filter(
        ChessPlayerStats.user_id == user_id
    ).first()
    stats_out = _stats_out(user_id, stats)

    # Recent form: last 10 online games
    recent_games = (
        db.query(ChessGame)
        .filter(
            ChessGame.organization_id == tenant_id,
            ChessGame.mode == "online",
            ChessGame.status == "ended",
            ChessGame.result.isnot(None),
            (ChessGame.white_id == user_id) | (ChessGame.black_id == user_id),
        )
        .order_by(ChessGame.ended_at.desc())
        .limit(10)
        .all()
    )
    form = []
    for g in recent_games:
        is_white = str(g.white_id) == str(user_id)
        if g.result == "draw":
            form.append("D")
        elif (is_white and g.result == "white_wins") or (not is_white and g.result == "black_wins"):
            form.append("W")
        else:
            form.append("L")

    # Rivalry: most-played online opponent
    rival_name = None
    rival_id = None
    from collections import Counter
    opp_counts: Counter = Counter()
    all_online = (
        db.query(ChessGame)
        .filter(
            ChessGame.organization_id == tenant_id,
            ChessGame.mode == "online",
            ChessGame.status == "ended",
            (ChessGame.white_id == user_id) | (ChessGame.black_id == user_id),
        )
        .all()
    )
    for g in all_online:
        opp = g.black_id if str(g.white_id) == str(user_id) else g.white_id
        if opp:
            opp_counts[str(opp)] += 1
    if opp_counts:
        top_opp_id, _ = opp_counts.most_common(1)[0]
        rival = db.query(User).filter(User.id == top_opp_id).first()
        if rival:
            rival_id = str(rival.id)
            profile = db.query(UserProfile).filter(UserProfile.user_id == rival.id).first()
            rival_name = (profile.full_name_en or profile.full_name_ta) if profile else str(rival.id)

    return PlayerProfileOut(
        user_id=user_id,
        glicko_rating=stats_out.glicko_rating,
        glicko_rd=stats_out.glicko_rd,
        games_played=stats_out.games_played,
        wins=stats_out.wins, losses=stats_out.losses, draws=stats_out.draws,
        win_rate=stats_out.win_rate,
        current_streak=stats_out.current_streak,
        longest_win_streak=stats_out.longest_win_streak,
        title=stats_out.title,
        title_emoji=stats_out.title_emoji,
        recent_form=form[:10],
        rival_id=rival_id,
        rival_name=rival_name,
    )


# ── Members list (for challenge opponent search) ───────────────────────────────

@router.get("/members", response_model=List[ChessMemberOut])
def chess_members(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Returns all org members with their chess ratings (excluding self)."""
    users = (
        db.query(User)
        .filter(User.organization_id == tenant_id, User.id != current_user.id)
        .limit(200)
        .all()
    )
    result = []
    for u in users:
        profile = db.query(UserProfile).filter(UserProfile.user_id == u.id).first()
        name = (profile.full_name_en or profile.full_name_ta) if profile else str(u.id)
        stats = db.query(ChessPlayerStats).filter(
            ChessPlayerStats.user_id == u.id
        ).first()
        rating = round(stats.glicko_rating, 1) if stats else 1500.0
        games = stats.games_played if stats else 0
        result.append(ChessMemberOut(
            user_id=u.id,
            name=name,
            area=None,
            glicko_rating=rating,
            games_played=games,
        ))
    return sorted(result, key=lambda m: m.glicko_rating, reverse=True)


# ── Challenges ─────────────────────────────────────────────────────────────────

@router.post("/challenges", response_model=ChallengeOut, status_code=201)
def create_challenge(
    payload: ChallengeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    if payload.challenged_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot challenge yourself")
    challenged = db.query(User).filter(
        User.id == payload.challenged_id,
        User.organization_id == tenant_id,
    ).first()
    if not challenged:
        raise HTTPException(status_code=404, detail="Member not found")
    # Cancel any existing pending challenge between same pair
    existing = db.query(ChessChallenge).filter(
        ChessChallenge.challenger_id == current_user.id,
        ChessChallenge.challenged_id == payload.challenged_id,
        ChessChallenge.status == "pending",
    ).first()
    if existing:
        existing.status = "expired"
    c = ChessChallenge(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        challenger_id=current_user.id,
        challenged_id=payload.challenged_id,
        time_control=payload.time_control,
        message=payload.message,
        status="pending",
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return _challenge_out(db, c)


@router.get("/challenges/incoming", response_model=List[ChallengeOut])
def incoming_challenges(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    challenges = (
        db.query(ChessChallenge)
        .filter(
            ChessChallenge.challenged_id == current_user.id,
            ChessChallenge.status == "pending",
            ChessChallenge.organization_id == tenant_id,
        )
        .order_by(ChessChallenge.created_at.desc())
        .all()
    )
    return [_challenge_out(db, c) for c in challenges]


@router.get("/challenges/outgoing", response_model=List[ChallengeOut])
def outgoing_challenges(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    challenges = (
        db.query(ChessChallenge)
        .filter(
            ChessChallenge.challenger_id == current_user.id,
            ChessChallenge.status == "pending",
            ChessChallenge.organization_id == tenant_id,
        )
        .order_by(ChessChallenge.created_at.desc())
        .all()
    )
    return [_challenge_out(db, c) for c in challenges]


@router.post("/challenges/{challenge_id}/accept", response_model=ChallengeAcceptOut)
def accept_challenge(
    challenge_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    c = db.query(ChessChallenge).filter(
        ChessChallenge.id == challenge_id,
        ChessChallenge.challenged_id == current_user.id,
        ChessChallenge.status == "pending",
    ).first()
    if not c:
        raise HTTPException(status_code=404, detail="Challenge not found or already handled")

    # Randomly assign colors (challenger is white, challenged is black — simple rule)
    game = ChessGame(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        white_id=c.challenger_id,
        black_id=c.challenged_id,
        mode="online",
        status="waiting",
        time_control=c.time_control,
        started_at=datetime.now(timezone.utc),
    )
    db.add(game)
    db.flush()

    c.status = "accepted"
    c.game_id = game.id
    db.commit()
    db.refresh(game)

    challenger_name = _display_name(db, c.challenger) or "Opponent"
    return ChallengeAcceptOut(
        game_id=game.id,
        color="black",  # accepting player is black
        opponent_name=challenger_name,
        time_control=c.time_control,
    )


@router.post("/challenges/{challenge_id}/decline")
def decline_challenge(
    challenge_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    c = db.query(ChessChallenge).filter(
        ChessChallenge.id == challenge_id,
        ChessChallenge.challenged_id == current_user.id,
        ChessChallenge.status == "pending",
    ).first()
    if not c:
        raise HTTPException(status_code=404, detail="Challenge not found")
    c.status = "declined"
    db.commit()
    return {"ok": True}


# ── WebSocket: spectate game ───────────────────────────────────────────────────

@router.websocket("/games/{game_id}/spectate")
async def spectate_websocket(
    game_id: str,
    websocket: WebSocket,
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    # ── Auth ──────────────────────────────────────────────────────────────────
    try:
        payload = decode_token(token)
        user_id = str(payload["sub"])
    except Exception:
        await websocket.close(code=4001, reason="Invalid token")
        return

    # ── Load game ─────────────────────────────────────────────────────────────
    try:
        gid = uuid.UUID(game_id)
    except ValueError:
        await websocket.close(code=4002, reason="Invalid game_id")
        return

    game = db.query(ChessGame).filter(ChessGame.id == gid).first()
    if not game:
        await websocket.close(code=4003, reason="Game not found")
        return

    if game.status not in ("waiting", "in_progress"):
        await websocket.close(code=4005, reason="Game is not live")
        return

    # ── Accept + register as spectator ────────────────────────────────────────
    await websocket.accept()

    session = ws_manager.get(str(gid))
    if not session:
        # Game exists in DB but session hasn't started yet — send minimal snapshot
        await websocket.send_text(__import__("json").dumps({
            "type": "waiting",
            "role": "spectator",
        }))
        await websocket.close()
        return

    await session.add_spectator(user_id, websocket)

    # Send current state immediately
    await websocket.send_text(__import__("json").dumps(session.spectator_snapshot()))

    # Notify players of new spectator count
    await session.broadcast(
        {"type": "spectator_count", "count": session.spectator_count},
        players_only=True,
    )

    # ── Spectator message loop ─────────────────────────────────────────────────
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = __import__("json").loads(raw)
            except Exception:
                continue
            if msg.get("type") == "ping":
                await websocket.send_text(__import__("json").dumps({"type": "pong"}))
    except WebSocketDisconnect:
        pass
    finally:
        await session.remove_spectator(user_id)
        await session.broadcast(
            {"type": "spectator_count", "count": session.spectator_count},
            players_only=True,
        )


# ── WebSocket: live game ───────────────────────────────────────────────────────

@router.websocket("/games/{game_id}/ws")
async def game_websocket(
    game_id: str,
    websocket: WebSocket,
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    # ── Auth ──────────────────────────────────────────────────────────────────
    try:
        payload = decode_token(token)
        user_id = payload["sub"]
    except Exception:
        await websocket.close(code=4001, reason="Invalid token")
        return

    # ── Load game ─────────────────────────────────────────────────────────────
    try:
        gid = uuid.UUID(game_id)
    except ValueError:
        await websocket.close(code=4002, reason="Invalid game_id")
        return

    game = db.query(ChessGame).filter(ChessGame.id == gid).first()
    if not game:
        await websocket.close(code=4003, reason="Game not found")
        return

    uid = str(user_id)
    white_id = str(game.white_id) if game.white_id else None
    black_id = str(game.black_id) if game.black_id else None

    if uid not in (white_id, black_id):
        await websocket.close(code=4004, reason="Not a player in this game")
        return

    # ── Accept + register ─────────────────────────────────────────────────────
    await websocket.accept()

    white_name = _display_name(db, game.white) or "White"
    black_name = _display_name(db, game.black) or "Black"

    session = ws_manager.get_or_create(
        game_id=str(gid),
        white_id=white_id,
        black_id=black_id,
        white_name=white_name,
        black_name=black_name,
        time_control=game.time_control,
    )

    session.cancel_disconnect_timer(uid)
    session.connections[uid] = websocket

    # Sync state for reconnecting player
    await session.send_to(uid, session.state_snapshot(uid))

    # Notify both when game is fully connected
    if session.both_connected():
        if game.status == "waiting":
            game.status = "in_progress"
            db.commit()
        session.start_clock()
        start_msg: dict = {
            "type": "game_start",
            "white_name": white_name,
            "black_name": black_name,
            "time_control": game.time_control,
            "fen": session.board.fen(),
            "turn": "white",
        }
        clock = session.clock_snapshot()
        if clock:
            start_msg["clock"] = clock
        await session.broadcast(start_msg)
    else:
        await session.send_to(uid, {"type": "waiting", "color": session.get_color(uid)})

    # ── Message loop ──────────────────────────────────────────────────────────
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = __import__("json").loads(raw)
            except Exception:
                continue

            msg_type = msg.get("type")

            if msg_type == "move":
                if not session.is_user_turn(uid):
                    await session.send_to(uid, {"type": "error", "message": "Not your turn"})
                    continue

                uci = msg.get("uci", "")
                # Deduct time before applying move (measures thinking time)
                session.deduct_time(uid)
                move = session.apply_move(uci)
                if move is None:
                    await session.send_to(uid, {"type": "error", "message": f"Illegal move: {uci}"})
                    continue

                san = session.san_list[-1]
                fen = session.board.fen()
                ply = len(session.san_list)
                turn = "white" if session.board.turn else "black"

                # Persist move to DB
                org_id = game.organization_id
                db.add(ChessMove(
                    id=uuid.uuid4(),
                    organization_id=org_id,
                    game_id=gid,
                    ply=ply,
                    uci=uci,
                    san=san,
                    fen_after=fen,
                ))
                db.commit()

                move_msg: dict = {
                    "type": "move",
                    "uci": uci,
                    "san": san,
                    "fen": fen,
                    "ply": ply,
                    "turn": turn,
                }
                clock = session.clock_snapshot()
                if clock:
                    move_msg["clock"] = clock
                await session.broadcast(move_msg)

                over = session.game_over_result()
                if over:
                    game.result = over["result"]
                    game.draw_reason = over.get("reason")
                    game.status = "ended"
                    game.total_moves = ply
                    game.ended_at = datetime.now(timezone.utc)
                    _update_stats(db, game, game.organization_id)
                    db.commit()
                    await session.broadcast({"type": "game_over", **over})
                    ws_manager.remove(str(gid))
                    break

            elif msg_type == "flag":
                # Client claims opponent/self has run out of time
                color = session.get_color(uid)
                if color and session.is_flagged(color):
                    # Our own flag: we lose
                    result = "black_wins" if color == "white" else "white_wins"
                    game.result = result
                    game.status = "ended"
                    game.total_moves = len(session.san_list)
                    game.ended_at = datetime.now(timezone.utc)
                    _update_stats(db, game, game.organization_id)
                    db.commit()
                    await session.broadcast({
                        "type": "game_over",
                        "result": result,
                        "reason": "time",
                    })
                    ws_manager.remove(str(gid))
                    break
                else:
                    # Spurious flag claim — ignore
                    pass

            elif msg_type == "resign":
                color = session.get_color(uid)
                result = "black_wins" if color == "white" else "white_wins"
                game.result = result
                game.status = "ended"
                game.total_moves = len(session.san_list)
                game.ended_at = datetime.now(timezone.utc)
                _update_stats(db, game, game.organization_id)
                db.commit()
                await session.broadcast({"type": "game_over", "result": result, "reason": "resignation"})
                ws_manager.remove(str(gid))
                break

            elif msg_type == "offer_draw":
                session.draw_offered_by = uid
                opp = session.opponent_id(uid)
                if opp:
                    await session.send_to(opp, {"type": "draw_offered"})

            elif msg_type == "accept_draw":
                if session.draw_offered_by and session.draw_offered_by != uid:
                    game.result = "draw"
                    game.draw_reason = "agreement"
                    game.status = "ended"
                    game.total_moves = len(session.san_list)
                    game.ended_at = datetime.now(timezone.utc)
                    _update_stats(db, game, game.organization_id)
                    db.commit()
                    await session.broadcast({"type": "game_over", "result": "draw", "reason": "agreement"})
                    ws_manager.remove(str(gid))
                    break

            elif msg_type == "decline_draw":
                session.draw_offered_by = None
                opp = session.opponent_id(uid)
                if opp:
                    await session.send_to(opp, {"type": "draw_declined"})

            elif msg_type == "sync":
                await session.send_to(uid, session.state_snapshot(uid))

            elif msg_type == "ping":
                await session.send_to(uid, {"type": "pong"})

    except WebSocketDisconnect:
        pass
    finally:
        session.connections.pop(uid, None)
        opp = session.opponent_id(uid)

        if opp in session.connections:
            await session.send_to(opp, {
                "type": "opponent_disconnected",
                "seconds_until_forfeit": 60,
            })

            async def forfeit(disconnected_uid: str):
                color = session.get_color(disconnected_uid)
                result = "black_wins" if color == "white" else "white_wins"
                game.result = result
                game.status = "ended"
                game.ended_at = datetime.now(timezone.utc)
                _update_stats(db, game, game.organization_id)
                db.commit()
                await session.broadcast({
                    "type": "game_over",
                    "result": result,
                    "reason": "disconnect_forfeit",
                })
                ws_manager.remove(str(gid))

            session.start_disconnect_timer(uid, forfeit)
        else:
            # Both disconnected — leave session alive briefly for reconnect
            pass
