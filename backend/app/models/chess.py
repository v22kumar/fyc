import uuid
from sqlalchemy import Column, String, Integer, Text, ForeignKey, DateTime, Float
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

GAME_RESULTS = ["white_wins", "black_wins", "draw", "abandoned"]
GAME_MODES = ["local", "vs_ai", "online"]
GAME_STATUSES = ["local", "waiting", "in_progress", "ended"]
TIME_CONTROLS = ["untimed", "bullet_1_0", "blitz_3_2", "blitz_5_0", "rapid_10_0", "classical_30_0"]
DRAW_REASONS = ["stalemate", "insufficient_material", "fifty_moves", "repetition", "agreement"]
CHALLENGE_STATUSES = ["pending", "accepted", "declined", "expired"]


class ChessGame(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "chess_games"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    white_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    black_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)

    mode = Column(String(20), nullable=False, default="local")
    status = Column(String(20), nullable=False, default="local")  # local/waiting/in_progress/ended
    time_control = Column(String(30), nullable=False, default="untimed")

    result = Column(String(20), nullable=True)        # null while in progress
    draw_reason = Column(String(30), nullable=True)

    pgn = Column(Text, nullable=True)                 # full PGN text after game ends
    final_fen = Column(Text, nullable=True)
    total_moves = Column(Integer, default=0)

    white_rating_before = Column(Float, nullable=True)
    black_rating_before = Column(Float, nullable=True)
    white_rating_after = Column(Float, nullable=True)
    black_rating_after = Column(Float, nullable=True)

    started_at = Column(DateTime(timezone=True), nullable=True)
    ended_at = Column(DateTime(timezone=True), nullable=True)

    white = relationship("User", foreign_keys=[white_id])
    black = relationship("User", foreign_keys=[black_id])
    moves = relationship("ChessMove", back_populates="game",
                         cascade="all, delete-orphan", order_by="ChessMove.ply")


class ChessMove(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "chess_moves"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    game_id = Column(GUID(), ForeignKey("chess_games.id", ondelete="CASCADE"),
                     nullable=False, index=True)
    ply = Column(Integer, nullable=False)     # half-move number (1-indexed)
    uci = Column(String(10), nullable=False)  # e.g. "e2e4", "e7e8q"
    san = Column(String(20), nullable=False)  # e.g. "e4", "Nf3", "O-O"
    fen_after = Column(Text, nullable=True)

    game = relationship("ChessGame", back_populates="moves")


class ChessChallenge(Base, TimestampMixin, TenantModelMixin):
    """A pending challenge from one member to another."""
    __tablename__ = "chess_challenges"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    challenger_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                           nullable=False, index=True)
    challenged_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                           nullable=False, index=True)
    time_control = Column(String(30), nullable=False, default="untimed")
    status = Column(String(20), nullable=False, default="pending")
    game_id = Column(GUID(), ForeignKey("chess_games.id", ondelete="SET NULL"), nullable=True)
    message = Column(String(200), nullable=True)

    challenger = relationship("User", foreign_keys=[challenger_id])
    challenged = relationship("User", foreign_keys=[challenged_id])
    game = relationship("ChessGame", foreign_keys=[game_id])


class ChessPlayerStats(Base, TimestampMixin, TenantModelMixin):
    """Materialised player stats — updated after each rated game."""
    __tablename__ = "chess_player_stats"

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     primary_key=True)

    # Glicko-2 fields
    glicko_rating = Column(Float, default=1500.0)
    glicko_rd = Column(Float, default=350.0)       # rating deviation
    glicko_vol = Column(Float, default=0.06)       # volatility

    games_played = Column(Integer, default=0)
    wins = Column(Integer, default=0)
    losses = Column(Integer, default=0)
    draws = Column(Integer, default=0)

    current_streak = Column(Integer, default=0)    # positive = win streak, negative = loss streak
    longest_win_streak = Column(Integer, default=0)

    user = relationship("User", foreign_keys=[user_id])
