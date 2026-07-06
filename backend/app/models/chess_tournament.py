import uuid

from sqlalchemy import (
    Column,
    String,
    Text,
    ForeignKey,
    Integer,
    Boolean,
    DateTime,
    UniqueConstraint,
)

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class ChessTournament(Base, TimestampMixin, TenantModelMixin):
    """A single-elimination chess tournament played in the FYC Chess Arena."""

    __tablename__ = "chess_tournaments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    # REGISTRATION_OPEN → REGISTRATION_CLOSED → IN_PROGRESS → COMPLETED
    status = Column(String(20), nullable=False, default="REGISTRATION_OPEN")
    registration_deadline = Column(DateTime(timezone=True), nullable=True)
    # Highest round the manager has activated ("Start Next Round"). 0 until the
    # tournament starts, 1 once round 1 is live, etc. Nullable so the startup
    # schema-reconcile can add it to existing rows; treated as 0 when null.
    current_round = Column(Integer, default=0)
    created_by_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    champion_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )


class ChessTournamentEntry(Base, TimestampMixin, TenantModelMixin):
    """A player registered for a chess tournament."""

    __tablename__ = "chess_tournament_entries"
    __table_args__ = (
        UniqueConstraint("tournament_id", "user_id", name="uq_chess_entry"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    tournament_id = Column(
        GUID(),
        ForeignKey("chess_tournaments.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # PENDING (awaiting manager decision) / APPROVED / REJECTED. Nullable so the
    # startup schema-reconcile can add it to legacy rows; a null status is
    # treated as APPROVED so pre-existing entries are never stranded.
    status = Column(String(20), default="PENDING")


class ChessTournamentMatch(Base, TimestampMixin, TenantModelMixin):
    """One bracket slot. round=1 is the first round; slot is 0-indexed."""

    __tablename__ = "chess_tournament_matches"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    tournament_id = Column(
        GUID(),
        ForeignKey("chess_tournaments.id", ondelete="CASCADE"),
        nullable=False,
    )
    round = Column(Integer, nullable=False)
    slot = Column(Integer, nullable=False)
    player_a_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    player_b_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    game_id = Column(
        GUID(), ForeignKey("chess_games.id", ondelete="SET NULL"), nullable=True
    )
    winner_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # PENDING (waiting for players / round not started) / READY (both set and
    # round activated) / LIVE / DONE / BYE
    status = Column(String(20), nullable=False, default="PENDING")
    # APP = played online in the Arena; PHYSICAL = played in person and an admin
    # records the result. Organizers switch this for semi-final / final matches.
    # Nullable so the startup schema-reconcile can add it to existing rows;
    # treated as "APP" when null.
    conduct_mode = Column(String(10), default="APP")
    # Round activation: a match only becomes playable once the manager starts its
    # round ("Start Next Round"). Round 1 is activated when the tournament starts.
    activated = Column(Boolean, default=False)
    # Per-player "Ready" acknowledgement before an online match can begin. Both
    # players must be ready to open the board. Nullable → treated as False.
    a_ready = Column(Boolean, default=False)
    b_ready = Column(Boolean, default=False)
    # Physical-match logistics (venue + reporting time) shown to both players.
    venue = Column(String(200), nullable=True)
    reporting_time = Column(DateTime(timezone=True), nullable=True)
    # When the winner was recorded (auto on Arena finish, or manager override).
    completed_at = Column(DateTime(timezone=True), nullable=True)
