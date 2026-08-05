import random
import uuid
import logging
import time
from collections import deque
from datetime import datetime, timezone, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, WebSocket, WebSocketDisconnect
from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi.concurrency import run_in_threadpool
from sqlalchemy.orm import Session

from app.core.database import get_db, SessionLocal
from app.core.security import decode_token
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.chess import (
    ChessGame, ChessMove, ChessPlayerStats, ChessChallenge, ChessSeek,
)
from app.models.user import User, UserProfile
from app.schemas.chess import (
    ChessGameCreate, ChessGamePatch,
    ChessGameOut, ChessGameDetailOut,
    ChessPlayerStatsOut, ChessMemberOut,
    ChallengeCreate, ChallengeOut, ChallengeAcceptOut,
    LiveGameOut, PlayerProfileOut,
    SeekCreate, SeekOut, SeekAcceptOut,
)
from app.services.chess_ws_manager import (
    ws_manager, DISCONNECT_GRACE_SECONDS, is_valid_time_control, _initial_time_ms,
)
from app.core.short_code import generate_unique_short_code
from app.services.glicko2 import update as glicko2_update, PlayerRating, prestige_title, title_emoji

logger = logging.getLogger(__name__)
from app.core.config import settings as _settings

router = APIRouter(prefix="/chess", tags=["Chess"])
# Disabled under TESTING so the in-memory counter can't trip across the suite's
# shared client address; enforced in every real deployment.
limiter = Limiter(key_func=get_remote_address, enabled=not _settings.TESTING)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _display_name(db: Session, user: Optional[User]) -> Optional[str]:
    if user is None:
        return None
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    if profile:
        return profile.full_name_en or profile.full_name_ta
    return None


def _display_names(db: Session, user_ids) -> dict:
    """Resolve many display names in ONE query (kills the per-game N+1 in live/
    list endpoints). Returns {user_id: name}; missing ids are simply absent."""
    ids = {u for u in user_ids if u}
    if not ids:
        return {}
    rows = (
        db.query(UserProfile.user_id, UserProfile.full_name_en, UserProfile.full_name_ta)
        .filter(UserProfile.user_id.in_(ids))
        .all()
    )
    return {uid: (en or ta) for uid, en, ta in rows}


def _move_counts(db: Session, game_ids) -> dict:
    """Count moves for many games in ONE grouped query instead of a COUNT per
    game. Returns {game_id: ply_count}."""
    ids = {g for g in game_ids if g}
    if not ids:
        return {}
    from sqlalchemy import func as _func
    rows = (
        db.query(ChessMove.game_id, _func.count(ChessMove.id))
        .filter(ChessMove.game_id.in_(ids))
        .group_by(ChessMove.game_id)
        .all()
    )
    return {gid: c for gid, c in rows}


def _live_games_out(db: Session, games) -> list:
    """Serialise live ChessGames to LiveGameOut with batched name + move-count
    lookups — 2 queries total regardless of how many games (was 3×N)."""
    if not games:
        return []
    names = _display_names(db, [g.white_id for g in games] + [g.black_id for g in games])
    # Move counts only needed for games with no in-memory session (else we use
    # the live ply). Batch-count just those.
    no_session_ids = [g.id for g in games if ws_manager.get(str(g.id)) is None]
    counts = _move_counts(db, no_session_ids)
    out = []
    for g in games:
        session = ws_manager.get(str(g.id))
        if session:
            ply = len(session.san_list)
            spec = session.spectator_count
        else:
            ply = counts.get(g.id, 0)
            spec = 0
        out.append(LiveGameOut(
            id=g.id,
            white_name=names.get(g.white_id) or "White",
            black_name=names.get(g.black_id) or "Black",
            ply=ply,
            time_control=g.time_control,
            spectator_count=spec,
        ))
    return out


