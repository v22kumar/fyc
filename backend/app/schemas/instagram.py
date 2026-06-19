from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from typing import Optional


class InstagramPostCreate(BaseModel):
    image_url: str
    caption: str = Field(default="", max_length=2200)


class InstagramPostOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organization_id: UUID
    created_by_user_id: Optional[UUID]
    image_url: str
    caption: str
    status: str
    instagram_media_id: Optional[str]
    reviewed_by_user_id: Optional[UUID]
    reviewed_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
