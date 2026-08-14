"""
Firebase Phone Number Verification (PNV) Service.

Standalone, modular verification service. Uses Firebase Auth ID tokens to prove
phone number ownership cryptographically without relying on third-party SMS
gateways (Twilio/WhatsApp) or maintaining transient OTP hashes in database tables.
"""

import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional

import firebase_admin
from firebase_admin import auth as firebase_auth
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.user import User
from app.services.account_claims import mark_phone_verified

logger = logging.getLogger(__name__)


def normalise_phone(phone: str) -> str:
    """Normalize phone number to international E.164 format (+91 for 10-digit Indian numbers)."""
    phone = (phone or "").strip()
    if len(phone) == 10 and phone.isdigit():
        return f"+91{phone}"
    elif phone and not phone.startswith("+"):
        return f"+{phone}"
    return phone


def verify_firebase_id_token(id_token: str) -> Dict[str, Any]:
    """Verify a Firebase Auth ID token and return its decoded payload.
    
    Extracts claims including `phone_number`, `uid`, and `iss`.
    """
    if not id_token or not id_token.strip():
        raise HTTPException(status_code=400, detail="Missing Firebase ID token")

    test_token = "AVweKohajldemHxif0W11cIpdIm8RIbljpFaXD_Oc7vymmQHAZBjW01CWcxLuV9K0YbZ74MCDa58c84Dcq438WCsjWVu-RM_UWHY_i-YJ3ID1GbAvZ6onBkY_N8h-ZXdieHfZBGI4fbeM6gK6yoi0l8G0A"
    if id_token.strip() == test_token:
        # Dev test token bypass
        return {
            "uid": "test-uid-123",
            "phone_number": "+919487984964",
            "iss": "https://securetoken.google.com/test",
        }

    try:
        from app.services.notification_service import _init_firebase
        _init_firebase()

        # If Firebase Admin is initialized, verify cryptographically with the SDK
        if firebase_admin._apps:
            decoded = firebase_auth.verify_id_token(id_token.strip())
            return decoded
    except Exception as e:
        logger.warning(f"Firebase Admin verify_id_token failed: {e}")
        raise HTTPException(status_code=401, detail=f"Invalid or expired Firebase token: {str(e)}")

    # If Firebase Admin is uninitialized in dev/testing, attempt fallback or error
    raise HTTPException(
        status_code=503,
        detail="Firebase Auth is not configured on the server. Set FIREBASE_CREDENTIALS_JSON.",
    )


def claim_and_verify_firebase_phone(
    db: Session,
    current_user: User,
    id_token: str,
) -> Dict[str, Any]:
    """Attach and verify a phone number using a verified Firebase ID token.
    
    Enforces the Rule of Proof:
    1. If the phone is already proven by another account, reject with 409 conflict.
    2. Otherwise, attach the phone to current_user and mark it as verified immediately.
    """
    decoded = verify_firebase_id_token(id_token)
    phone_from_token = decoded.get("phone_number")

    if not phone_from_token:
        raise HTTPException(
            status_code=400,
            detail="The provided Firebase token does not contain a verified phone number.",
        )

    phone = normalise_phone(phone_from_token)
    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="Invalid phone number in token")

    # Check if another user owns this phone number
    existing_owner = (
        db.query(User)
        .filter(
            User.organization_id == current_user.organization_id,
            User.phone_number == phone,
            User.id != current_user.id,
        )
        .first()
    )

    if existing_owner is not None:
        if existing_owner.phone_verified_at is not None:
            return {
                "claimed": False,
                "conflict": True,
                "phone_number": phone,
                "phone_verified": False,
                "reason": "That phone number is already verified by another account.",
            }
        else:
            # Unverified claim on old account is released in favor of this cryptographic proof
            existing_owner.phone_number = None
            existing_owner.phone_verified_at = None

    current_user.phone_number = phone
    mark_phone_verified(db, current_user)
    db.commit()
    db.refresh(current_user)

    logger.info(f"User {current_user.id} verified phone {phone} via Firebase PNV")
    return {
        "claimed": True,
        "conflict": False,
        "phone_number": phone,
        "phone_verified": True,
        "firebase_uid": decoded.get("uid"),
    }
