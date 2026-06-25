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
    photo_url: Optional[str] = None
    is_emergency: bool = False

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
    photo_url: Optional[str]
    verification_photo_url: Optional[str]
    is_emergency: Optional[bool] = False
    status: IssueStatus
    assigned_volunteer_id: Optional[UUID]
    reported_by_user_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime

class IssueStats(BaseModel):
    total: int
    resolved: int
    resolution_rate: int        # percentage 0–100
    avg_response_days: float
    active_citizens: int

class IssueEmailCreate(BaseModel):
    authority_email: str
    subject: str
    body: str

class IssueEmailOut(BaseModel):
    id: UUID
    issue_id: UUID
    sent_by_user_id: Optional[UUID]
    authority_email: str
    subject: str
    body: str
    created_at: datetime
    
    class Config:
        from_attributes = True
