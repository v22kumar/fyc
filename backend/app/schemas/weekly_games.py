from pydantic import BaseModel, ConfigDict
import uuid
from typing import Optional, List
from datetime import datetime

class WeeklyGamePlayerOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    user_name: str
    status: str
    team_assigned: Optional[str] = None
    
    model_config = ConfigDict(from_attributes=True)

class WeeklyGameCreate(BaseModel):
    title: str
    sport: str
    scheduled_at: datetime
    venue: Optional[str] = None


class WeeklyGameUpdate(BaseModel):
    title: Optional[str] = None
    sport: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    venue: Optional[str] = None

class WeeklyGameOut(BaseModel):
    id: uuid.UUID
    title: str
    sport: str
    scheduled_at: datetime
    venue: Optional[str] = None
    status: str
    created_by_id: Optional[uuid.UUID] = None
    fixture_id: Optional[uuid.UUID] = None
    players: List[WeeklyGamePlayerOut] = []
    
    model_config = ConfigDict(from_attributes=True)
