from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional

class OTPRequest(BaseModel):
    organization_id: UUID
    phone_number: str = Field(..., description="Phone number with country code")

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
    id: UUID
    phone_number: str
    role: str
    is_verified: bool
    preferred_language: str

    class Config:
        from_attributes = True

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

