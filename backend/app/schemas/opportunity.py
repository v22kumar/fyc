from pydantic import BaseModel, ConfigDict
from uuid import UUID
from typing import Optional
from app.models.opportunity import OpportunityType


class OpportunityCreate(BaseModel):
    type: OpportunityType
    title_ta: str
    title_en: str
    organizer_ta: Optional[str] = None
    organizer_en: Optional[str] = None
    hours: Optional[str] = None
    category_ta: Optional[str] = None
    category_en: Optional[str] = None
    location_ta: Optional[str] = None
    location_en: Optional[str] = None
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    is_active: bool = True


class OpportunityUpdate(BaseModel):
    title_ta: Optional[str] = None
    title_en: Optional[str] = None
    organizer_ta: Optional[str] = None
    organizer_en: Optional[str] = None
    hours: Optional[str] = None
    category_ta: Optional[str] = None
    category_en: Optional[str] = None
    location_ta: Optional[str] = None
    location_en: Optional[str] = None
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    is_active: Optional[bool] = None


class OpportunityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organization_id: UUID
    type: OpportunityType
    title_ta: str
    title_en: str
    organizer_ta: Optional[str]
    organizer_en: Optional[str]
    hours: Optional[str]
    category_ta: Optional[str]
    category_en: Optional[str]
    location_ta: Optional[str]
    location_en: Optional[str]
    description_ta: Optional[str]
    description_en: Optional[str]
    is_active: bool
