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
    # Which channel actually carried the code: sms | whatsapp | email | log.
    # The app tells the member where to look, because "check WhatsApp" and
    # "check your messages" send them to different places and being pointed at
    # the wrong one is indistinguishable from nothing arriving.
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
    # Required in production (enforced in the endpoint); optional at the schema
    # level so the test suite (settings.TESTING) can register without an OTP round-trip.
    registration_token: Optional[str] = Field(None, description="JWT token proving the phone number was verified via OTP")
    # Email is now OPTIONAL — many OTP members don't have one; Google prefills it
    # when present. A single 'full_name' is enough (the app stores it to both the
    # Tamil and English name columns), so full_name_ta is optional and defaults to
    # the English name server-side.
    email: Optional[str] = Field(None, description="Optional — member contact email")
    # Nothing here is required any more except a verified phone number.
    #
    # This used to demand a date of birth, a name and a role before an account
    # could exist, which put a form between a member and the app on the day
    # they installed it — and then the completeness gate asked for most of it a
    # second time. Everything optional below is now collected afterwards, a
    # question at a time, by the profile-prompt system that already exists.
    date_of_birth: Optional[date] = Field(
        None, description="Optional — asked later as a profile prompt"
    )
    # Optional at the API for backward compatibility, but the app now collects it
    # at signup and sends it here so the user isn't bounced to a second "complete
    # profile" screen just to pick a gender. When absent, the completeness gate
    # still asks for it later (old behaviour) — so this is non-breaking.
    gender: Optional[str] = Field(None, pattern="^(MALE|FEMALE|OTHER)$", description="MALE/FEMALE/OTHER")
    blood_group: Optional[str] = Field(None, description="Optional blood group")
    role: str = Field(
        "PUBLIC_CITIZEN", pattern="^(PUBLIC_CITIZEN|VOLUNTEER|CLUB_MEMBER)$"
    )
    full_name_en: Optional[str] = None
    full_name_ta: Optional[str] = None
    preferred_language: Optional[str] = "ta"

    @field_validator("email")
    @classmethod
    def _email_valid(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip().lower()
        if not v:
            return None
        if not _EMAIL_RE.match(v):
            raise ValueError("Enter a valid email address")
        return v

    @field_validator("full_name_en")
    @classmethod
    def _name_required(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Name is required")
        return v.strip()

    @field_validator("full_name_ta")
    @classmethod
    def _name_ta_clean(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip()
        return v or None

    @field_validator("date_of_birth")
    @classmethod
    def _dob_sane(cls, v: date) -> date:
        today = date.today()
        age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
        if v > today:
            raise ValueError("Date of birth cannot be in the future")
        if age > 120:
            raise ValueError("Enter a valid date of birth")
        return v


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    phone_number: Optional[str] = None   # nullable — Google-only users have no phone
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
    is_profile_complete: bool = False     # True when name + DOB + gender all set


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


def _build_user_out(user, profile=None):
    """Build UserOut from User + optional UserProfile."""
    # A profile is "complete" only when we have the full mandatory set: name,
    # date of birth, gender AND a phone number. Google-only accounts (no phone)
    # therefore stay incomplete until they add one, so the onboarding gate keeps
    # asking — no dataless users slip into the database.
    is_complete = bool(
        profile
        and (profile.full_name_en or profile.full_name_ta)
        and profile.date_of_birth
        and profile.gender
        and user.phone_number
    )
    return UserOut(
        id=user.id,
        phone_number=user.phone_number,
        email=user.email,
        role=user.role,
        is_verified=user.is_verified,
        is_blocked=getattr(user, 'is_blocked', False),
        preferred_language=user.preferred_language,
        full_name_en=profile.full_name_en if profile else None,
        full_name_ta=profile.full_name_ta if profile else None,
        date_of_birth=profile.date_of_birth if profile else None,
        gender=profile.gender if profile else None,
        blood_group=profile.blood_group if profile else None,
        is_profile_complete=is_complete,
    )
