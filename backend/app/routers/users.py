import datetime
from io import BytesIO
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user, RoleChecker
from app.models.user import User, UserProfile, VolunteerMetadata
from app.models.tenant import Organization
from app.schemas.auth import UserOut
from app.middleware.tenant import get_current_tenant_id
from app.services.certificates import generate_volunteer_certificate
from pydantic import BaseModel, ConfigDict
from uuid import UUID

router = APIRouter(prefix="/users", tags=["Users"])

require_admin = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_volunteer = RoleChecker(["VOLUNTEER"])


class UserWithProfile(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    phone_number: str
    role: str
    is_verified: bool
    preferred_language: str
    full_name_ta: Optional[str] = None
    full_name_en: Optional[str] = None


@router.get("", response_model=List[UserWithProfile])
def list_users(
    role: Optional[str] = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """List users in the current tenant, optionally filtered by role (admin only)."""
    tenant_id = get_current_tenant_id()
    query = db.query(User)
    if tenant_id:
        query = query.filter(User.organization_id == tenant_id)
    if role:
        query = query.filter(User.role == role.upper())

    users = query.order_by(User.role).all()

    result = []
    for user in users:
        profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
        result.append(
            UserWithProfile(
                id=user.id,
                phone_number=user.phone_number,
                role=user.role,
                is_verified=user.is_verified,
                preferred_language=user.preferred_language,
                full_name_ta=profile.full_name_ta if profile else None,
                full_name_en=profile.full_name_en if profile else None,
            )
        )
    return result


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
