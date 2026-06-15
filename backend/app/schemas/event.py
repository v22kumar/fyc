from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List

class EventCreate(BaseModel):
    title_ta: str
    title_en: str
    description_ta: str
    description_en: str
    event_start: datetime
    event_end: datetime
    banner_url: Optional[str] = None
    geography_id: Optional[UUID] = None

class EventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title_ta: str
    title_en: str
    description_ta: str
    description_en: str
    event_start: datetime
    event_end: datetime
    banner_url: Optional[str]
    geography_id: Optional[UUID]
    created_by_user_id: Optional[UUID]
    created_at: datetime

class EventCheckinOut(BaseModel):
    message: str
    event_id: UUID
    user_id: UUID
    checked_in_at: datetime
