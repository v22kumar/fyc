import re
from datetime import date
from pydantic import BaseModel, ConfigDict, Field, field_validator
from uuid import UUID
from typing import Optional

# Pragmatic email check (email-validator / EmailStr isn't installed, and adding
# it is an unnecessary dependency for a single field). Good enough to reject
# obvious typos; real deliverability is verified out of band.
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

class OTPRequest(BaseModel):
    organization_id: UUID
    phone_number: str = Field(..., description="Phone number with country code, e.g. +919876543210")
    email: Optional[str] = Field(None, description="Optional email — OTP also sent here if provided")

class OTPResponse(BaseModel):
    message: str
    verification_id: str
    channel: Optional[str] = None

class OTPVerify(BaseModel):
    verification_id: str
    otp_code: str = Field(..., min_length=6, max_length=6)

class OTPVerifySuccess(BaseModel):
    message: str
    registration_token: str
    phone_number: str

class UserRegister(BaseModel):
    organization_id: UUID
    phone_number: str
    registration_token: Optional[str] = Field(None, description="JWT token proving the phone number was verified via OTP")
    email: Optional[str] = Field(None, description="Optional — member contact email")
    date_of_birth: Optional[date] = None
    gender: Optional[str] = Field(None, pattern="^(MALE|FEMALE|OTHER)$")
    blood_group: Optional[str] = None
    role: str = Field("PUBLIC_CITIZEN", pattern="^(PUBLIC_CITIZEN|VOLUNTEER|CLUB_MEMBER)$")
    full_name_en: Optional[str] = None
    full_name_ta: Optional[str] = None
    preferred_language: Optional[str] = "ta"

    @field_validator("email")
    @classmethod
    def _email_valid(cls, v: Optional[str]) -> Optional[str]:
        if v is None: return None
        v = v.strip().lower()
        if not v: return None
        if not _EMAIL_RE.match(v): raise ValueError("Enter a valid email address")
        return v

    @field_validator("full_name_en")
    @classmethod
    def _name_required(cls, v: Optional[str]) -> Optional[str]:
        if v is None: return None
        return v.strip() or None

    @field_validator("full_name_ta")
    @classmethod
    def _name_ta_clean(cls, v: Optional[str]) -> Optional[str]:
        if v is None: return None
        return v.strip() or None

    @field_validator("date_of_birth")
    @classmethod
    def _dob_sane(cls, v: Optional[date]) -> Optional[date]:
        if v is None: return None
        today = date.today()
        age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
        if v > today: raise ValueError("Date of birth cannot be in the future")
        if age > 120: raise ValueError("Enter a valid date of birth")
        return v

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    phone_number: Optional[str] = None
    email: Optional[str] = None
    role: str
    is_verified: bool
    is_blocked: bool = False
    preferred_language: str
    full_name_en: Optional[str] = None
    full_name_ta: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None
    blood_group: Optional[str] = None
    is_profile_complete: bool = False

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserOut
    refresh_token: Optional[str] = None

class RefreshRequest(BaseModel):
    refresh_token: str

class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    role: Optional[str] = None
    organization_id: Optional[str] = None

class AdminLogin(BaseModel):
    organization_id: UUID
    username: str = Field(..., description="Phone number or email")
    password: str

class GoogleLoginRequest(BaseModel):
    organization_id: UUID
    id_token: str
    # Claim only: never use this value to find or authenticate an account.
    phone_number: Optional[str] = Field(None, description="Phone typed before Google authentication")

def _build_user_out(user, profile=None):
    is_complete = bool(profile and (profile.full_name_en or profile.full_name_ta) and profile.date_of_birth and profile.gender and user.phone_number)
    return UserOut(
        id=user.id, phone_number=user.phone_number, email=user.email,
        role=user.role, is_verified=user.is_verified,
        is_blocked=getattr(user, 'is_blocked', False),
        preferred_language=user.preferred_language,
        full_name_en=profile.full_name_en if profile else None,
        full_name_ta=profile.full_name_ta if profile else None,
        date_of_birth=profile.date_of_birth if profile else None,
        gender=profile.gender if profile else None,
        blood_group=profile.blood_group if profile else None,
        is_profile_complete=is_complete,
    )
