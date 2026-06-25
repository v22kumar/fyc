from typing import Optional, List
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel


class TournamentCreate(BaseModel):
    name_ta: str
    name_en: str
    sport: str
    year: int
    format: str = "LEAGUE"
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    # Rich config
    num_teams: Optional[int] = None
    match_config: Optional[str] = None
    registration_mode: str = "MANUAL_APPROVAL"
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    venue: Optional[str] = None
    show_points_table: bool = True
    show_live_scores: bool = True
    show_prize_details: bool = False
    prize_details: Optional[str] = None


class TournamentOut(BaseModel):
    id: UUID
    name_ta: str
    name_en: str
    sport: str
    year: int
    format: str
    status: str
    description_ta: Optional[str]
    description_en: Optional[str]
    num_teams: Optional[int] = None
    match_config: Optional[str] = None
    registration_mode: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    venue: Optional[str] = None
    show_points_table: Optional[bool] = True
    show_live_scores: Optional[bool] = True
    show_prize_details: Optional[bool] = False
    prize_details: Optional[str] = None

    class Config:
        from_attributes = True


class TeamCreate(BaseModel):
    name: str
    captain_name: Optional[str] = None
    contact_phone: Optional[str] = None
    is_fyc_team: bool = False


class TeamOut(BaseModel):
    id: UUID
    tournament_id: UUID
    name: str
    captain_name: Optional[str]
    contact_phone: Optional[str]
    wins: int
    losses: int
    draws: int
    points: int
    is_fyc_team: bool
    status: str

    class Config:
        from_attributes = True


class TeamStatusUpdate(BaseModel):
    status: str  # PENDING, APPROVED, REJECTED


class FixtureCreate(BaseModel):
    team_a_id: UUID
    team_b_id: UUID
    match_number: Optional[int] = None
    scheduled_at: Optional[datetime] = None
    venue: Optional[str] = None


class FixtureResultUpdate(BaseModel):
    team_a_score: Optional[str] = None
    team_b_score: Optional[str] = None
    winner_id: Optional[UUID] = None
    result_notes: Optional[str] = None


class FixtureOut(BaseModel):
    id: UUID
    tournament_id: UUID
    team_a_id: UUID
    team_b_id: UUID
    team_a_name: Optional[str] = None
    team_b_name: Optional[str] = None
    match_number: Optional[int]
    scheduled_at: Optional[datetime]
    venue: Optional[str]
    status: str
    team_a_score: Optional[str]
    team_b_score: Optional[str]
    winner_id: Optional[UUID]
    result_notes: Optional[str]

    class Config:
        from_attributes = True


class ChallengeCreate(BaseModel):
    challenger_team_name: str
    challenger_captain: str
    challenger_phone: str
    sport: str
    proposed_date: Optional[datetime] = None
    venue: Optional[str] = None
    message: Optional[str] = None


class ChallengeOut(BaseModel):
    id: UUID
    challenger_team_name: str
    challenger_captain: str
    challenger_phone: str
    sport: str
    proposed_date: Optional[datetime]
    venue: Optional[str]
    message: Optional[str]
    status: str
    admin_response: Optional[str]

    class Config:
        from_attributes = True


class ChallengeStatusUpdate(BaseModel):
    status: str  # ACCEPTED, REJECTED, COMPLETED
    admin_response: Optional[str] = None


# ── Live Score Entry (club-member submission → admin approval) ─────────────────

class LiveScoreEntryCreate(BaseModel):
    team_a_score: Optional[str] = None
    team_b_score: Optional[str] = None
    winner_id: Optional[UUID] = None
    notes: Optional[str] = None


class LiveScoreReview(BaseModel):
    status: str  # APPROVED or REJECTED
    review_notes: Optional[str] = None


class LiveScoreEntryOut(BaseModel):
    id: UUID
    fixture_id: UUID
    tournament_id: UUID
    submitted_by_id: Optional[UUID]
    submitted_by_name: Optional[str] = None
    team_a_name: Optional[str] = None
    team_b_name: Optional[str] = None
    team_a_score: Optional[str]
    team_b_score: Optional[str]
    winner_id: Optional[UUID]
    notes: Optional[str]
    status: str
    review_notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
