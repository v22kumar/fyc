from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Any

class EventCreate(BaseModel):
    title_ta: str
    title_en: str
    description_ta: str
    description_en: str
    event_start: datetime
    event_end: datetime
    banner_url: Optional[str] = None
    geography_id: Optional[UUID] = None
    is_published: Optional[bool] = False
    requires_registration: Optional[bool] = True
    registration_deadline: Optional[datetime] = None
    max_participants: Optional[int] = None
    competition_categories: Optional[List[str]] = None

class EventUpdate(BaseModel):
    title_ta: Optional[str] = None
    title_en: Optional[str] = None
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    event_start: Optional[datetime] = None
    event_end: Optional[datetime] = None
    banner_url: Optional[str] = None
    geography_id: Optional[UUID] = None
    is_published: Optional[bool] = None
    requires_registration: Optional[bool] = None
    registration_deadline: Optional[datetime] = None
    max_participants: Optional[int] = None
    competition_categories: Optional[List[str]] = None

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
    is_published: Optional[bool]
    requires_registration: Optional[bool]
    registration_deadline: Optional[datetime]
    max_participants: Optional[int]
    competition_categories: Optional[Any]
    registration_count: int = 0  # number of registrations ("N Going")

class EventCheckinOut(BaseModel):
    message: str
    event_id: UUID
    user_id: UUID
    checked_in_at: datetime

class EventCheckoutOut(BaseModel):
    checked_out_at: datetime
    hours_accrued: float

class EventRegistrationCreate(BaseModel):
    name: str
    age: int
    gender: str
    mobile_number: str
    email: Optional[str] = None
    address: Optional[str] = None
    school_college: Optional[str] = None
    competition_category: List[str]
    class_grade: Optional[str] = None
    remarks: Optional[str] = None

class EventRegistrationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    event_id: UUID
    user_id: Optional[UUID]
    name: str
    age: int
    gender: str
    mobile_number: str
    email: Optional[str]
    address: Optional[str]
    school_college: Optional[str]
    competition_category: Any
    class_grade: Optional[str]
    remarks: Optional[str]
    created_at: datetime
