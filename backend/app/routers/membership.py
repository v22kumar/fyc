import uuid
from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.user import User, MembershipCard
from app.schemas.membership import MembershipCardGenerate, MembershipCardOut
from app.dependencies import get_current_user, RoleChecker

router = APIRouter(prefix="/membership", tags=["Membership"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])
require_member = RoleChecker(["CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

def _next_membership_number(db: Session, org_id: UUID) -> str:
    year = datetime.utcnow().year
    count = db.query(MembershipCard).join(User, User.id == MembershipCard.user_id).filter(
        User.organization_id == org_id
    ).count()
    return f"FYC-{year}-{str(count + 1).zfill(4)}"

@router.post("/generate", response_model=MembershipCardOut, status_code=status.HTTP_201_CREATED)
def generate_membership_card(
    payload: MembershipCardGenerate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """
    Issue a digital membership card to a user (Admin / Super Admin only).
    Generates a unique membership number and QR payload.
    """
    target_user = db.query(User).filter(
        User.id == payload.user_id,
        User.organization_id == current_user.organization_id
    ).first()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found in this organization")

    existing_card = db.query(MembershipCard).filter(MembershipCard.user_id == payload.user_id).first()
    if existing_card:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already has a membership card"
        )

    membership_number = _next_membership_number(db, current_user.organization_id)
    qr_payload = f"FYC:{membership_number}:{str(payload.user_id)}"

    card = MembershipCard(
        user_id=payload.user_id,
        membership_number=membership_number,
        qr_code_payload=qr_payload,
        designation_ta=payload.designation_ta,
        designation_en=payload.designation_en,
        expires_at=payload.expires_at,
        status="ACTIVE"
    )
    db.add(card)
    db.commit()
    db.refresh(card)
    return card

@router.get("/my-card", response_model=MembershipCardOut)
def get_my_card(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member)
):
    """Retrieve the authenticated member's digital membership card."""
    card = db.query(MembershipCard).filter(MembershipCard.user_id == current_user.id).first()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No membership card found")
    return card

@router.get("/verify/{membership_number}", response_model=MembershipCardOut)
def verify_card(membership_number: str, db: Session = Depends(get_db)):
    """
    Public QR verification endpoint — confirms a membership card is valid and active.
    """
    card = db.query(MembershipCard).filter(
        MembershipCard.membership_number == membership_number
    ).first()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Membership card not found")
    if card.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Membership card is {card.status}"
        )
    return card
