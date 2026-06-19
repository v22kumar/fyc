from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.opportunity import Opportunity, OpportunityApplication
from app.models.user import User
from app.models.audit import AuditLog
from app.schemas.opportunity import OpportunityCreate, OpportunityUpdate, OpportunityOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/opportunities", tags=["Opportunities"])

require_manager = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


@router.get("", response_model=List[OpportunityOut])
def list_opportunities(
    type: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Public list of active opportunities. Filter by ?type=VOLUNTEER or ?type=COURSE."""
    query = db.query(Opportunity).filter(
        Opportunity.organization_id == tenant_id,
        Opportunity.is_active == True,
    )
    if type:
        query = query.filter(Opportunity.type == type.upper())
    return query.order_by(Opportunity.created_at.desc()).all()


@router.post("", response_model=OpportunityOut, status_code=status.HTTP_201_CREATED)
def create_opportunity(
    payload: OpportunityCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    """Create a new opportunity (EXECUTIVE_MEMBER, ADMIN, SUPER_ADMIN only)."""
    opp = Opportunity(
        organization_id=current_user.organization_id,
        type=payload.type,
        title_ta=payload.title_ta,
        title_en=payload.title_en,
        organizer_ta=payload.organizer_ta,
        organizer_en=payload.organizer_en,
        hours=payload.hours,
        category_ta=payload.category_ta,
        category_en=payload.category_en,
        location_ta=payload.location_ta,
        location_en=payload.location_en,
        description_ta=payload.description_ta,
        description_en=payload.description_en,
        is_active=payload.is_active,
    )
    db.add(opp)
    db.commit()
    db.refresh(opp)
    return opp


@router.patch("/{opp_id}", response_model=OpportunityOut)
def update_opportunity(
    opp_id: UUID,
    payload: OpportunityUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    """Update an opportunity (EXECUTIVE_MEMBER, ADMIN, SUPER_ADMIN only)."""
    opp = db.query(Opportunity).filter(
        Opportunity.id == opp_id,
        Opportunity.organization_id == current_user.organization_id,
    ).first()
    if not opp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Opportunity not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(opp, field, value)
    db.commit()
    db.refresh(opp)
    return opp


@router.post("/{opp_id}/apply", status_code=status.HTTP_200_OK)
def apply_for_opportunity(
    opp_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Apply / enroll for an opportunity. Authenticated users only.
    Duplicate applications are silently ignored so the UI can retry safely.
    """
    opp = db.query(Opportunity).filter(
        Opportunity.id == opp_id,
        Opportunity.organization_id == tenant_id,
        Opportunity.is_active == True,
    ).first()
    if not opp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Opportunity not found")

    existing = db.query(OpportunityApplication).filter(
        OpportunityApplication.opportunity_id == opp_id,
        OpportunityApplication.user_id == current_user.id,
    ).first()
    if not existing:
        db.add(OpportunityApplication(
            opportunity_id=opp_id,
            user_id=current_user.id,
            organization_id=tenant_id,
        ))
        db.add(AuditLog(
            organization_id=tenant_id,
            user_id=current_user.id,
            action_type="OPPORTUNITY_APPLY",
            target_table="opportunities",
            target_id=opp_id,
            new_values={"opportunity_id": str(opp_id), "type": opp.type},
        ))
        db.commit()

    return {"message": "Application submitted successfully.", "opportunity_id": str(opp_id)}
