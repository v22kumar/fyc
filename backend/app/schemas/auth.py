from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from typing import Optional

class OTPRequest(BaseModel):
    organization_id: UUID
    phone_number: str = Field(..., description="Phone number with country code, e.g. +919876543210")
    email: Optional[str] = Field(None, description="Optional email — OTP also sent here if provided")

class OTPResponse(BaseModel):
    message: str
    verification_id: str

class OTPVerify(BaseModel):
    verification_id: str
    otp_code: str = Field(..., min_length=6, max_length=6)

class UserRegister(BaseModel):
    organization_id: UUID
    phone_number: str
    role: str = Field(..., pattern="^(PUBLIC_CITIZEN|VOLUNTEER)$")
    full_name_ta: str
    full_name_en: str
    preferred_language: Optional[str] = "ta"

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    phone_number: str
    role: str
    is_verified: bool
    preferred_language: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserOut

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    role: Optional[str] = None
    organization_id: Optional[str] = None

class AdminLogin(BaseModel):
    organization_id: UUID
    username: str = Field(..., description="Phone number or email")
    password: str

