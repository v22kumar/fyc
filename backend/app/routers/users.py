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
    email: Optional[str] = None
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
            email=user.email or "",
            role=user.role,
            is_verified=user.is_verified,
            preferred_language=user.preferred_language,
            full_name_ta=profile.full_name_ta if profile else None,
            full_name_en=profile.full_name_en if profile else None,
        )
        for user, profile in rows
    ]


class MemberRosterOut(BaseModel):
    """Safe, member-facing roster row — names, role and photo only. Never
    exposes phone, email, DOB or address."""
    id: UUID
    full_name_ta: Optional[str] = None
    full_name_en: Optional[str] = None
    role: str
    profile_image_url: Optional[str] = None


# Seniority order for display (most senior first); anything unlisted sorts last.
_ROLE_RANK = {
    "SUPER_ADMIN": 0,
    "ADMIN": 1,
    "EXECUTIVE_MEMBER": 2,
    "CLUB_MEMBER": 3,
    "VOLUNTEER": 4,
}


@router.get("/roster", response_model=List[MemberRosterOut])
def member_roster(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Club member roster visible to any signed-in member: names, role and
    photo only (no contact details). Lists verified club members and excludes
    plain app users (PUBLIC_CITIZEN), ordered by seniority then name.
    """
    rows = (
        db.query(User, UserProfile)
        .outerjoin(UserProfile, UserProfile.user_id == User.id)
        .filter(
            User.organization_id == tenant_id,
            User.is_verified == True,  # noqa: E712
            User.role != "PUBLIC_CITIZEN",
        )
        .all()
    )
    members = [
        MemberRosterOut(
            id=user.id,
            full_name_ta=profile.full_name_ta if profile else None,
            full_name_en=profile.full_name_en if profile else None,
            role=user.role,
            profile_image_url=profile.profile_image_url if profile else None,
        )
        for user, profile in rows
    ]
    members.sort(key=lambda m: (
        _ROLE_RANK.get(m.role, 99),
        (m.full_name_en or m.full_name_ta or "").lower(),
    ))
    return members


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
    wedding_anniversary: Optional[date] = None
    celebrate_publicly: Optional[bool] = None


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
    if payload.wedding_anniversary is not None:
        profile.wedding_anniversary = payload.wedding_anniversary
    if payload.celebrate_publicly is not None:
        profile.celebrate_publicly = payload.celebrate_publicly

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


class CreateUserPayload(BaseModel):
    phone_number: Optional[str] = None
    email: Optional[str] = None
    role: str
    full_name_ta: str
    full_name_en: str
    preferred_language: Optional[str] = "en"


@router.post("", response_model=UserWithProfile, status_code=status.HTTP_201_CREATED)
def create_user_by_admin(
    payload: CreateUserPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Admin: directly create a new user and profile."""
    if payload.role not in PROMOTABLE_ROLES and payload.role != "SUPER_ADMIN":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Must be one of: {', '.join(PROMOTABLE_ROLES)}",
        )

    if payload.phone_number:
        # Check if phone number is unique within organization
        existing = db.query(User).filter(
            User.organization_id == current_user.organization_id,
            User.phone_number == payload.phone_number,
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A user with this phone number already exists in the organization.",
            )

    new_user = User(
        phone_number=payload.phone_number,
        email=payload.email,
        role=payload.role,
        organization_id=current_user.organization_id,
        is_verified=True,
        preferred_language=payload.preferred_language or "en",
    )
    db.add(new_user)
    db.flush()

    profile = UserProfile(
        user_id=new_user.id,
        full_name_ta=payload.full_name_ta,
        full_name_en=payload.full_name_en,
    )
    db.add(profile)

    if payload.role == "VOLUNTEER":
        volunteer_meta = VolunteerMetadata(
            user_id=new_user.id,
            skills=[],
            availability_status="AVAILABLE",
            total_hours_accrued=0.00,
        )
        db.add(volunteer_meta)

    db.commit()
    db.refresh(new_user)
    db.refresh(profile)

    return UserWithProfile(
        id=new_user.id,
        phone_number=new_user.phone_number or "",
        email=new_user.email or "",
        role=new_user.role,
        is_verified=new_user.is_verified,
        preferred_language=new_user.preferred_language,
        full_name_ta=profile.full_name_ta,
        full_name_en=profile.full_name_en,
    )


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


class AdminBlockPayload(_BaseModel):
    is_blocked: bool


