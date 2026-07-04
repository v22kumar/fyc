import datetime
import uuid
from datetime import date
from io import BytesIO
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import extract

from app.core.database import get_db
from app.dependencies import get_current_user, RoleChecker
from app.models.user import User, UserProfile, VolunteerMetadata, UserBlock
from app.models.tenant import Organization
from app.schemas.auth import UserOut, _build_user_out
from app.services.certificates import generate_volunteer_certificate
from app.middleware.tenant import require_tenant_id
from pydantic import BaseModel, BaseModel as _BaseModel, ConfigDict
from uuid import UUID

router = APIRouter(prefix="/users", tags=["Users"])

require_admin = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_volunteer = RoleChecker(["VOLUNTEER"])


class UserWithProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    phone_number: Optional[str] = None
    role: str
    is_verified: bool
    preferred_language: str
    full_name_ta: Optional[str] = None
    full_name_en: Optional[str] = None


@router.get("", response_model=List[UserWithProfile])
def list_users(
    role: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """List users in the current tenant, optionally filtered by role (admin only)."""
    query = (
        db.query(User, UserProfile)
        .outerjoin(UserProfile, UserProfile.user_id == User.id)
        .filter(User.organization_id == current_user.organization_id)
    )
    if role:
        query = query.filter(User.role == role.upper())

    rows = query.order_by(User.role).all()
    return [
        UserWithProfile(
            id=user.id,
            phone_number=user.phone_number or "",
            role=user.role,
            is_verified=user.is_verified,
            preferred_language=user.preferred_language,
            full_name_ta=profile.full_name_ta if profile else None,
            full_name_en=profile.full_name_en if profile else None,
        )
        for user, profile in rows
    ]


@router.get("/volunteers/my-certificate")
def get_my_volunteer_certificate(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_volunteer),
):
    """
    Generate and return a PDF volunteer certificate for the authenticated volunteer.
    Requires the user to have a VolunteerMetadata record with hours accrued.
    """
    volunteer_meta = db.query(VolunteerMetadata).filter(
        VolunteerMetadata.user_id == current_user.id
    ).first()
    if not volunteer_meta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No volunteer metadata found for this user"
        )

    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()
    full_name = profile.full_name_en if profile and profile.full_name_en else "Volunteer"

    org = db.query(Organization).filter(
        Organization.id == current_user.organization_id
    ).first()
    org_name = org.name_en if org else "FYC Connect"

    total_hours = float(volunteer_meta.total_hours_accrued or 0)
    cert_id = str(current_user.id)[:8]
    issued_date = datetime.date.today()

    pdf_bytes = generate_volunteer_certificate(
        full_name=full_name,
        org_name=org_name,
        total_hours=total_hours,
        issued_date=issued_date,
        cert_id=cert_id,
    )

    return StreamingResponse(
        BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="certificate_{cert_id}.pdf"'
        },
    )


class ProfileUpdate(_BaseModel):
    full_name_ta: Optional[str] = None
    full_name_en: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None          # MALE / FEMALE / OTHER
    phone_number: Optional[str] = None    # Only for Google-only users who want to add phone


@router.patch("/me/profile", response_model=UserOut)
def update_my_profile(
    payload: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update the authenticated user's profile (name, DOB, gender, phone)."""
    # Phone deduplication: if adding a phone, ensure it's not taken by another user
    if payload.phone_number and payload.phone_number != current_user.phone_number:
        clash = db.query(User).filter(
            User.organization_id == current_user.organization_id,
            User.phone_number == payload.phone_number,
            User.id != current_user.id,
        ).first()
        if clash:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This phone number is already registered under another account.",
            )
        current_user.phone_number = payload.phone_number

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    if payload.full_name_ta is not None:
        profile.full_name_ta = payload.full_name_ta
    if payload.full_name_en is not None:
        profile.full_name_en = payload.full_name_en
    if payload.date_of_birth is not None:
        profile.date_of_birth = payload.date_of_birth
    if payload.gender is not None:
        if payload.gender not in ("MALE", "FEMALE", "OTHER"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="gender must be MALE, FEMALE, or OTHER")
        profile.gender = payload.gender

    db.commit()
    db.refresh(current_user)
    db.refresh(profile)
    return _build_user_out(current_user, profile)


class FcmTokenPayload(_BaseModel):
    token: str


