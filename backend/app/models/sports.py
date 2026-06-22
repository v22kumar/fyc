import uuid
from sqlalchemy import Column, String, Boolean, Integer, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

SPORT_TYPES = ["cricket", "kabaddi", "volleyball", "football", "carrom", "chess", "other"]
TOURNAMENT_FORMATS = ["LEAGUE", "ROUND_ROBIN", "DOUBLE_ROUND", "KNOCKOUT", "GROUP_STAGE", "CUSTOM"]
TOURNAMENT_STATUSES = ["UPCOMING", "ONGOING", "COMPLETED"]
FIXTURE_STATUSES = ["SCHEDULED", "LIVE", "COMPLETED", "CANCELLED"]
CHALLENGE_STATUSES = ["OPEN", "ACCEPTED", "REJECTED", "COMPLETED"]
REGISTRATION_MODES = ["MANUAL_APPROVAL", "OPEN"]
LIVE_ENTRY_STATUSES = ["PENDING", "APPROVED", "REJECTED"]


class Tournament(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "tournaments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    name_ta = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=False)
    sport = Column(String(30), nullable=False)
    year = Column(Integer, nullable=False)
    format = Column(String(20), default="LEAGUE")
    status = Column(String(20), default="UPCOMING")
    description_ta = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)
    created_by_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    # Rich configuration (from the create-tournament form)
    num_teams = Column(Integer, nullable=True)
    match_config = Column(String(60), nullable=True)        # e.g. "20 Overs", "Best of 5 sets"
    registration_mode = Column(String(20), default="MANUAL_APPROVAL")
    start_date = Column(DateTime(timezone=True), nullable=True)
    end_date = Column(DateTime(timezone=True), nullable=True)
    venue = Column(String(200), nullable=True)
    show_points_table = Column(Boolean, default=True)
    show_live_scores = Column(Boolean, default=True)
    show_prize_details = Column(Boolean, default=False)
    prize_details = Column(Text, nullable=True)

    teams = relationship("Team", back_populates="tournament", cascade="all, delete-orphan")
    fixtures = relationship("Fixture", back_populates="tournament", cascade="all, delete-orphan")
    created_by = relationship("User", foreign_keys=[created_by_id])


class Team(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "teams"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    tournament_id = Column(GUID(), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    captain_name = Column(String(100), nullable=True)
    contact_phone = Column(String(15), nullable=True)
    wins = Column(Integer, default=0)
    losses = Column(Integer, default=0)
    draws = Column(Integer, default=0)
    points = Column(Integer, default=0)
    is_fyc_team = Column(Boolean, default=False)

    tournament = relationship("Tournament", back_populates="teams")


class Fixture(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "fixtures"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    tournament_id = Column(GUID(), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False)
    team_a_id = Column(GUID(), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    team_b_id = Column(GUID(), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    match_number = Column(Integer, nullable=True)
    scheduled_at = Column(DateTime(timezone=True), nullable=True)
    venue = Column(String(200), nullable=True)
    status = Column(String(20), default="SCHEDULED")
    # Result (filled after match)
    team_a_score = Column(String(50), nullable=True)
    team_b_score = Column(String(50), nullable=True)
    winner_id = Column(GUID(), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    result_notes = Column(String(300), nullable=True)

    tournament = relationship("Tournament", back_populates="fixtures")
    team_a = relationship("Team", foreign_keys=[team_a_id])
    team_b = relationship("Team", foreign_keys=[team_b_id])
    winner = relationship("Team", foreign_keys=[winner_id])


class LiveScoreEntry(Base, TimestampMixin, TenantModelMixin):
    """
    A score update submitted by a CLUB_MEMBER during/after a match.
    Stays PENDING until an admin/executive approves it; on approval the
    scores are applied to the parent fixture and team standings update.
    """
    __tablename__ = "live_score_entries"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    fixture_id = Column(GUID(), ForeignKey("fixtures.id", ondelete="CASCADE"), nullable=False)
    tournament_id = Column(GUID(), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False)
    submitted_by_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    team_a_score = Column(String(50), nullable=True)
    team_b_score = Column(String(50), nullable=True)
    winner_id = Column(GUID(), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    notes = Column(String(300), nullable=True)
    status = Column(String(20), default="PENDING")
    reviewed_by_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    review_notes = Column(String(300), nullable=True)

    fixture = relationship("Fixture", foreign_keys=[fixture_id])
    submitted_by = relationship("User", foreign_keys=[submitted_by_id])
    reviewed_by = relationship("User", foreign_keys=[reviewed_by_id])


class ChallengeMatch(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "challenge_matches"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    challenger_team_name = Column(String(100), nullable=False)
    challenger_captain = Column(String(100), nullable=False)
    challenger_phone = Column(String(15), nullable=False)
    sport = Column(String(30), nullable=False)
    proposed_date = Column(DateTime(timezone=True), nullable=True)
    venue = Column(String(200), nullable=True)
    message = Column(Text, nullable=True)
    status = Column(String(20), default="OPEN")
    admin_response = Column(String(300), nullable=True)
