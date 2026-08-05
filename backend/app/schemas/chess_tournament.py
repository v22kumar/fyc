from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class ChessTournamentCreate(BaseModel):
    name: str
    description: Optional[str] = None
    registration_deadline: Optional[datetime] = None
    # Clock for every match in the event. Defaults to 10 minutes per player
    # (sudden death) — a sane default for a multi-round one-day knockout.
    time_control: str = "rapid_10_0"


class TournamentSettingsIn(BaseModel):
    """Organizer-editable tournament settings."""
    time_control: str


class PlayerRef(BaseModel):
    id: UUID
    name: str


class EntryOut(BaseModel):
    """A registered player and their approval status."""
    id: UUID  # the player's user id
    name: str
    status: str  # PENDING / APPROVED / REJECTED


class ChessTournamentOut(BaseModel):
    id: UUID
    short_code: Optional[str] = None
    name: str
    description: Optional[str]
    status: str
    registration_deadline: Optional[datetime]
    time_control: str  # clock applied to every match in this tournament
    entry_count: int  # approved players (the ones who will play)
    pending_count: int  # registrations awaiting a manager decision
    current_round: int
    is_registered: bool
    my_status: Optional[str]  # PENDING / APPROVED / REJECTED for the caller
    champion: Optional[PlayerRef]
    created_at: datetime


class MatchOut(BaseModel):
    id: UUID
    round: int
    slot: int
    player_a: Optional[PlayerRef]
    player_b: Optional[PlayerRef]
    winner_id: Optional[UUID]
    game_id: Optional[UUID]
    status: str
    # APP = played online in the Arena; PHYSICAL = played in person, organizer
    # records the result. Defaults to APP.
    conduct_mode: str = "APP"
    activated: bool = False
    a_ready: bool = False
    b_ready: bool = False
    venue: Optional[str] = None
    reporting_time: Optional[datetime] = None


class ChessTournamentDetailOut(ChessTournamentOut):
    entries: List[EntryOut]
    rounds: int
    matches: List[MatchOut]


class ReportResultIn(BaseModel):
    winner_id: UUID


class RegistrationDecisionIn(BaseModel):
    approve: bool


class ConductModeIn(BaseModel):
    mode: str  # 'APP' or 'PHYSICAL'
    venue: Optional[str] = None
    reporting_time: Optional[datetime] = None
