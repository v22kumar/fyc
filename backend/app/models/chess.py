import uuid
from sqlalchemy import Column, String, Integer, Text, ForeignKey, DateTime, Float, Index, UniqueConstraint
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
    # Live-game/tenant listings filter (organization_id, status) and order by
    # started_at — a composite index keeps those off a full scan under load.
    __table_args__ = (
        Index("ix_chess_games_org_status", "organization_id", "status"),
    )

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

    # ── Durable clock ─────────────────────────────────────────────────────────
    # Remaining milliseconds per side, plus when the clock last changed hands.
    # Previously the clock lived ONLY in the in-memory GameSession, so any
    # redeploy handed both players a full clock back mid-game. Persisting it
    # here lets a restarted process resume the true times. Nullable: untimed
    # games leave these null, and the startup schema-reconcile can add them to
    # existing rows.
    white_time_ms = Column(Integer, nullable=True)
    black_time_ms = Column(Integer, nullable=True)
    last_move_at = Column(DateTime(timezone=True), nullable=True)

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
    # One row per half-move: (game_id, ply) is unique. This both indexes the hot
    # per-game ordered-move query AND makes a double-persist (e.g. a reconnect
    # race) a no-op conflict instead of a silent duplicate ply.
    __table_args__ = (
        UniqueConstraint("game_id", "ply", name="uq_chess_move_game_ply"),
    )

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


class ChessSeek(Base, TimestampMixin, TenantModelMixin):
    """An open offer to play — "anyone, at this time control".

    A ChessChallenge is directed: you must already know who you want to play.
    That is useless to a member who opens the app at 9pm and just wants a game,
    and it cannot be shared. A seek is the undirected form: it sits in a lobby
    until someone takes it, and its short code makes it a link you can send on
    WhatsApp. Whoever opens the link first gets the game.
    """
    __tablename__ = "chess_seeks"
    __table_args__ = (
        # The lobby query is (organization_id, status) ordered by recency.
        Index("ix_chess_seeks_org_status", "organization_id", "status"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    # Short, typeable code so a seek can be shared as a link (…/play/K7P2).
    short_code = Column(String(12), unique=True, index=True, nullable=True)
    creator_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                        nullable=False, index=True)
    time_control = Column(String(30), nullable=False, default="rapid_10_0")
    # open → matched | cancelled | expired
    status = Column(String(20), nullable=False, default="open")
    # Colour the CREATOR wants: white / black / random (resolved on match).
    preferred_color = Column(String(10), nullable=False, default="random")
    game_id = Column(GUID(), ForeignKey("chess_games.id", ondelete="SET NULL"),
                     nullable=True)
    accepted_by_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                            nullable=True)
    # A seek nobody takes should not sit in the lobby for ever.
    expires_at = Column(DateTime(timezone=True), nullable=True)

    creator = relationship("User", foreign_keys=[creator_id])
    accepted_by = relationship("User", foreign_keys=[accepted_by_id])
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
