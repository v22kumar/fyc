import uuid
from sqlalchemy import Column, String, Integer, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class WeeklyGame(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "weekly_games"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    title = Column(String(200), nullable=False)
    sport = Column(String(30), nullable=False)
    scheduled_at = Column(DateTime(timezone=True), nullable=False)
    venue = Column(String(200), nullable=True)
    status = Column(String(20), default="UPCOMING")  # UPCOMING, LIVE, COMPLETED, CANCELLED
    created_by_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Hook for live scoring using existing Fixture system
    fixture_id = Column(GUID(), ForeignKey("fixtures.id", ondelete="SET NULL"), nullable=True)
    
    players = relationship("WeeklyGamePlayer", back_populates="game", cascade="all, delete-orphan")
    created_by = relationship("User", foreign_keys=[created_by_id])
    fixture = relationship("Fixture")

class WeeklyGamePlayer(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "weekly_game_players"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    game_id = Column(GUID(), ForeignKey("weekly_games.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), default="JOINED")
    team_assigned = Column(String(20), nullable=True)  # "A" or "B" for grouping

    game = relationship("WeeklyGame", back_populates="players")
    user = relationship("User")
