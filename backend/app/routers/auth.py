import random
import uuid
from typing import Dict, Tuple
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, verify_password, get_password_hash
from app.services.otp_sender import send_otp as deliver_otp, send_verify_otp, check_verify_otp
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.models.club_request import ClubMemberRequest
from app.schemas.auth import OTPRequest, OTPResponse, OTPVerify, Token, UserRegister, UserOut, AdminLogin, GoogleLoginRequest, _build_user_out

router = APIRouter(prefix="/auth", tags=["Authentication"])

limiter = Limiter(key_func=get_remote_address)

OTP_TTL_MINUTES = 10

# In-memory OTP store: verification_id → (phone, otp_code_or_None, org_id, expires_at)
# otp_code is None when Twilio Verify is used (Twilio manages the code server-side)
otp_store: Dict[str, Tuple[str, str | None, uuid.UUID, datetime]] = {}


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
    # Ensure phone number is E.164 formatted (default to +91 for India)
    if len(payload.phone_number) == 10 and payload.phone_number.isdigit():
        payload.phone_number = f"+91{payload.phone_number}"
    elif not payload.phone_number.startswith('+'):
        payload.phone_number = f"+{payload.phone_number}"

    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)

    if settings.TWILIO_VERIFY_SID:
        # Twilio Verify manages the OTP — we only track phone+org
        send_verify_otp(payload.phone_number)
        otp_store[verification_id] = (payload.phone_number, None, payload.organization_id, expires_at)
    else:
        otp_code = _generate_otp()
        otp_store[verification_id] = (payload.phone_number, otp_code, payload.organization_id, expires_at)
        deliver_otp(payload.phone_number, otp_code, email=payload.email)

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

    phone_number, otp_code, org_id, expires_at = stored

    if datetime.now(timezone.utc) > expires_at:
        otp_store.pop(payload.verification_id, None)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired. Please request a new one.",
        )

    if otp_code is None:
        # Twilio Verify flow — delegate check to Twilio
        if not check_verify_otp(phone_number, payload.otp_code):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP code")
    elif payload.otp_code != otp_code:
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

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, token_type="bearer", user=_build_user_out(user, profile))


@router.post("/register", response_model=Token)
def register_user(payload: UserRegister, db: Session = Depends(get_db)):
    """Register a new Citizen or Volunteer after OTP verification."""
    # Ensure phone number is E.164 formatted (default to +91 for India)
    if len(payload.phone_number) == 10 and payload.phone_number.isdigit():
        payload.phone_number = f"+91{payload.phone_number}"
    elif not payload.phone_number.startswith('+'):
        payload.phone_number = f"+{payload.phone_number}"

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

    # CLUB_MEMBER registrations are held in a PENDING approval queue.
    # The user account is created with PUBLIC_CITIZEN so they can use
    # the app immediately; an admin must approve before the role upgrades.
    effective_role = "PUBLIC_CITIZEN" if payload.role == "CLUB_MEMBER" else payload.role

    user = User(
        organization_id=payload.organization_id,
        phone_number=payload.phone_number,
        role=effective_role,
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

    if payload.role == "CLUB_MEMBER":
        db.add(ClubMemberRequest(
            organization_id=payload.organization_id,
            user_id=user.id,
            status="PENDING",
        ))

    db.commit()
    db.refresh(user)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, token_type="bearer", user=_build_user_out(user, profile))


from google.oauth2 import id_token
from google.auth.transport import requests

@router.post("/google", response_model=Token)
def login_google(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    """Google Sign-In logic for mobile app"""
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    valid_client_ids = [
        cid for cid in [settings.GOOGLE_CLIENT_ID, settings.GOOGLE_WEB_CLIENT_ID] if cid
    ]
    if not valid_client_ids:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Sign-In is not configured. Set GOOGLE_CLIENT_ID or GOOGLE_WEB_CLIENT_ID.",
        )

    try:
        idinfo = None
        last_err: Exception = ValueError("no client IDs configured")
        for cid in valid_client_ids:
            try:
                idinfo = id_token.verify_oauth2_token(
                    payload.id_token, requests.Request(), cid
                )
                break
            except ValueError as e:
                last_err = e
        if idinfo is None:
            raise last_err
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid Google token: {e}")
        
    email = idinfo.get("email")
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google account has no email")

    google_sub = idinfo.get("sub")
    name = idinfo.get("name", "")
    given_name = idinfo.get("given_name", name)

    user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        User.email == email,
    ).first()

    if not user and google_sub:
        user = db.query(User).filter(
            User.organization_id == payload.organization_id,
            User.google_sub == google_sub,
        ).first()

    # If user doesn't exist, create them automatically
    if not user:
        # Special check for super admin
        role = "SUPER_ADMIN" if email == "vrn2252@gmail.com" else "PUBLIC_CITIZEN"
        
        user = User(
            organization_id=payload.organization_id,
            email=email,
            google_sub=google_sub,
            role=role,
            is_verified=True,
            preferred_language="en",
        )
        db.add(user)
        db.flush()

        profile = UserProfile(
            user_id=user.id,
            full_name_en=name or given_name or "FYC User",
            full_name_ta=name or given_name or "FYC பயனர்",
            last_login_at=datetime.now(timezone.utc),
        )
        db.add(profile)
        db.commit()
        db.refresh(user)
    else:
        # Link google_sub if not present
        if google_sub and not user.google_sub:
            user.google_sub = google_sub
            db.commit()
            db.refresh(user)

        # If the user is vrn2252@gmail.com, upgrade them to SUPER_ADMIN to ensure they have access.
        if email == "vrn2252@gmail.com" and user.role != "SUPER_ADMIN":
            user.role = "SUPER_ADMIN"
            db.commit()
            db.refresh(user)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, token_type="bearer", user=_build_user_out(user, profile))


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

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, token_type="bearer", user=_build_user_out(user, profile))





@router.get("/users/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return the currently authenticated user with profile."""
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    return _build_user_out(current_user, profile)
