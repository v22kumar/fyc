import random
import uuid
from typing import Dict, Tuple
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, verify_password, get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.schemas.auth import OTPRequest, OTPResponse, OTPVerify, Token, UserRegister, UserOut, AdminLogin

router = APIRouter(prefix="/auth", tags=["Authentication"])

limiter = Limiter(key_func=get_remote_address)

# In-memory OTP store: verification_id → (phone, otp_code, org_id)
otp_store: Dict[str, Tuple[str, str, uuid.UUID]] = {}


def _generate_otp() -> str:
    """Return a fixed bypass code in test/dev, or a random 6-digit code otherwise."""
    if settings.OTP_BYPASS_CODE:
        return settings.OTP_BYPASS_CODE
    return f"{random.randint(0, 999999):06d}"


@router.post("/otp/send", response_model=OTPResponse)
@limiter.limit("5/minute")
def send_otp(request: Request, payload: OTPRequest, db: Session = Depends(get_db)):
    """
    Initiate authentication by sending a 6-digit OTP to the phone number.
    Rate-limited to 5 requests per minute per IP.
    """
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    otp_code = _generate_otp()

    otp_store[verification_id] = (payload.phone_number, otp_code, payload.organization_id)

    # In production replace this with your SMS provider (Twilio, AWS SNS, etc.)
    print(f"[OTP] {payload.phone_number} → {otp_code}")

    return OTPResponse(
        message="OTP sent successfully",
        verification_id=verification_id,
    )


@router.post("/otp/verify", response_model=Token)
def verify_otp(payload: OTPVerify, db: Session = Depends(get_db)):
    """
    Verify OTP. Returns JWT on success; 404 if user not yet registered.
    """
    stored = otp_store.get(payload.verification_id)
    if not stored:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification ID",
        )

    phone_number, otp_code, org_id = stored

    if payload.otp_code != otp_code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP code")

    user = db.query(User).filter(
        User.organization_id == org_id,
        User.phone_number == phone_number,
    ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not registered. Please call /auth/register.",
        )

    otp_store.pop(payload.verification_id, None)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    return Token(access_token=access_token, token_type="bearer", user=UserOut.model_validate(user))


@router.post("/register", response_model=Token)
def register_user(payload: UserRegister, db: Session = Depends(get_db)):
    """Register a new Citizen or Volunteer after OTP verification."""
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    existing_user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        User.phone_number == payload.phone_number,
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered under this organization",
        )

    user = User(
        organization_id=payload.organization_id,
        phone_number=payload.phone_number,
        role=payload.role,
        is_verified=True,
        preferred_language=payload.preferred_language,
    )
    db.add(user)
    db.flush()

    profile = UserProfile(
        user_id=user.id,
        full_name_ta=payload.full_name_ta,
        full_name_en=payload.full_name_en,
        last_login_at=datetime.now(timezone.utc),
    )
    db.add(profile)

    if payload.role == "VOLUNTEER":
        db.add(VolunteerMetadata(user_id=user.id, skills=[], total_hours_accrued=0.00))

    db.commit()
    db.refresh(user)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    return Token(access_token=access_token, token_type="bearer", user=UserOut.model_validate(user))


@router.post("/login/password", response_model=Token)
def login_password(payload: AdminLogin, db: Session = Depends(get_db)):
    """Password login for Administrators, Executives, and Club Members."""
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        ((User.email == payload.username) | (User.phone_number == payload.username)),
    ).first()

    if not user or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid username or password")

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid username or password")

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    return Token(access_token=access_token, token_type="bearer", user=UserOut.model_validate(user))


from app.dependencies import get_current_user


@router.get("/users/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    """Return the currently authenticated user."""
    return current_user