@router.post("/me/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
def register_fcm_token(
    payload: FcmTokenPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Store the device FCM push token for the authenticated user."""
    current_user.fcm_token = payload.token
    db.commit()


class BirthdayOut(_BaseModel):
    full_name_en: str
    full_name_ta: str


@router.get("/birthdays/today", response_model=list[BirthdayOut])
def todays_birthdays(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Return names of org members whose birthday is today (month + day match)."""
    today = date.today()
    rows = (
        db.query(UserProfile)
        .join(User, User.id == UserProfile.user_id)
        .filter(
            User.organization_id == tenant_id,
            UserProfile.date_of_birth.isnot(None),
            extract("month", UserProfile.date_of_birth) == today.month,
            extract("day", UserProfile.date_of_birth) == today.day,
        )
        .all()
    )
    return [BirthdayOut(full_name_en=p.full_name_en, full_name_ta=p.full_name_ta) for p in rows]


PROMOTABLE_ROLES = ["PUBLIC_CITIZEN", "VOLUNTEER", "CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN"]


class PromotePayload(_BaseModel):
    role: str


@router.post("/{user_id}/promote")
def promote_user(
    user_id: UUID,
    payload: PromotePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Admin: directly set a user's role (for promotions and demotions)."""
    if payload.role not in PROMOTABLE_ROLES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Must be one of: {', '.join(PROMOTABLE_ROLES)}",
        )
    target = db.query(User).filter(
        User.id == user_id,
        User.organization_id == current_user.organization_id,
    ).first()
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if target.id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot promote yourself")

    target.role = payload.role
    db.commit()
    return {"ok": True, "user_id": str(user_id), "new_role": payload.role}

class UserCommunityJourneyOut(_BaseModel):
    events_attended: int
    issues_helped: int
    blood_donations: int
    trees_planted: int
    sports_matches_played: int
    volunteer_hours: float

@router.get("/me/journey", response_model=UserCommunityJourneyOut)
def get_my_community_journey(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns an aggregated living profile of the user's community journey.
    """
    from app.models.event import EventAttendance
    from app.models.issue import PublicIssue
    from app.models.blood_donor import BloodDonor
    from app.models.green_fyc import TreeRegistration
    from app.models.sports import Player
    
    events_attended = db.query(EventAttendance).filter(
        EventAttendance.user_id == current_user.id
    ).count()
    
    issues_helped = db.query(PublicIssue).filter(
        PublicIssue.assigned_volunteer_id == current_user.id,
        PublicIssue.status == "RESOLVED"
    ).count()
    
    blood_donations = db.query(BloodDonor).filter(
        BloodDonor.user_id == current_user.id
    ).count()
    
    trees_planted = db.query(TreeRegistration).filter(
        TreeRegistration.registered_by_user_id == current_user.id
    ).count()
    
    # Sports matches: SUM of matches_played across all Player profiles for this user
    from sqlalchemy.sql import func
    sports_matches = db.query(func.sum(Player.matches_played)).filter(
        Player.user_id == current_user.id
    ).scalar() or 0
    
    volunteer_meta = db.query(VolunteerMetadata).filter(VolunteerMetadata.user_id == current_user.id).first()
    volunteer_hours = float(volunteer_meta.total_hours_accrued) if volunteer_meta else 0.0

    return UserCommunityJourneyOut(
        events_attended=events_attended,
        issues_helped=issues_helped,
        blood_donations=blood_donations,
        trees_planted=trees_planted,
        sports_matches_played=int(sports_matches),
        volunteer_hours=volunteer_hours
    )


@router.post("/{user_id}/block")
def block_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Block another user to stop seeing their posts."""
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    target = db.query(User).filter(
        User.id == user_id,
        User.organization_id == tenant_id
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
        
    existing = db.query(UserBlock).filter(
        UserBlock.blocker_id == current_user.id,
        UserBlock.blocked_id == user_id,
        UserBlock.organization_id == tenant_id
    ).first()
    
    if not existing:
        from sqlalchemy.exc import IntegrityError
        block = UserBlock(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            blocker_id=current_user.id,
            blocked_id=user_id,
        )
        db.add(block)
        try:
            db.commit()
        except IntegrityError:
            # Concurrent double-tap already inserted the same block — the
            # UniqueConstraint(blocker_id, blocked_id) fired. Treat as success.
            db.rollback()
    return {"status": "blocked"}
