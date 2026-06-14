from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from typing import Optional
from app.models.issue import IssueCategory, IssueStatus

class IssueCreate(BaseModel):
    category: IssueCategory
    description_ta: str
    description_en: str
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    geography_id: Optional[UUID] = None
    photo_url: str = Field(..., description="URL of uploaded photo (presigned S3 or local path)")

class IssueStatusUpdate(BaseModel):
    status: IssueStatus
    assigned_volunteer_id: Optional[UUID] = None
    verification_photo_url: Optional[str] = None

class IssueOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    category: IssueCategory
    description_ta: str
    description_en: str
    latitude: float
    longitude: float
    geography_id: Optional[UUID]
    photo_url: str
    verification_photo_url: Optional[str]
    status: IssueStatus
    assigned_volunteer_id: Optional[UUID]
    reported_by_user_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime
