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
    # Opt-in base location + preferences (all optional / privacy-first).
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_consent: bool = False
    notify_opt_in: bool = True

class BloodDonorAvailabilityUpdate(BaseModel):
    is_available: bool

class BloodDonorProfileUpdate(BaseModel):
    """Donor-editable fields for the 'my donor card' — all optional (patch)."""
    is_available: Optional[bool] = None
    last_donation_date: Optional[date] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_consent: Optional[bool] = None
    notify_opt_in: Optional[bool] = None

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
    # Age in years, not the date of birth: a hospital asks how old a donor is,
    # and a birth date is more of someone's identity than the question needs.
    age: Optional[int] = None
    # True for a directory contact imported from Friends2Support (vs a donor who
    # self-registered in the app). Drives the "Friends2Support" badge.
    is_imported: bool = False
    # 'fyc' = app user (in-app reachable, may be location-aware) vs 'imported'
    # (F2S contact — call only). Lets the UI show the two-tier distinction.
    tier: str = "fyc"
    # Donation eligibility (90-day cooldown).
    is_eligible: bool = True
    eligible_on: Optional[date] = None
    # Distance from the query point in km — only present on /nearby results.
    distance_km: Optional[float] = None
    # Whether this donor has an opt-in location on file (drives "on map" vs
    # "area only").
    has_location: bool = False
    # COARSE coordinates (~1 km grid) for the map view — only on /nearby, only
    # for donors who consented. Deliberately rounded so a home is never pinpointed.
    approx_latitude: Optional[float] = None
    approx_longitude: Optional[float] = None

class ContactRequestOut(BaseModel):
    message: str
    phone_number: str
    whatsapp_link: str