@router.post("/{user_id}/admin-block")
def admin_block_user(
    user_id: UUID,
    payload: AdminBlockPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Admin: block or unblock a user from logging into the platform."""
    target = db.query(User).filter(
        User.id == user_id,
        User.organization_id == current_user.organization_id,
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if target.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
        
    target.is_blocked = payload.is_blocked
    # If blocking, bump token version to revoke existing sessions immediately
    if payload.is_blocked:
        target.token_version = int(target.token_version or 0) + 1
        
    db.commit()
    return {"ok": True, "user_id": str(user_id), "is_blocked": target.is_blocked}

# ── Celebrations & the member card ────────────────────────────────────────────
#
# The plan, decided deliberately (see the feature ask): a birthday and a
# wedding anniversary recur every year and the club remembers them FOR the
# member. Where cards appear: the member's own notification (always), the
# club's celebration list and Home card (only when celebrate_publicly), and
# the feed (only if the member chooses to share). Where they never appear:
# ages and years — day and month leave the profile, the year does not.

class CelebrationOut(_BaseModel):
    user_id: uuid.UUID
    full_name_ta: str
    full_name_en: str
    kind: str  # 'birthday' | 'anniversary'
    # Anniversaries carry their ordinal — a 10th anniversary IS the story,
    # and the member typed the year in themselves. Birthdays never carry
    # one: an age is nobody's announcement to make.
    years: Optional[int] = None
    is_milestone: bool = False


# The years a Tamil household marks with a function, not just a wish.
_MILESTONES = {1, 5, 10, 15, 20, 25, 30, 40, 50, 60}


@router.get("/celebrations/today", response_model=List[CelebrationOut])
def celebrations_today(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Who is celebrating today, org-scoped, opt-outs respected."""
    today = datetime.date.today()
    rows = (
        db.query(User, UserProfile)
        .join(UserProfile, UserProfile.user_id == User.id)
        .filter(
            User.organization_id == current_user.organization_id,
            # NULL (never chose) counts as public; only explicit False hides.
            UserProfile.celebrate_publicly.isnot(False),
        )
        .all()
    )
    out: list[CelebrationOut] = []
    for user, profile in rows:
        for field, kind in ((profile.date_of_birth, "birthday"),
                            (profile.wedding_anniversary, "anniversary")):
            if field is None:
                continue
            # Feb-29 celebrants are wished on Mar-1 in ordinary years rather
            # than skipped for three years out of four.
            matches = (field.month == today.month and field.day == today.day)
            if not matches and field.month == 2 and field.day == 29:
                matches = today.month == 3 and today.day == 1 and not _is_leap(today.year)
            if matches:
                years = (today.year - field.year) if kind == "anniversary" else None
                out.append(CelebrationOut(
                    user_id=user.id,
                    full_name_ta=profile.full_name_ta or "",
                    full_name_en=profile.full_name_en or "",
                    kind=kind,
                    years=years,
                    is_milestone=bool(years in _MILESTONES),
                ))
    return out


def _is_leap(year: int) -> bool:
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)


class MemberCardOut(_BaseModel):
    user_id: uuid.UUID
    full_name_ta: str
    full_name_en: str
    role: str
    profile_image_url: Optional[str] = None
    member_since: Optional[datetime.date] = None
    # Day-and-month only, when the member celebrates publicly. Never a year.
    birthday_day_month: Optional[str] = None      # e.g. '09-08' (MM-DD)
    anniversary_day_month: Optional[str] = None
    is_birthday_today: bool = False
    is_anniversary_today: bool = False
    anniversary_years: Optional[int] = None
    events_attended: int = 0
    blood_donations: int = 0
    trees_planted: int = 0
    sports_matches_played: int = 0


@router.get("/{user_id}/card", response_model=MemberCardOut)
def member_card(
    user_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The minimal public profile — what one member may know about another.

    Deliberately excluded: phone, email, address, blood group, gender, age.
    Contact flows exist elsewhere with their own consent steps (the blood
    ask-a-donor exchange); the card is a face and a community record."""
    row = (
        db.query(User, UserProfile)
        .join(UserProfile, UserProfile.user_id == User.id)
        .filter(
            User.id == user_id,
            User.organization_id == current_user.organization_id,
        )
        .first()
    )
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Member not found")
    user, profile = row

    from app.models.event import EventAttendance
    from app.models.blood_donor import BloodDonor
    from app.models.green_fyc import TreeRegistration
    from app.models.sports import Player
    from sqlalchemy.sql import func

    today = datetime.date.today()

    def _dm(d):
        return f"{d.month:02d}-{d.day:02d}" if d else None

    public = profile.celebrate_publicly is not False
    dob = profile.date_of_birth
    ann = profile.wedding_anniversary
    return MemberCardOut(
        user_id=user.id,
        full_name_ta=profile.full_name_ta or "",
        full_name_en=profile.full_name_en or "",
        role=user.role,
        profile_image_url=profile.profile_image_url,
        member_since=user.created_at.date() if user.created_at else None,
        birthday_day_month=_dm(dob) if public else None,
        anniversary_day_month=_dm(ann) if public else None,
        is_birthday_today=bool(public and dob and dob.month == today.month
                               and dob.day == today.day),
        is_anniversary_today=bool(public and ann and ann.month == today.month
                                  and ann.day == today.day),
        anniversary_years=(today.year - ann.year)
            if (public and ann and ann.month == today.month
                and ann.day == today.day) else None,
        events_attended=db.query(EventAttendance)
            .filter(EventAttendance.user_id == user.id).count(),
        blood_donations=db.query(BloodDonor)
            .filter(BloodDonor.user_id == user.id).count(),
        trees_planted=db.query(TreeRegistration)
            .filter(TreeRegistration.registered_by_user_id == user.id).count(),
        sports_matches_played=int(
            db.query(func.sum(Player.matches_played))
            .filter(Player.user_id == user.id).scalar() or 0),
    )
