from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker, get_current_user
from app.core.people import real_people
from app.models.club_request import ClubMemberRequest
from app.models.user import User, UserProfile

router = APIRouter(prefix="/club-requests", tags=["Club Member Requests"])

# Who may let somebody into the club.
#
# Executive members carry this now as well as admins. Approving is not a
# privileged act in the way spending money is — it is recognising a neighbour —
# and holding every request until one of two people looks at it means a member
# who joined on Saturday is still waiting on Tuesday.
require_approver = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


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
    current_user: User = Depends(require_approver),
):
    """
    List all PENDING club-member requests for the admin's organisation.
    Joins UserProfile to include name and phone fields.
    Executive members, admins and super admins.
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
    current_user: User = Depends(require_approver),
):
    """
    Approve a pending club-member request.
    Sets request status=APPROVED, upgrades the applicant's role to CLUB_MEMBER,
    and records the reviewer info.
    Executive members, admins and super admins.
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
    current_user: User = Depends(require_approver),
):
    """
    Reject a pending club-member request.
    Sets request status=REJECTED and records the reviewer info.
    The user's role remains PUBLIC_CITIZEN.
    Executive members, admins and super admins.
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


# ── The member's own side of this ───────────────────────────────────────────
#
# Until now a request could only be made at registration, in a role dropdown.
# Somebody who signed in with Google — which is most people, and the whole
# point of that road existing — had no way to say "I am a club member" at all,
# and no way to learn what had become of it if they had. Both roads need the
# same two things: a way to ask, and a way to see the answer.

class MyMembershipOut(BaseModel):
    """Where the signed-in member stands. Never raises; 'NONE' is an answer."""
    status: str            # NONE | PENDING | APPROVED | REJECTED
    role: str
    is_member: bool
    can_request: bool
    requested_at: Optional[datetime] = None


def _latest_request(db: Session, user: User) -> Optional[ClubMemberRequest]:
    return (
        db.query(ClubMemberRequest)
        .filter(
            ClubMemberRequest.user_id == user.id,
            ClubMemberRequest.organization_id == user.organization_id,
        )
        .order_by(ClubMemberRequest.requested_at.desc())
        .first()
    )


MEMBER_ROLES = ("CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")


@router.get("/me", response_model=MyMembershipOut)
def my_membership(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """What this member should be shown: the prompt, the wait, or nothing."""
    already = current_user.role in MEMBER_ROLES
    req = _latest_request(db, current_user)
    status_str = "APPROVED" if already else (req.status if req else "NONE")
    return MyMembershipOut(
        status=status_str,
        role=current_user.role,
        is_member=already,
        # A rejected request can be made again — people are told no by mistake,
        # and a permanent dead end for a real member is the worse failure.
        can_request=not already and (req is None or req.status == "REJECTED"),
        requested_at=req.requested_at if req else None,
    )


@router.post("/me", response_model=MyMembershipOut, status_code=status.HTTP_201_CREATED)
def request_membership(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Ask to be recognised as a club member.

    Idempotent on purpose: a second tap while the first is pending returns the
    same pending request rather than stacking duplicates in the admin's queue —
    the queue is somebody's Saturday morning, and a member who taps twice
    should not cost them two decisions.
    """
    if current_user.role in MEMBER_ROLES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a club member.",
        )

    req = _latest_request(db, current_user)
    if req is not None and req.status == "PENDING":
        return MyMembershipOut(
            status="PENDING", role=current_user.role, is_member=False,
            can_request=False, requested_at=req.requested_at,
        )

    fresh = ClubMemberRequest(
        organization_id=current_user.organization_id,
        user_id=current_user.id,
        status="PENDING",
    )
    db.add(fresh)
    db.commit()
    db.refresh(fresh)
    return MyMembershipOut(
        status="PENDING", role=current_user.role, is_member=False,
        can_request=False, requested_at=fresh.requested_at,
    )


# ── Duplicates, reported and never deleted ─────────────────────────────────

class DuplicateAccountOut(BaseModel):
    user_id: UUID
    full_name_en: str
    phone_number: Optional[str]
    email: Optional[str]
    role: str
    created_at: Optional[datetime]
    is_verified: bool


class DuplicateGroupOut(BaseModel):
    """One person, appearing more than once."""
    key: str
    accounts: List[DuplicateAccountOut]


@router.get("/duplicates", response_model=List[DuplicateGroupOut])
def duplicate_members(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_approver),
):
    """Members who appear more than once, grouped — reported, never merged.

    One person is currently in the roster three times. Merging accounts is not
    reversible and only somebody who knows these people can say which row is
    the real one and which is a stray sign-in, so this reports and stops there:
    every account, with what each holds, so the decision is made by a human
    with the facts in front of them.

    Grouped by name, because that is what the duplicates share — the same
    person signing in by phone one day and Google the next has two rows with
    different identifiers and one name.
    """
    rows = (
        db.query(User, UserProfile)
        .join(UserProfile, UserProfile.user_id == User.id)
        .filter(
            User.organization_id == current_user.organization_id,
            real_people(User),
        )
        .all()
    )

    groups: dict[str, list] = {}
    for user, profile in rows:
        key = (profile.full_name_en or "").strip().lower()
        if not key:
            continue
        groups.setdefault(key, []).append((user, profile))

    out: List[DuplicateGroupOut] = []
    for key, members in sorted(groups.items()):
        if len(members) < 2:
            continue
        out.append(DuplicateGroupOut(
            key=key,
            accounts=[
                DuplicateAccountOut(
                    user_id=u.id,
                    full_name_en=pr.full_name_en,
                    phone_number=u.phone_number,
                    email=u.email,
                    role=u.role,
                    created_at=getattr(u, "created_at", None),
                    is_verified=bool(u.is_verified),
                )
                for u, pr in members
            ],
        ))
    return out
