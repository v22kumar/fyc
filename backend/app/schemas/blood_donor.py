from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import date
from typing import Optional

VALID_BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

class BloodDonorRegister(BaseModel):
    blood_group: str = Field(..., description="Must be one of A+, A-, B+, B-, AB+, AB-, O+, O-")
    geography_id: Optional[UUID] = None
    is_available: bool = True
    last_donation_date: Optional[date] = None

class BloodDonorAvailabilityUpdate(BaseModel):
    is_available: bool

class BloodDonorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    blood_group: str
    is_available: bool
    last_donation_date: Optional[date]
    geography_id: Optional[UUID]
    full_name_en: Optional[str] = None
    full_name_ta: Optional[str] = None

class BloodDonorPublicOut(BaseModel):
    """Public view — no contact details exposed."""
    id: UUID
    blood_group: str
    is_available: bool
    geography_id: Optional[UUID]
    geography_name_en: Optional[str] = None
    geography_name_ta: Optional[str] = None
    full_name_en: Optional[str] = None
    full_name_ta: Optional[str] = None
    # True for a directory contact imported from Friends2Support (vs a donor who
    # self-registered in the app). Drives the "Friends2Support" badge.
    is_imported: bool = False

class ContactRequestOut(BaseModel):
    message: str
    phone_number: str
    whatsapp_link: str
