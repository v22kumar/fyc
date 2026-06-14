import uuid
from typing import Dict, Tuple
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import create_access_token, verify_password, get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.schemas.auth import OTPRequest, OTPResponse, OTPVerify, Token, UserRegister, UserOut, AdminLogin

router = APIRouter(prefix="/auth", tags=["Authentication"])


# Global memory store to simulate OTP storage (Key: verification_id -> Value: (phone_number, otp_code, organization_id))
otp_store: Dict[str, Tuple[str, str, uuid.UUID]] = {}

@router.post("/otp/send", response_model=OTPResponse)
def send_otp(payload: OTPRequest, db: Session = Depends(get_db)):
    """
    Initiate authentication by sending a 6-digit OTP to the phone number.
    Verifies that the organization (tenant) exists in the database.
    """
    # Check if organization exists
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found"
        )

    # In local testing, we generate a mock verification ID and fixed OTP
    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    mock_otp = "123456"  # Standard mock OTP for developer ease
    
    # Store OTP validation mapping
    otp_store[verification_id] = (payload.phone_number, mock_otp, payload.organization_id)
    
    # In production, SMS API would be invoked here.
    return OTPResponse(
        message="OTP sent successfully (Use '123456' for mock verification)",
        verification_id=verification_id
    )

@router.post("/otp/verify", response_model=Token)
def verify_otp(payload: OTPVerify, db: Session = Depends(get_db)):
    """
    Verify OTP. If user is registered, returns JWT token.
    If not registered, raises 404 prompting registration.
    """
    stored = otp_store.get(payload.verification_id)
    if not stored:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification ID"
        )
        
    phone_number, otp_code, org_id = stored
    
    if payload.otp_code != otp_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP code"
        )
        
    # Check if user exists under this organization
    user = db.query(User).filter(
        User.organization_id == org_id,
        User.phone_number == phone_number
    ).first()
    
    if not user:
        # User needs to register. Raise 404 with registration hint details.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not registered. Please call /auth/register."
        )
        
    # Clean up OTP store
    otp_store.pop(payload.verification_id, None)
    
    # Generate access token
    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id)
    )
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserOut.model_validate(user)
    )

@router.post("/register", response_model=Token)
def register_user(payload: UserRegister, db: Session = Depends(get_db)):
    """
    Register a new Citizen or Volunteer after OTP verification.
    """
    # Check if organization exists
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found"
        )

    # Check if phone number is already registered under this organization
    existing_user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        User.phone_number == payload.phone_number
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered under this organization"
        )
        
    # Create user
    user = User(
        organization_id=payload.organization_id,
        phone_number=payload.phone_number,
        role=payload.role,
        is_verified=True,
        preferred_language=payload.preferred_language
    )
    db.add(user)
    db.flush()  # Flushes user to DB to fetch ID
    
    # Create profile
    profile = UserProfile(
        user_id=user.id,
        full_name_ta=payload.full_name_ta,
        full_name_en=payload.full_name_en,
        last_login_at=datetime.now(timezone.utc)
    )
    db.add(profile)
    
    # Create volunteer metadata if role is VOLUNTEER
    if payload.role == "VOLUNTEER":
        vol_meta = VolunteerMetadata(
            user_id=user.id,
            skills=[],
            total_hours_accrued=0.00
        )
        db.add(vol_meta)
        
    db.commit()
    db.refresh(user)
    
    # Generate access token
    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id)
    )
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserOut.model_validate(user)
    )

@router.post("/login/password", response_model=Token)
def login_password(payload: AdminLogin, db: Session = Depends(get_db)):
    """
    Log in using password (for Administrators, Executives, and Club Members).
    """
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found"
        )

    user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        ((User.email == payload.username) | (User.phone_number == payload.username))
    ).first()

    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid username or password"
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid username or password"
        )

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id)
    )

    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserOut.model_validate(user)
    )

from app.dependencies import get_current_user


@router.get("/users/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    """
    Retrieve details of the currently authenticated user.
    """
    return current_user

