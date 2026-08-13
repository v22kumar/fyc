"""Google-first authentication and collision-safe phone claims.

This module owns the new Google -> phone-claim flow. It deliberately does not
patch or replace the legacy phone OTP route. Keeping those routes independent
prevents FastAPI dependency graphs from being mutated at runtime and prevents a
phone-only login from ever selecting a Google-only account.
"""
from __future__ import annotations

import hmac
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, Request
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


class PhoneClaimVerifyRequest(BaseModel):
    verification_id: str
    otp_code: str = Field(min_length=6, max_length=6)


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
        access_token=create_access_token(
            subject=user.id,
            role=user.role,
            organization_id=str(user.organization_id),
        ),
        refresh_token=create_refresh_token(user.id, user.token_version),
        token_type="bearer",
        user=_build_user_out(user, profile),
    )


def session_for_google_identity(db: Session, organization_id, idinfo: dict):
    """Authenticate an existing Google identity; new users use registration."""
    email = (idinfo.get("email") or "").strip().lower()
    google_sub = idinfo.get("sub")
    name = (idinfo.get("name") or idinfo.get("given_name") or "FYC Member").strip()
    if not email or not google_sub:
        raise HTTPException(status_code=400, detail="Google account has no usable identity")

    user = db.query(User).filter(
        User.organization_id == organization_id,
        User.email == email,
    ).first()
    if not user:
        user = db.query(User).filter(
            User.organization_id == organization_id,
            User.google_sub == google_sub,
        ).first()

    is_super_admin = email == "vrn2252@gmail.com"
    if user is not None and getattr(user, "is_blocked", False):
        raise HTTPException(status_code=403, detail="Your account has been blocked by an administrator.")

    if user is None and not is_super_admin:
        return {"needs_registration": True, "email": email, "full_name": name}

    if user is None:
        user = User(
            organization_id=organization_id,
            email=email,
            google_sub=google_sub,
            role="SUPER_ADMIN",
            is_verified=True,
            preferred_language="en",
        )
        db.add(user)
        db.flush()
        db.add(UserProfile(
            user_id=user.id,
            full_name_en=name,
            full_name_ta=name,
            last_login_at=datetime.now(timezone.utc),
        ))
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


def _send_claim_otp(
    db: Session,
    user: User,
    phone: str,
) -> tuple[bool, Optional[str], Optional[str]]:
    """Send OTP as best effort; Google authentication never depends on delivery."""
    from app.core.config import settings
    from app.models.otp import PendingOtp
    from app.services.otp_sender import send_otp as _deliver_otp, send_verify_otp
    from app.routers import auth

    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

    if settings.TWILIO_VERIFY_SID:
        try:
            if send_verify_otp(phone):
                db.add(PendingOtp(
                    verification_id=verification_id,
                    phone_number=phone,
                    organization_id=user.organization_id,
                    code_hash=None,
                    expires_at=expires_at,
                    attempts=0,
                ))
                db.commit()
                return True, "sms", verification_id
        except Exception:
            db.rollback()

    try:
        code = auth._generate_otp()
        db.add(PendingOtp(
            verification_id=verification_id,
            phone_number=phone,
            organization_id=user.organization_id,
            code_hash=auth._hash_code(code),
            expires_at=expires_at,
            attempts=0,
        ))
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
def claim_phone(
    request: Request,
    payload: PhoneClaimRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PhoneClaimResponse:
    """Attach a typed phone as an unverified claim to the current Google user."""
    phone = _normalise_phone(payload.phone_number)
    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="Enter a valid phone number")

    if current_user.phone_number == phone:
        return PhoneClaimResponse(
            claimed=True,
            phone_number=phone,
            phone_verified=current_user.phone_verified_at is not None,
        )

    if current_user.phone_number and current_user.phone_number != phone:
        return PhoneClaimResponse(
            claimed=False,
            phone_number=current_user.phone_number,
            phone_verified=current_user.phone_verified_at is not None,
            reason="Your account already has a phone number.",
        )

    existing = db.query(User).filter(
        User.organization_id == current_user.organization_id,
        User.phone_number == phone,
        User.id != current_user.id,
    ).first()
    if existing is not None:
        return PhoneClaimResponse(
            claimed=False,
            conflict=True,
            reason="That phone number is already attached to another account.",
        )

    current_user.phone_number = phone
    db.commit()
    db.refresh(current_user)

    otp_sent, otp_channel, verification_id = _send_claim_otp(db, current_user, phone)
    return PhoneClaimResponse(
        claimed=True,
        phone_number=phone,
        phone_verified=False,
        otp_sent=otp_sent,
        otp_channel=otp_channel,
        otp_verification_id=verification_id,
    )


@limiter.limit("20/minute")
def verify_claim_phone(
    request: Request,
    payload: PhoneClaimVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PhoneClaimResponse:
    """Prove the claimed phone without changing the authenticated Google user."""
    from app.models.otp import PendingOtp
    from app.services.otp_sender import check_verify_otp
    from app.routers import auth

    row = db.get(PendingOtp, payload.verification_id)
    if row is None or row.phone_number != current_user.phone_number or row.organization_id != current_user.organization_id:
        raise HTTPException(status_code=400, detail="Invalid or expired phone verification")

    expires = row.expires_at if row.expires_at.tzinfo else row.expires_at.replace(tzinfo=timezone.utc)
    if expires < datetime.now(timezone.utc):
        db.delete(row)
        db.commit()
        raise HTTPException(status_code=400, detail="Phone verification has expired. Request a new code.")

    valid = (
        check_verify_otp(row.phone_number, payload.otp_code)
        if row.code_hash is None
        else hmac.compare_digest(auth._hash_code(payload.otp_code), row.code_hash)
    )
    if not valid:
        row.attempts += 1
        if row.attempts >= 5:
            db.delete(row)
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid OTP code")

    db.delete(row)
    from app.services.account_claims import mark_phone_verified
    mark_phone_verified(db, current_user)
    db.commit()
    return PhoneClaimResponse(
        claimed=True,
        phone_number=current_user.phone_number,
        phone_verified=True,
    )


def install(auth_router) -> None:
    """Register the Google-first extension without modifying existing auth routes."""
    auth_router.session_for_google_identity = session_for_google_identity

    if not any(
        getattr(route, "path", None) == "/auth/google/claim-phone"
        for route in auth_router.router.routes
    ):
        auth_router.router.add_api_route(
            "/google/claim-phone",
            claim_phone,
            methods=["POST"],
            response_model=PhoneClaimResponse,
            tags=["Authentication"],
        )

    if not any(
        getattr(route, "path", None) == "/auth/google/claim-phone/verify"
        for route in auth_router.router.routes
    ):
        auth_router.router.add_api_route(
            "/google/claim-phone/verify",
            verify_claim_phone,
            methods=["POST"],
            response_model=PhoneClaimResponse,
            tags=["Authentication"],
        )
