import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.chess import ChessGame, ChessMove, ChessPlayerStats
from app.models.user import User, UserProfile
from app.schemas.chess import (
    ChessGameCreate, ChessGamePatch,
    ChessGameOut, ChessGameDetailOut,
    ChessPlayerStatsOut,
)

router = APIRouter(prefix="/chess", tags=["Chess"])


# ── Helpers ────────────────────────────────────────────────────────────────────

def _display_name(db: Session, user: Optional[User]) -> Optional[str]:
    if user is None:
        return None
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    if profile:
        return profile.full_name_en or profile.full_name_ta
    return str(user.id)


def _game_out(db: Session, g: ChessGame) -> ChessGameOut:
    return ChessGameOut(
        id=g.id,
        mode=g.mode,
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


def _get_or_create_stats(db: Session, user_id: uuid.UUID,
                          org_id: uuid.UUID) -> ChessPlayerStats:
    stats = db.query(ChessPlayerStats).filter(
        ChessPlayerStats.user_id == user_id
    ).first()
    if not stats:
        stats = ChessPlayerStats(
            user_id=user_id,
            organization_id=org_id,
        )
        db.add(stats)
        db.flush()
    return stats


def _update_stats(db: Session, game: ChessGame, org_id: uuid.UUID) -> None:
    """Bump win/loss/draw counters and streaks after a completed rated game."""
    if game.result is None or game.mode == "vs_ai":
        return

    pairs = []
    if game.white_id:
        won = game.result == "white_wins"
        drew = game.result == "draw"
        pairs.append((game.white_id, won, drew))
    if game.black_id:
        won = game.result == "black_wins"
        drew = game.result == "draw"
        pairs.append((game.black_id, won, drew))

    for user_id, won, drew in pairs:
        s = _get_or_create_stats(db, user_id, org_id)
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


# ── Endpoints ──────────────────────────────────────────────────────────────────

@router.post("/games", response_model=ChessGameOut, status_code=201)
def submit_game(
    payload: ChessGameCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Submit a completed game (local or online). Called fire-and-forget from mobile."""
    game = ChessGame(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        # For local games the submitting user is always white; black may be a guest
        white_id=current_user.id,
        black_id=None,          # future: resolve from member lookup by name
        mode=payload.mode,
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
            ply=m.ply,
            uci=m.uci,
            san=m.san,
            fen_after=m.fen_after,
        ))

    _update_stats(db, game, tenant_id)
    db.commit()
    db.refresh(game)
    return _game_out(db, game)


@router.get("/games", response_model=List[ChessGameOut])
def list_games(
    player_id: Optional[uuid.UUID] = Query(None),
    mode: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """List games for the org. Optionally filter by player or mode."""
    q = db.query(ChessGame).filter(ChessGame.organization_id == tenant_id)

    if player_id:
        q = q.filter(
            (ChessGame.white_id == player_id) | (ChessGame.black_id == player_id)
        )
    if mode:
        q = q.filter(ChessGame.mode == mode)

    games = q.order_by(ChessGame.created_at.desc()).limit(limit).all()
    return [_game_out(db, g) for g in games]


@router.get("/games/my", response_model=List[ChessGameOut])
def my_games(
    limit: int = Query(30, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Return the current user's game history, newest first."""
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


@router.get("/games/{game_id}", response_model=ChessGameDetailOut)
def get_game(
    game_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    game = db.query(ChessGame).filter(
        ChessGame.id == game_id,
        ChessGame.organization_id == tenant_id,
    ).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    base = _game_out(db, game)
    return ChessGameDetailOut(
        **base.model_dump(),
        moves=[{"ply": m.ply, "uci": m.uci, "san": m.san, "fen_after": m.fen_after}
               for m in game.moves],
    )


@router.patch("/games/{game_id}", response_model=ChessGameOut)
def patch_game(
    game_id: uuid.UUID,
    payload: ChessGamePatch,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Update a game's result (used by online game flow to set result on completion)."""
    game = db.query(ChessGame).filter(
        ChessGame.id == game_id,
        ChessGame.organization_id == tenant_id,
        (ChessGame.white_id == current_user.id) | (ChessGame.black_id == current_user.id),
    ).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found or not yours")

    for field, val in payload.model_dump(exclude_none=True).items():
        setattr(game, field, val)

    if payload.result and game.result is None:
        _update_stats(db, game, tenant_id)

    db.commit()
    db.refresh(game)
    return _game_out(db, game)


@router.get("/players/{user_id}/stats", response_model=ChessPlayerStatsOut)
def player_stats(
    user_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    stats = db.query(ChessPlayerStats).filter(
        ChessPlayerStats.user_id == user_id,
    ).first()
    if not stats:
        # Return zeroed stats rather than 404 for new players
        return ChessPlayerStatsOut(
            user_id=user_id,
            glicko_rating=1500.0,
            glicko_rd=350.0,
            games_played=0,
            wins=0, losses=0, draws=0,
            current_streak=0,
            longest_win_streak=0,
            win_rate=0.0,
        )
    win_rate = round(stats.wins / stats.games_played, 3) if stats.games_played else 0.0
    return ChessPlayerStatsOut(
        user_id=stats.user_id,
        glicko_rating=round(stats.glicko_rating, 1),
        glicko_rd=round(stats.glicko_rd, 1),
        games_played=stats.games_played,
        wins=stats.wins,
        losses=stats.losses,
        draws=stats.draws,
        current_streak=stats.current_streak,
        longest_win_streak=stats.longest_win_streak,
        win_rate=win_rate,
    )


@router.get("/players/me/stats", response_model=ChessPlayerStatsOut)
def my_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    return player_stats(current_user.id, db, current_user, tenant_id)
