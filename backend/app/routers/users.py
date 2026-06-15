from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker
from app.models.user import User, UserProfile
from app.schemas.auth import UserOut
from app.middleware.tenant import get_current_tenant_id
from pydantic import BaseModel, ConfigDict
from uuid import UUID

router = APIRouter(prefix="/users", tags=["Users"])

require_admin = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


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