def _notify_chess(
    db: Session,
    *,
    user_id: uuid.UUID,
    org_id: uuid.UUID,
    title_en: str,
    body_en: str,
    title_ta: str,
    body_ta: str,
    data: dict,
) -> None:
    """Best-effort push to the opponent about a challenge / acceptance.

    Online-chess challenges are otherwise only surfaced by the recipient
    polling the inbox, so a player who isn't already sitting on that screen
    never sees the request. A push (data type `chess_challenge`/`chess_accept`,
    which the mobile ChallengePage already listens for) wakes the app to
    reload and also posts a tray notification when it's backgrounded. Never
    raises into the caller — delivery must not break creating the challenge.
    """
    try:
        # Imported lazily so the chess router has no hard dependency on the
        # notification stack (and firebase init) at import time.
        from app.services.notification_service import NotificationService

        # Push-only: a game challenge should ping the opponent's device, not
        # fan out to WhatsApp/email (both default-on) like a broadcast would.
        NotificationService(db).send_push_only(
            user_id=user_id,
            organization_id=org_id,
            title_en=title_en,
            title_ta=title_ta,
            body_en=body_en,
            body_ta=body_ta,
            notification_type="CHESS",
            data=data,
        )
    except Exception as e:  # pragma: no cover - best-effort delivery
        logger.warning(f"chess notify failed (non-fatal): {e}")


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


