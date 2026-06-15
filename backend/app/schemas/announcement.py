from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional
from app.models.announcement import AnnouncementCategory


class AnnouncementCreate(BaseModel):
    title_ta: str
    title_en: str
    body_ta: str
    body_en: str
    category: AnnouncementCategory
    is_pinned: bool = False
    expires_at: Optional[datetime] = None
    banner_url: Optional[str] = None
    geography_id: Optional[UUID] = None


class AnnouncementUpdate(BaseModel):
    title_ta: Optional[str] = None
    title_en: Optional[str] = None
    body_ta: Optional[str] = None
    body_en: Optional[str] = None
    category: Optional[AnnouncementCategory] = None
    is_pinned: Optional[bool] = None
    expires_at: Optional[datetime] = None
    banner_url: Optional[str] = None
    geography_id: Optional[UUID] = None


class AnnouncementOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title_ta: str
    title_en: str
    body_ta: str
    body_en: str
    category: AnnouncementCategory
    is_pinned: bool
    expires_at: Optional[datetime]
    banner_url: Optional[str]
    created_by_user_id: Optional[UUID]
    geography_id: Optional[UUID]
    organization_id: UUID
    created_at: datetime
    updated_at: datetime
