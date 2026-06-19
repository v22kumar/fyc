from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker
from app.models.club_request import ClubMemberRequest
from app.models.user import User, UserProfile

router = APIRouter(prefix="/club-requests", tags=["Club Member Requests"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


# ---------------------------------------------------------------------------
# Response schema
# ---------------------------------------------------------------------------

class ClubRequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    full_name_en: str
    full_name_ta: str
    phone_number: Optional[str]
    requested_at: datetime
    status: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("", response_model=List[ClubRequestOut])
def list_pending_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    List all PENDING club-member requests for the admin's organisation.
    Joins UserProfile to include name and phone fields.
    ADMIN / SUPER_ADMIN only.
    """
    rows = (
        db.query(ClubMemberRequest, UserProfile, User)
        .join(User, ClubMemberRequest.user_id == User.id)
        .join(UserProfile, UserProfile.user_id == User.id)
        .filter(
            ClubMemberRequest.organization_id == current_user.organization_id,
            ClubMemberRequest.status == "PENDING",
        )
        .order_by(ClubMemberRequest.requested_at.asc())
        .all()
    )

    result = []
    for req, profile, user in rows:
        result.append(ClubRequestOut(
            id=req.id,
            user_id=req.user_id,
            full_name_en=profile.full_name_en,
            full_name_ta=profile.full_name_ta,
            phone_number=user.phone_number,
            requested_at=req.requested_at,
            status=req.status,
        ))
    return result


@router.post("/{request_id}/approve", response_model=ClubRequestOut)
def approve_request(
    request_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Approve a pending club-member request.
    Sets request status=APPROVED, upgrades the applicant's role to CLUB_MEMBER,
    and records the reviewer info.
    ADMIN / SUPER_ADMIN only.
    """
    req, profile, user = _get_request_with_join(db, request_id, current_user.organization_id)

    if req.status != "PENDING":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Request is already {req.status}.",
        )

    now = datetime.now(timezone.utc)
    req.status = "APPROVED"
    req.reviewed_by_user_id = current_user.id
    req.reviewed_at = now

    user.role = "CLUB_MEMBER"

    db.commit()
    db.refresh(req)

    return ClubRequestOut(
        id=req.id,
        user_id=req.user_id,
        full_name_en=profile.full_name_en,
        full_name_ta=profile.full_name_ta,
        phone_number=user.phone_number,
        requested_at=req.requested_at,
        status=req.status,
    )


@router.post("/{request_id}/reject", response_model=ClubRequestOut)
def reject_request(
    request_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Reject a pending club-member request.
    Sets request status=REJECTED and records the reviewer info.
    The user's role remains PUBLIC_CITIZEN.
    ADMIN / SUPER_ADMIN only.
    """
    req, profile, user = _get_request_with_join(db, request_id, current_user.organization_id)

    if req.status != "PENDING":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Request is already {req.status}.",
        )

    now = datetime.now(timezone.utc)
    req.status = "REJECTED"
    req.reviewed_by_user_id = current_user.id
    req.reviewed_at = now

    db.commit()
    db.refresh(req)

    return ClubRequestOut(
        id=req.id,
        user_id=req.user_id,
        full_name_en=profile.full_name_en,
        full_name_ta=profile.full_name_ta,
        phone_number=user.phone_number,
        requested_at=req.requested_at,
        status=req.status,
    )


# ---------------------------------------------------------------------------
# Internal helper
# ---------------------------------------------------------------------------

def _get_request_with_join(
    db: Session,
    request_id: UUID,
    organization_id: UUID,
):
    """Fetch a ClubMemberRequest + associated UserProfile + User, scoped to the org."""
    row = (
        db.query(ClubMemberRequest, UserProfile, User)
        .join(User, ClubMemberRequest.user_id == User.id)
        .join(UserProfile, UserProfile.user_id == User.id)
        .filter(
            ClubMemberRequest.id == request_id,
            ClubMemberRequest.organization_id == organization_id,
        )
        .first()
    )
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Club member request not found.",
        )
    return row
