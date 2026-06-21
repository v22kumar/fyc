from typing import Optional, List
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel


# ── Game submission (from mobile after local game ends) ────────────────────────

class ChessMoveIn(BaseModel):
    ply: int
    uci: str
    san: str
    fen_after: Optional[str] = None


class ChessGameCreate(BaseModel):
    mode: str = "local"
    time_control: str = "untimed"
    white_name: Optional[str] = None
    black_name: Optional[str] = None
    result: str
    draw_reason: Optional[str] = None
    pgn: Optional[str] = None
    final_fen: Optional[str] = None
    total_moves: int = 0
    moves: List[ChessMoveIn] = []
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None


class ChessGamePatch(BaseModel):
    result: Optional[str] = None
    draw_reason: Optional[str] = None
    pgn: Optional[str] = None
    final_fen: Optional[str] = None
    total_moves: Optional[int] = None
    status: Optional[str] = None
    ended_at: Optional[datetime] = None


# ── Challenge ──────────────────────────────────────────────────────────────────

class ChallengeCreate(BaseModel):
    challenged_id: UUID
    time_control: str = "untimed"
    message: Optional[str] = None


class ChallengeOut(BaseModel):
    id: UUID
    challenger_id: UUID
    challenged_id: UUID
    challenger_name: Optional[str] = None
    challenged_name: Optional[str] = None
    time_control: str
    status: str
    game_id: Optional[UUID] = None
    message: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ChallengeAcceptOut(BaseModel):
    game_id: UUID
    color: str          # "white" | "black"
    opponent_name: Optional[str] = None
    time_control: str


# ── Online game creation ───────────────────────────────────────────────────────

class OnlineGameCreate(BaseModel):
    white_id: UUID
    black_id: UUID
    time_control: str = "untimed"


# ── Output schemas ─────────────────────────────────────────────────────────────

class ChessMoveOut(BaseModel):
    ply: int
    uci: str
    san: str
    fen_after: Optional[str] = None

    model_config = {"from_attributes": True}


class ChessGameOut(BaseModel):
    id: UUID
    mode: str
    status: str
    time_control: str
    white_id: Optional[UUID] = None
    black_id: Optional[UUID] = None
    white_name: Optional[str] = None
    black_name: Optional[str] = None
    result: Optional[str] = None
    draw_reason: Optional[str] = None
    pgn: Optional[str] = None
    final_fen: Optional[str] = None
    total_moves: int
    white_rating_before: Optional[float] = None
    black_rating_before: Optional[float] = None
    white_rating_after: Optional[float] = None
    black_rating_after: Optional[float] = None
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ChessGameDetailOut(ChessGameOut):
    moves: List[ChessMoveOut] = []


class ChessPlayerStatsOut(BaseModel):
    user_id: UUID
    glicko_rating: float
    glicko_rd: float
    games_played: int
    wins: int
    losses: int
    draws: int
    current_streak: int
    longest_win_streak: int
    win_rate: float

    model_config = {"from_attributes": True}


class ChessMemberOut(BaseModel):
    user_id: UUID
    name: str
    area: Optional[str] = None
    glicko_rating: float
    games_played: int
