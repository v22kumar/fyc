from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional


class PhotoCreate(BaseModel):
    photo_url: str
    caption_ta: Optional[str] = None
    caption_en: Optional[str] = None
    taken_at: Optional[datetime] = None


class PhotoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    event_id: UUID
    uploaded_by_user_id: Optional[UUID]
    photo_url: str
    caption_ta: Optional[str]
    caption_en: Optional[str]
    taken_at: Optional[datetime]
    organization_id: UUID
    created_at: datetime
    updated_at: datetime
