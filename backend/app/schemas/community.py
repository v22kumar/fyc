from typing import Optional
from uuid import UUID
from pydantic import BaseModel


class CommunityProfileRegister(BaseModel):
    category: str
    business_name_ta: Optional[str] = None
    business_name_en: Optional[str] = None
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_whatsapp: Optional[str] = None
    service_area: Optional[str] = None
    years_experience: Optional[int] = None


class CommunityProfileUpdate(BaseModel):
    category: Optional[str] = None
    business_name_ta: Optional[str] = None
    business_name_en: Optional[str] = None
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_whatsapp: Optional[str] = None
    service_area: Optional[str] = None
    years_experience: Optional[int] = None
    is_available: Optional[bool] = None


class CommunityProfileOut(BaseModel):
    id: UUID
    user_id: UUID
    category: str
    business_name_ta: Optional[str]
    business_name_en: Optional[str]
    description_ta: Optional[str]
    description_en: Optional[str]
    contact_phone: Optional[str]
    contact_whatsapp: Optional[str]
    service_area: Optional[str]
    years_experience: Optional[int]
    is_available: bool
    is_verified: bool
    full_name_en: Optional[str] = None
    full_name_ta: Optional[str] = None

    class Config:
        from_attributes = True

class CommunityFeedItem(BaseModel):
    item_type: str  # "NEWS", "EVENT", "TOURNAMENT", "ISSUE", "ANNOUNCEMENT"
    id: str
    title_en: Optional[str] = None
    title_ta: Optional[str] = None
    subtitle_en: Optional[str] = None
    subtitle_ta: Optional[str] = None
    image_url: Optional[str] = None
    created_at: str
    metadata: Optional[dict] = None

class CommunityStatsOut(BaseModel):
    total_volunteers: int
    total_events: int
    total_blood_donations: int
    total_trees_planted: int
    total_issues_solved: int
