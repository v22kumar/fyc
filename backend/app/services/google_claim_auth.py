"""Immediate Google authentication plus collision-safe phone claims."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException
from fastapi.dependencies.utils import get_dependant
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.rate_limit import limiter
from app.core.security import create_access_token, create_refresh_token
from app.dependencies import get_current_user
from app.models.user import User, UserProfile
from app.schemas.auth import Token, _build_user_out


class PhoneClaimRequest(BaseModel):
    phone_number: str = Field(min_length=10, max_length=20)


class PhoneClaimResponse(BaseModel):
    claimed: bool
    phone_number: Optional[str] = None
    phone_verified: bool = False
    conflict: bool = False
    reason: Optional[str] = None
    otp_sent: bool = False
    otp_channel: Optional[str] = None
    otp_verification_id: Optional[str] = None


def _normalise_phone(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit())
    if len(digits) == 10:
        return f"+91{digits}"
    return f"+{digits}"


def _issue_token(db: Session, user: User) -> Token:
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(
        access_token=create_access_token(subject=user.id, role=user.role, organization_id=str(user.organization_id)),
        refresh_token=create_refresh_token(user.id, user.token_version),
        token_type="bearer",
        user=_build_user_out(user, profile),
    )


def session_for_google_identity(db: Session, organization_id, idinfo: dict):
    """Authenticate Google and create a session immediately."""
    email = (idinfo.get("email") or "").strip().lower()
    google_sub = idinfo.get("sub")
    name = (idinfo.get("name") or idinfo.get("given_name") or "FYC Member").strip()
    if not email or not google_sub:
        raise HTTPException(status_code=400, detail="Google account has no usable identity")

    user = db.query(User).filter(User.organization_id == organization_id, User.email == email).first()
    if not user:
        user = db.query(User).filter(User.organization_id == organization_id, User.google_sub == google_sub).first()

    is_super_admin = email == "vrn2252@gmail.com"
    if user is not None and getattr(user, "is_blocked", False):
        raise HTTPException(status_code=403, detail="Your account has been blocked by an administrator.")

    if user is None:
        user = User(
            organization_id=organization_id,
            email=email,
            google_sub=google_sub,
            role="SUPER_ADMIN" if is_super_admin else "PUBLIC_CITIZEN",
            is_verified=True,
            preferred_language="en" if is_super_admin else "ta",
        )
        db.add(user)
        db.flush()
        db.add(UserProfile(user_id=user.id, full_name_en=name, full_name_ta=name, last_login_at=datetime.now(timezone.utc)))
    else:
        if google_sub and not user.google_sub:
            user.google_sub = google_sub
        if is_super_admin and user.role != "SUPER_ADMIN":
            user.role = "SUPER_ADMIN"
        if user.profile is not None:
            user.profile.last_login_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(user)
    return _issue_token(db, user)


def _send_claim_otp(db: Session, user: User, phone: str) -> tuple[bool, Optional[str], Optional[str]]:
    """Try the existing OTP delivery ladder without blocking Google login."""
    from app.core.config import settings
    from app.models.otp import PendingOtp
    from app.services.otp_sender import send_otp as _deliver_otp, send_verify_otp
    from app.routers import auth

    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

    if settings.TWILIO_VERIFY_SID:
        try:
            if send_verify_otp(phone):
                db.add(PendingOtp(verification_id=verification_id, phone_number=phone, organization_id=user.organization_id, code_hash=None, expires_at=expires_at, attempts=0))
                db.commit()
                return True, "sms", verification_id
        except Exception:
            db.rollback()

    try:
        code = auth._generate_otp()
        db.add(PendingOtp(verification_id=verification_id, phone_number=phone, organization_id=user.organization_id, code_hash=auth._hash_code(code), expires_at=expires_at, attempts=0))
        db.commit()
        results = _deliver_otp(phone, code)
        channel = next((name for name, ok in results.items() if ok), None)
        if channel:
            return True, channel, verification_id
        row = db.get(PendingOtp, verification_id)
        if row is not None:
            db.delete(row)
            db.commit()
    except Exception:
        db.rollback()
    return False, None, None


@limiter.limit("10/minute")
def claim_phone(payload: PhoneClaimRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> PhoneClaimResponse:
    """Attach a typed number as an unverified claim and start OTP proof."""
    phone = _normalise_phone(payload.phone_number)
    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="Enter a valid phone number")

    if current_user.phone_number == phone:
        return PhoneClaimResponse(claimed=True, phone_number=phone, phone_verified=current_user.phone_verified_at is not None)
    if current_user.phone_number and current_user.phone_number != phone:
        return PhoneClaimResponse(claimed=False, phone_number=current_user.phone_number, phone_verified=current_user.phone_verified_at is not None, reason="Your account already has a phone number.")

    existing = db.query(User).filter(User.organization_id == current_user.organization_id, User.phone_number == phone, User.id != current_user.id).first()
    if existing is not None:
        return PhoneClaimResponse(claimed=False, conflict=True, reason="That phone number is already attached to another account.")

    current_user.phone_number = phone
    # Google proves the account, not the phone. Keep phone_verified_at NULL.
    db.commit()
    db.refresh(current_user)
    otp_sent, otp_channel, verification_id = _send_claim_otp(db, current_user, phone)
    return PhoneClaimResponse(claimed=True, phone_number=phone, phone_verified=False, otp_sent=otp_sent, otp_channel=otp_channel, otp_verification_id=verification_id)


def install(auth_router) -> None:
    """Patch the existing Google flow without duplicating the auth router."""
    auth_router.session_for_google_identity = session_for_google_identity

    original_graduate = getattr(auth_router, "_graduate_from_directory", None)
    if original_graduate is not None and not getattr(original_graduate, "_google_claim_wrapper", False):
        def _graduate_and_verify(db, user):
            original_graduate(db, user)
            from app.services.account_claims import mark_phone_verified
            mark_phone_verified(db, user)
        _graduate_and_verify._google_claim_wrapper = True
        auth_router._graduate_from_directory = _graduate_and_verify

    original_verify = getattr(auth_router, "verify_otp", None)
    if original_verify is not None and not getattr(original_verify, "_google_claim_wrapper", False):
        def _verify_otp_claim_safe(request, payload, db):
            row = auth_router._otp_get(db, payload.verification_id)
            claimant = None
            temporary_hash = False
            if row is not None:
                claimant = db.query(User).filter(User.organization_id == row.organization_id, User.phone_number == row.phone_number).first()
                if claimant is not None and claimant.phone_verified_at is None and not claimant.password_hash:
                    claimant.password_hash = "__google_claim_unverified__"
                    db.flush()
                    temporary_hash = True
            try:
                return original_verify(request, payload, db)
            finally:
                if temporary_hash and claimant is not None:
                    claimant.password_hash = None
                    db.commit()
        _verify_otp_claim_safe._google_claim_wrapper = True
        for route in auth_router.router.routes:
            if getattr(route, "path", None) == "/auth/otp/verify" and "POST" in (getattr(route, "methods", set()) or set()):
                route.endpoint = _verify_otp_claim_safe
                route.dependant = get_dependant(path=route.path, call=_verify_otp_claim_safe)

    if not any(getattr(route, "path", None) == "/auth/google/claim-phone" for route in auth_router.router.routes):
        auth_router.router.add_api_route("/google/claim-phone", claim_phone, methods=["POST"], response_model=PhoneClaimResponse, tags=["Authentication"])
