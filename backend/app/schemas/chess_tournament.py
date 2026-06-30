from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class ChessTournamentCreate(BaseModel):
    name: str
    description: Optional[str] = None
    registration_deadline: Optional[datetime] = None


class PlayerRef(BaseModel):
    id: UUID
    name: str


class ChessTournamentOut(BaseModel):
    id: UUID
    name: str
    description: Optional[str]
    status: str
    registration_deadline: Optional[datetime]
    entry_count: int
    is_registered: bool
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


class ChessTournamentDetailOut(ChessTournamentOut):
    entries: List[PlayerRef]
    rounds: int
    matches: List[MatchOut]


class ReportResultIn(BaseModel):
    winner_id: UUID
