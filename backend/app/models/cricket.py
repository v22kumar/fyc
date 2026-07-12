import uuid
from sqlalchemy import Column, String, Integer, ForeignKey, Boolean, JSON
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class CricketMatch(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "cricket_matches"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    fixture_id = Column(GUID(), ForeignKey("fixtures.id", ondelete="CASCADE"), nullable=False, unique=True)
    toss_winner_id = Column(GUID(), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    toss_decision = Column(String(20), nullable=True) # "BAT" or "BOWL"
    status = Column(String(20), default="NOT_STARTED") # NOT_STARTED, FIRST_INNINGS, INNINGS_BREAK, SECOND_INNINGS, COMPLETED
    overs_per_innings = Column(Integer, default=20)
    # Village house-rule: when true, the first two wides in each over carry no
    # penalty run (but are still re-bowled). The 3rd+ wide reverts to a normal
    # wide. Counter resets every over. See recalculate_match_state.
    village_wides = Column(Boolean, default=False, nullable=False)
    scorer_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    edit_history = Column(JSON, nullable=True)
    notes = Column(String(500), nullable=True)

    # We will store the full calculated real-time state as JSON for ultra-fast reads.
    # Every time a ball is scored, we rebuild this JSON.
    match_state = Column(JSON, nullable=True)

    fixture = relationship("Fixture")
    toss_winner = relationship("Team", foreign_keys=[toss_winner_id])
    scorer = relationship("User")


    # Using central Player model from sports.py
    # CricketPlayer is removed


class CricketBall(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "cricket_balls"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    match_id = Column(GUID(), ForeignKey("cricket_matches.id", ondelete="CASCADE"), nullable=False)
    innings_number = Column(Integer, nullable=False) # 1 or 2
    
    # Audit trail ordering
    ball_index = Column(Integer, nullable=False) # absolute index in innings (1, 2, 3...)
    
    # Players
    striker_id = Column(GUID(), ForeignKey("players.id", ondelete="CASCADE"), nullable=False)
    non_striker_id = Column(GUID(), ForeignKey("players.id", ondelete="CASCADE"), nullable=False)
    bowler_id = Column(GUID(), ForeignKey("players.id", ondelete="CASCADE"), nullable=False)
    
    # Runs
    runs_batter = Column(Integer, default=0)
    extras_type = Column(String(20), nullable=True) # WIDE, NO_BALL, BYE, LEG_BYE
    extras_runs = Column(Integer, default=0)
    
    # Wicket
    is_wicket = Column(Boolean, default=False)
    wicket_type = Column(String(50), nullable=True) # BOWLED, CAUGHT, RUN_OUT, etc.
    player_dismissed_id = Column(GUID(), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    
    # Audit
    scorer_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    edit_history = Column(JSON, nullable=True)
    notes = Column(String(500), nullable=True)
    
    match = relationship("CricketMatch")
    striker = relationship("Player", foreign_keys=[striker_id])
    non_striker = relationship("Player", foreign_keys=[non_striker_id])
    bowler = relationship("Player", foreign_keys=[bowler_id])
    player_dismissed = relationship("Player", foreign_keys=[player_dismissed_id])