@router.get("/games/active", response_model=Optional[ChessGameOut])
def active_game(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """The player's current joinable game (status waiting or in_progress), if any.

    This is the reliable, poll-anywhere signal that a game is ready — the app
    polls it globally so the CHALLENGER always gets pulled into the game even if
    they left the challenge screen or the accept push never arrived (push is
    best-effort and off unless Firebase is configured). Returns null when the
    player has no game to join.
    """
    g = (
        db.query(ChessGame)
        .filter(
            ChessGame.organization_id == tenant_id,
            ChessGame.status.in_(("waiting", "in_progress")),
            (ChessGame.white_id == current_user.id) | (ChessGame.black_id == current_user.id),
        )
        .order_by(ChessGame.created_at.desc())
        .first()
    )
    return _game_out(db, g) if g else None


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
    return _live_games_out(db, games)


@router.get("/public/games/live", response_model=List[LiveGameOut])
@limiter.limit("60/minute")
def list_public_live_games(
    request: Request,
    tournament: Optional[uuid.UUID] = None,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Public telecast: all in-progress games for the org, no auth required, so a
    web/Android 'Live now' list can show games to anyone. Tenant comes from the
    X-Organization-ID header (same as other public endpoints). Pass ?tournament=
    to scope to one chess tournament's live games (for its share-link telecast)."""
    q = db.query(ChessGame).filter(
        ChessGame.organization_id == tenant_id,
        ChessGame.status == "in_progress",
    )
    if tournament is not None:
        from app.models.chess_tournament import ChessTournamentMatch
        game_ids = [
            m.game_id for m in db.query(ChessTournamentMatch.game_id)
            .filter(ChessTournamentMatch.tournament_id == tournament,
                    ChessTournamentMatch.game_id.isnot(None))
            .all()
        ]
        if not game_ids:
            return []
        q = q.filter(ChessGame.id.in_(game_ids))
    games = q.order_by(ChessGame.started_at.desc()).limit(50).all()
    return _live_games_out(db, games)


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
    """Returns all org members with their chess ratings (excluding self, and
    excluding imported directory contacts like Friends2Support donors — they are
    not real app users/opponents)."""
    users = (
        db.query(User)
        .filter(
            User.organization_id == tenant_id,
            User.id != current_user.id,
            (User.source.is_(None)) | (User.source != "F2S_IMPORT"),
        )
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
@limiter.limit("20/minute")
def create_challenge(
    request: Request,
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

    challenger_name = _display_name(db, current_user) or "A member"
    _notify_chess(
        db,
        user_id=challenged.id,
        org_id=tenant_id,
        title_en="♟️ Chess challenge",
        body_en=f"{challenger_name} challenged you to a game.",
        title_ta="♟️ சதுரங்க அழைப்பு",
        body_ta=f"{challenger_name} உங்களை விளையாட அழைத்துள்ளார்.",
        data={"type": "chess_challenge", "route": "/chess/challenge"},
    )
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
    accepter_name = _display_name(db, current_user) or "Your opponent"
    _notify_chess(
        db,
        user_id=c.challenger_id,
        org_id=tenant_id,
        title_en="♟️ Challenge accepted",
        body_en=f"{accepter_name} accepted — the game is starting.",
        title_ta="♟️ அழைப்பு ஏற்கப்பட்டது",
        body_ta=f"{accepter_name} ஏற்றுக்கொண்டார் — விளையாட்டு தொடங்குகிறது.",
        data={
            "type": "chess_accept",
            "route": f"/chess/online/{game.id}",
            "game_id": str(game.id),
        },
    )
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
    token: str = Query(None),
):
    # A WebSocket lives for minutes; taking Depends(get_db) would pin one of the
    # (30) pooled DB connections for the whole time, and enough open sockets
    # would starve the pool and stall ball-scoring. Instead every DB touch uses
    # a short-lived SessionLocal() opened off the event loop, then closed.
    # ── Identity (public telecast: token OPTIONAL) ─────────────────────────────
    # Spectating is public — anyone with the link can watch. A token, if present,
    # only labels the viewer; anonymous viewers get a unique ephemeral id so they
    # don't collide in the spectators map.
    user_id: Optional[str] = None
    if token:
        try:
            user_id = str(decode_token(token)["sub"])
        except Exception:
            user_id = None
    if not user_id:
        user_id = f"anon_{uuid.uuid4().hex[:12]}"

    # ── Load game ─────────────────────────────────────────────────────────────
    try:
        gid = uuid.UUID(game_id)
    except ValueError:
        await websocket.close(code=4002, reason="Invalid game_id")
        return

    # Load everything needed to (re)build a live session from the DB, so a
    # spectator can attach even after a redeploy wiped the in-memory session.
    def _load_game():
        with SessionLocal() as s:
            g = s.query(ChessGame).filter(ChessGame.id == gid).first()
            if g is None:
                return None
            moves = [
                m.uci for m in s.query(ChessMove)
                .filter(ChessMove.game_id == gid)
                .order_by(ChessMove.ply.asc())
                .all()
            ]
            return {
                "status": g.status,
                "white_id": str(g.white_id) if g.white_id else "",
                "black_id": str(g.black_id) if g.black_id else "",
                "white_name": _display_name(s, g.white) or "White",
                "black_name": _display_name(s, g.black) or "Black",
                "time_control": g.time_control,
                "moves": moves,
                "clock": {
                    "white_time_ms": g.white_time_ms,
                    "black_time_ms": g.black_time_ms,
                    "last_move_at": g.last_move_at,
                },
            }

    loaded = await run_in_threadpool(_load_game)
    if loaded is None:
        await websocket.close(code=4003, reason="Game not found")
        return
    if loaded["status"] not in ("waiting", "in_progress"):
        await websocket.close(code=4005, reason="Game is not live")
        return

    # ── Accept + register as spectator ────────────────────────────────────────
    await websocket.accept()

    # Reuse the live session if present; otherwise rebuild it from the persisted
    # moves so the telecast shows the true position (survives redeploys). Only
    # seeds on create — a live game is never re-replayed.
    session = ws_manager.get_or_create(
        game_id=str(gid),
        white_id=loaded["white_id"],
        black_id=loaded["black_id"],
        white_name=loaded["white_name"],
        black_name=loaded["black_name"],
        time_control=loaded["time_control"],
        initial_uci=loaded["moves"],
        initial_clock=loaded["clock"],
    )

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
):
    # No Depends(get_db): a game socket lives for minutes; pinning a pooled
    # connection that whole time would starve the pool (and ball-scoring) once a
    # handful of games are live. Every DB touch below uses a short-lived
    # SessionLocal() opened off the event loop.
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

    # Load the game AND resolve player display names in one short-lived session,
    # returning only the scalars we need — nothing stays attached to a session
    # that outlives the query.
    def _load_game():
        with SessionLocal() as s:
            g = s.query(ChessGame).filter(ChessGame.id == gid).first()
            if g is None:
                return None
            # Also load the moves so a freshly-(re)created session can replay the
            # game to its true position — surviving redeploys without resetting
            # the board to move 1 or duplicating ply numbers.
            moves = [
                m.uci for m in s.query(ChessMove)
                .filter(ChessMove.game_id == gid)
                .order_by(ChessMove.ply.asc())
                .all()
            ]
            return {
                "white_id": str(g.white_id) if g.white_id else None,
                "black_id": str(g.black_id) if g.black_id else None,
                "org_id": g.organization_id,
                "time_control": g.time_control,
                "status": g.status,
                "white_name": _display_name(s, g.white) or "White",
                "black_name": _display_name(s, g.black) or "Black",
                "moves": moves,
                # Durable clock, so a restarted process resumes the real times
                # instead of handing both players a fresh full clock.
                "clock": {
                    "white_time_ms": g.white_time_ms,
                    "black_time_ms": g.black_time_ms,
                    "last_move_at": g.last_move_at,
                },
            }

    loaded = await run_in_threadpool(_load_game)
    if loaded is None:
        await websocket.close(code=4003, reason="Game not found")
        return

    uid = str(user_id)
    white_id = loaded["white_id"]
    black_id = loaded["black_id"]
    game_org_id = loaded["org_id"]
    game_time_control = loaded["time_control"]
    game_status = loaded["status"]
    white_name = loaded["white_name"]
    black_name = loaded["black_name"]
    game_moves = loaded["moves"]

    if uid not in (white_id, black_id):
        await websocket.close(code=4004, reason="Not a player in this game")
        return

    # ── Accept + register ─────────────────────────────────────────────────────
    await websocket.accept()

    # Finalize a completed game (result + rating/stat updates) in a fresh
    # session. Idempotent: it re-loads the row and bails if the game is already
    # ended, so two racing end-conditions (e.g. a flag claim and a mating move)
    # can never rate/finalize the game twice.
    def _end_game_db(result, reason, total_moves):
        with SessionLocal() as s:
            g = s.query(ChessGame).filter(ChessGame.id == gid).first()
            if not g or g.status == "ended":
                return
            g.result = result
            g.draw_reason = reason
            g.status = "ended"
            g.total_moves = total_moves
            g.ended_at = datetime.now(timezone.utc)
            _update_stats(s, g, game_org_id)
            s.commit()

    session = ws_manager.get_or_create(
        game_id=str(gid),
        white_id=white_id,
        black_id=black_id,
        white_name=white_name,
        black_name=black_name,
        time_control=game_time_control,
        initial_uci=game_moves,
        initial_clock=loaded["clock"],
    )

    session.cancel_disconnect_timer(uid)
    session.connections[uid] = websocket

    # Sync state for reconnecting player
    await session.send_to(uid, session.state_snapshot(uid))

    # Withdraw the forfeit warning if one was shown for this player. The timer
    # was already cancelled above, but until now nothing told the opponent, so
    # their screen kept counting down to a forfeit that would never happen.
    if uid in session.disconnect_notified:
        session.disconnect_notified.discard(uid)
        _opp = session.opponent_id(uid)
        if _opp:
            await session.send_to(_opp, {"type": "opponent_reconnected"})

    # Notify both when game is fully connected
    if session.both_connected():
        # Start the clock first so the opening window is part of the state we
        # persist below — otherwise a restart during the very first move lost
        # that thinking time (last_move_at was still null in the database).
        session.start_clock()
        if game_status == "waiting":
            _start_clock_state = session.clock_for_db()

            def _mark_in_progress():
                with SessionLocal() as s:
                    g = s.query(ChessGame).filter(ChessGame.id == gid).first()
                    if g and g.status == "waiting":
                        g.status = "in_progress"
                        g.started_at = g.started_at or datetime.now(timezone.utc)
                        if _start_clock_state["white_time_ms"] is not None:
                            g.white_time_ms = _start_clock_state["white_time_ms"]
                            g.black_time_ms = _start_clock_state["black_time_ms"]
                            g.last_move_at = _start_clock_state["last_move_at"]
                        s.commit()
            await run_in_threadpool(_mark_in_progress)
            game_status = "in_progress"
        start_msg: dict = {
            "type": "game_start",
            "white_name": white_name,
            "black_name": black_name,
            "time_control": game_time_control,
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
    # Per-connection flood guard: legitimate play is a few messages/sec, so >30
    # in a rolling second is abusive — drop the excess instead of letting one
    # client spin the loop (and the DB) at will.
    _recent = deque(maxlen=60)
    try:
        while True:
            raw = await websocket.receive_text()
            _mt = time.monotonic()
            _recent.append(_mt)
            if len(_recent) == _recent.maxlen and (_mt - _recent[0]) < 1.0:
                # Over the burst budget. Crucially this must NOT be a silent
                # drop: swallowing a legitimate move leaves the sender waiting
                # forever for an echo that never comes, and the board deadlocks
                # with no error anywhere (this stalled real games in the 100-bot
                # tournament simulation, always right as the window filled).
                # Tell the client instead, so it can resync and retry.
                await session.send_to(uid, {
                    "type": "error",
                    "message": "Too many messages — slow down and resync.",
                })
                await session.send_to(uid, session.state_snapshot(uid))
                continue
            try:
                msg = __import__("json").loads(raw)
            except Exception:
                continue

            msg_type = msg.get("type")

            if msg_type == "move":
                if session.paused:
                    await session.send_to(uid, {"type": "error", "message": "Game is paused — an organizer has been alerted."})
                    continue
                if not session.is_user_turn(uid):
                    await session.send_to(uid, {"type": "error", "message": "Not your turn"})
                    continue

                uci = msg.get("uci", "")

                # Adjudicate the clock BEFORE accepting the move: a player whose
                # time already expired cannot rescue themselves by finally
                # moving. Previously time was only ever charged on a move, so a
                # player could stall indefinitely and never flag.
                flagged = session.flagged_color()
                if flagged is not None:
                    _r = "black_wins" if flagged == "white" else "white_wins"
                    _tm = len(session.san_list)
                    await run_in_threadpool(lambda: _end_game_db(_r, "time", _tm))
                    await session.broadcast(
                        {"type": "game_over", "result": _r, "reason": "time"}
                    )
                    ws_manager.remove(str(gid))
                    break

                move = session.apply_move(uci)
                if move is None:
                    await session.send_to(uid, {"type": "error", "message": f"Illegal move: {uci}"})
                    continue

                # Commit thinking time + grant the increment only now that the
                # move is known legal, so illegal attempts can't farm increments.
                session.deduct_time(uid)
                # Playing on answers any outstanding draw offer — otherwise the
                # offer stayed live and could be accepted 30 moves later.
                session.draw_offered_by = None

                san = session.san_list[-1]
                fen = session.board.fen()
                ply = len(session.san_list)
                turn = "white" if session.board.turn else "black"

                org_id = game_org_id

                # ── Broadcast FIRST, persist second ──────────────────────────
                # The board is already validated + applied in memory (the source
                # of truth for a live game), so echo the move immediately — move
                # latency is then pure network, independent of DB write latency
                # (which matters a lot with an external/remote Postgres). Durable
                # persistence happens right after, off the event loop; if it ever
                # fails we roll the move back and pause + resync (below), so the
                # board can never *permanently* diverge from the database.
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

                # Measure each player's round trip right after the move that
                # starts their think time. The probe is server-initiated so a
                # client cannot inflate its own lag to win free time, and a
                # client that never answers simply gets no compensation — which
                # is exactly the behaviour before this existed.
                for _pid in (session.white_id, session.black_id):
                    if _pid in session.connections:
                        session.probe_sent(_pid)
                        await session.send_to(_pid, {"type": "latency_probe"})

                clock_state = session.clock_for_db()

                def _persist_move() -> bool:
                    # Retries transient write contention; a unique (game_id, ply)
                    # violation means the move is already stored (a reconnect race)
                    # and counts as success. Returns False only when the move is
                    # genuinely not saved after retries.
                    import time as _t
                    for _attempt in range(3):
                        try:
                            with SessionLocal() as s:
                                s.add(ChessMove(
                                    id=uuid.uuid4(),
                                    organization_id=org_id,
                                    game_id=gid,
                                    ply=ply,
                                    uci=uci,
                                    san=san,
                                    fen_after=fen,
                                ))
                                # Persist the clock in the SAME transaction as the
                                # move, so the stored times always correspond to
                                # the stored position — a restart resumes exactly
                                # where play left off.
                                if clock_state["white_time_ms"] is not None:
                                    s.query(ChessGame).filter(
                                        ChessGame.id == gid
                                    ).update({
                                        ChessGame.white_time_ms: clock_state["white_time_ms"],
                                        ChessGame.black_time_ms: clock_state["black_time_ms"],
                                        ChessGame.last_move_at: clock_state["last_move_at"],
                                    }, synchronize_session=False)
                                s.commit()
                            return True
                        except Exception as _e:  # noqa: BLE001
                            _m = str(_e).lower()
                            if "unique" in _m or "duplicate" in _m:
                                logger.info(f"[chess-persist] ply already stored game={gid} ply={ply}")
                                return True
                            if _attempt < 2:
                                _t.sleep(0.15)
                                continue
                            logger.error(f"[chess-persist] UNRECOVERABLE game={gid} ply={ply}: {_e}")
                            return False

                persisted = await run_in_threadpool(_persist_move)
                if not persisted:
                    # Rare: the move was shown but couldn't be saved. Undo it in
                    # memory, RESYNC every client to the authoritative pre-move
                    # board, freeze the game, and alert. The phantom move is thus
                    # rolled back everywhere; the game can never permanently
                    # diverge from what's durably stored.
                    session.rollback_last()
                    session.paused = True
                    logger.error(f"[chess-persist] GAME PAUSED (persist failed) game={gid} ply={ply} — organizer must resolve")
                    for _uid in list(session.connections.keys()):
                        await session.send_to(_uid, session.state_snapshot(_uid))
                    for _sid in list(session.spectators.keys()):
                        _sws = session.spectators.get(_sid)
                        if _sws:
                            try:
                                await _sws.send_text(__import__("json").dumps(session.spectator_snapshot()))
                            except Exception:
                                pass
                    await session.broadcast({"type": "game_paused", "reason": "persist_failed", "ply": ply - 1})
                    continue

                # Game-over is only declared after the deciding move is durably
                # stored, so a "checkmate" is never announced on an unsaved move.
                over = session.game_over_result()
                if over:
                    _r, _reason, _tm = over["result"], over.get("reason"), ply
                    await run_in_threadpool(lambda: _end_game_db(_r, _reason, _tm))
                    await session.broadcast({"type": "game_over", **over})
                    ws_manager.remove(str(gid))
                    break

            elif msg_type == "flag":
                # A flag claim from EITHER player. The server decides purely from
                # its own authoritative clock who (if anyone) is actually out of
                # time — so a claim about the opponent is honoured, and a false
                # claim is rejected. The old code compared only against the
                # claimant's own colour AND against a clock that was never
                # decremented, so every real claim was discarded as "spurious"
                # and timed-out games hung forever.
                flagged = session.flagged_color()
                if flagged is not None:
                    result = "black_wins" if flagged == "white" else "white_wins"
                    _tm = len(session.san_list)
                    await run_in_threadpool(lambda: _end_game_db(result, "time", _tm))
                    await session.broadcast({
                        "type": "game_over",
                        "result": result,
                        "reason": "time",
                    })
                    ws_manager.remove(str(gid))
                    break
                # Nobody has actually flagged — resync the claimant so their UI
                # stops showing a phantom 0:00 instead of leaving them stuck.
                await session.send_to(uid, session.state_snapshot(uid))

            elif msg_type == "resign":
                color = session.get_color(uid)
                result = "black_wins" if color == "white" else "white_wins"
                _tm = len(session.san_list)
                await run_in_threadpool(lambda: _end_game_db(result, "resignation", _tm))
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
                    _tm = len(session.san_list)
                    await run_in_threadpool(lambda: _end_game_db("draw", "agreement", _tm))
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

            elif msg_type == "latency_pong":
                session.probe_returned(uid)

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
                "seconds_until_forfeit": DISCONNECT_GRACE_SECONDS,
            })
            # Remember that a warning is on screen, so it can be withdrawn if
            # this player reconnects before the timer fires.
            session.disconnect_notified.add(uid)

            async def forfeit(disconnected_uid: str):
                color = session.get_color(disconnected_uid)
                result = "black_wins" if color == "white" else "white_wins"

                def _persist_forfeit():
                    # This timer fires ~60s AFTER the handler returned, so the
                    # request's `db` session is already closed — use a fresh one
                    # (and re-load the game). Runs off the event loop.
                    fdb = SessionLocal()
                    try:
                        g = fdb.query(ChessGame).filter(ChessGame.id == gid).first()
                        if not g or g.status == "ended":
                            return
                        g.result = result
                        g.status = "ended"
                        g.ended_at = datetime.now(timezone.utc)
                        _update_stats(fdb, g, g.organization_id)
                        fdb.commit()
                    finally:
                        fdb.close()

                await run_in_threadpool(_persist_forfeit)
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


# ── Open seeks ────────────────────────────────────────────────────────────────
# A directed challenge needs you to already know your opponent. A seek is the
# undirected form: it sits in a lobby until someone takes it, and its short code
# makes it a link you can send on WhatsApp.

SEEK_TTL_MINUTES = 60


def _seek_out(db: Session, s: ChessSeek, me) -> SeekOut:
    return SeekOut(
        id=s.id,
        short_code=s.short_code,
        creator_id=s.creator_id,
        creator_name=_display_name(db, s.creator) or "Player",
        time_control=s.time_control,
        preferred_color=s.preferred_color or "random",
        status=s.status,
        is_mine=str(s.creator_id) == str(me),
        game_id=s.game_id,
        created_at=s.created_at,
    )


def _expire_stale_seeks(db: Session, tenant_id) -> None:
    """Sweep seeks nobody took. Cheap, and keeps the lobby honest."""
    now = datetime.now(timezone.utc)
    db.query(ChessSeek).filter(
        ChessSeek.organization_id == tenant_id,
        ChessSeek.status == "open",
        ChessSeek.expires_at.isnot(None),
        ChessSeek.expires_at < now,
    ).update({"status": "expired"}, synchronize_session=False)


@router.post("/seeks", response_model=SeekOut, status_code=201)
@limiter.limit("20/minute")
def create_seek(
    request: Request,
    payload: SeekCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Offer a game to anyone. Returns a seek whose short_code is shareable."""
    tc = (payload.time_control or "rapid_10_0").strip()
    if not is_valid_time_control(tc):
        raise HTTPException(status_code=400, detail=f"Unknown time control '{tc}'")
    colour = (payload.preferred_color or "random").strip().lower()
    if colour not in ("white", "black", "random"):
        raise HTTPException(status_code=400, detail="preferred_color must be white, black or random")

    _expire_stale_seeks(db, tenant_id)

    # One open seek per player: a lobby full of duplicates from one person is
    # noise, and the second one could never be honoured anyway.
    existing = db.query(ChessSeek).filter(
        ChessSeek.organization_id == tenant_id,
        ChessSeek.creator_id == current_user.id,
        ChessSeek.status == "open",
    ).first()
    if existing:
        existing.time_control = tc
        existing.preferred_color = colour
        existing.expires_at = datetime.now(timezone.utc) + timedelta(minutes=SEEK_TTL_MINUTES)
        db.commit()
        db.refresh(existing)
        return _seek_out(db, existing, current_user.id)

    seek = ChessSeek(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        short_code=generate_unique_short_code(db, ChessSeek),
        creator_id=current_user.id,
        time_control=tc,
        preferred_color=colour,
        status="open",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=SEEK_TTL_MINUTES),
    )
    db.add(seek)
    db.commit()
    db.refresh(seek)
    return _seek_out(db, seek, current_user.id)


@router.get("/seeks", response_model=List[SeekOut])
def list_seeks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """The lobby: every open offer, newest first, own seek included and flagged."""
    _expire_stale_seeks(db, tenant_id)
    db.commit()
    rows = (
        db.query(ChessSeek)
        .filter(ChessSeek.organization_id == tenant_id, ChessSeek.status == "open")
        .order_by(ChessSeek.created_at.desc())
        .limit(50)
        .all()
    )
    return [_seek_out(db, s, current_user.id) for s in rows]


@router.get("/seeks/by-code/{code}", response_model=SeekOut)
def resolve_seek_code(
    code: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Resolve a shared link to its seek, so the page can show what is on offer."""
    seek = db.query(ChessSeek).filter(
        ChessSeek.organization_id == tenant_id,
        ChessSeek.short_code == code,
    ).first()
    if not seek:
        raise HTTPException(status_code=404, detail="This invitation no longer exists")
    return _seek_out(db, seek, current_user.id)


@router.delete("/seeks/{seek_id}", status_code=204)
def cancel_seek(
    seek_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    seek = db.query(ChessSeek).filter(
        ChessSeek.id == seek_id,
        ChessSeek.organization_id == tenant_id,
        ChessSeek.creator_id == current_user.id,
    ).first()
    if not seek:
        raise HTTPException(status_code=404, detail="Seek not found")
    if seek.status == "open":
        seek.status = "cancelled"
        db.commit()
    return Response(status_code=204)


@router.post("/seeks/{seek_id}/accept", response_model=SeekAcceptOut)
@limiter.limit("30/minute")
def accept_seek(
    request: Request,
    seek_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    """Take an open seek and start the game.

    Two people can tap the same offer at the same moment, so the seek is claimed
    with a conditional UPDATE: exactly one caller can move it out of `open`, and
    the loser is told it is gone rather than being handed a second game.
    """
    seek = db.query(ChessSeek).filter(
        ChessSeek.id == seek_id,
        ChessSeek.organization_id == tenant_id,
    ).first()
    if not seek:
        raise HTTPException(status_code=404, detail="This invitation no longer exists")
    if str(seek.creator_id) == str(current_user.id):
        raise HTTPException(status_code=400, detail="You cannot accept your own invitation")
    if seek.status != "open":
        raise HTTPException(status_code=409, detail="Someone already took this game")

    claimed = db.query(ChessSeek).filter(
        ChessSeek.id == seek_id,
        ChessSeek.status == "open",
    ).update(
        {"status": "matched", "accepted_by_id": current_user.id},
        synchronize_session=False,
    )
    if claimed == 0:
        db.rollback()
        raise HTTPException(status_code=409, detail="Someone already took this game")

    # Resolve colours from the creator's preference.
    pref = (seek.preferred_color or "random").lower()
    if pref == "random":
        creator_is_white = random.choice((True, False))
    else:
        creator_is_white = pref == "white"

    game = ChessGame(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        white_id=seek.creator_id if creator_is_white else current_user.id,
        black_id=current_user.id if creator_is_white else seek.creator_id,
        mode="online",
        status="waiting",
        time_control=seek.time_control,
        white_time_ms=_initial_time_ms(seek.time_control),
        black_time_ms=_initial_time_ms(seek.time_control),
        started_at=datetime.now(timezone.utc),
    )
    db.add(game)
    db.flush()
    db.query(ChessSeek).filter(ChessSeek.id == seek_id).update(
        {"game_id": game.id}, synchronize_session=False)
    db.commit()

    creator_name = _display_name(db, seek.creator) or "Opponent"
    accepter_name = _display_name(db, current_user) or "Your opponent"
    _notify_chess(
        db,
        user_id=seek.creator_id,
        org_id=tenant_id,
        title_en="♟️ Your game is on",
        body_en=f"{accepter_name} accepted your invitation.",
        title_ta="♟️ ஆட்டம் தொடங்குகிறது",
        body_ta=f"{accepter_name} உங்கள் அழைப்பை ஏற்றார்.",
        data={
            "type": "chess_accept",
            "route": f"/chess/online/{game.id}",
            "game_id": str(game.id),
        },
    )
    return SeekAcceptOut(
        game_id=game.id,
        color="black" if creator_is_white else "white",
        opponent_name=creator_name,
        time_control=seek.time_control,
    )
