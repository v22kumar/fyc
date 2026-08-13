"""Immediate Google authentication plus collision-safe phone claims.

Google proves the Google identity. The phone typed on the first screen is only a
claim until OTP proves ownership. A number already attached to another account
is never stolen or used to choose the account.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import create_access_token, create_refresh_token
from app.dependencies import get_current_user
from app.models.tenant import Organization
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


def _normalise_phone(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit())
    if len(digits) == 10:
        return f"+91{digits}"
    if phone.strip().startswith("+"):
        return f"+{digits}"
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
    """Authenticate Google and create a session immediately.

    A new Google identity gets a real PUBLIC_CITIZEN account now. No phone is
    required for the account to exist. Phone ownership is a separate proof step.
    """
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


def claim_phone(
    payload: PhoneClaimRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PhoneClaimResponse:
    """Attach a typed number only when it is not already attached elsewhere.

    This endpoint deliberately does NOT set phone_verified_at. Only /otp/verify
    can establish ownership. If the number belongs to somebody else, Google
    authentication still succeeds and the claim is simply declined.
    """
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
        # Proof wins later through the existing OTP flow; Google never overrides
        # an existing phone relationship, verified or otherwise.
        return PhoneClaimResponse(
            claimed=False,
            conflict=True,
            reason="That phone number is already attached to another account.",
        )

    current_user.phone_number = phone
    # Intentionally leave phone_verified_at NULL. Google did not prove the phone.
    db.commit()
    db.refresh(current_user)
    return PhoneClaimResponse(claimed=True, phone_number=phone, phone_verified=False)


def install(auth_router) -> None:
    """Patch the existing Google flow without duplicating the auth router."""
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
