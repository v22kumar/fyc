from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.community import CommunityProfile
from app.models.user import User, UserProfile
from app.schemas.community import CommunityProfileRegister, CommunityProfileUpdate, CommunityProfileOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import get_current_tenant_id

router = APIRouter(prefix="/community", tags=["Community Directory"])

require_member = RoleChecker(["PUBLIC_CITIZEN", "VOLUNTEER", "CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


def _build_out(profile: CommunityProfile, db: Session) -> CommunityProfileOut:
    up = db.query(UserProfile).filter(UserProfile.user_id == profile.user_id).first()
    return CommunityProfileOut(
        id=profile.id,
        user_id=profile.user_id,
        category=profile.category,
        business_name_ta=profile.business_name_ta,
        business_name_en=profile.business_name_en,
        description_ta=profile.description_ta,
        description_en=profile.description_en,
        contact_phone=profile.contact_phone,
        contact_whatsapp=profile.contact_whatsapp,
        service_area=profile.service_area,
        years_experience=profile.years_experience,
        is_available=profile.is_available,
        is_verified=profile.is_verified,
        full_name_en=up.full_name_en if up else None,
        full_name_ta=up.full_name_ta if up else None,
    )


@router.get("", response_model=List[CommunityProfileOut])
def search_directory(
    category: Optional[str] = None,
    service_area: Optional[str] = None,
    available_only: bool = True,
    verified_only: bool = False,
    db: Session = Depends(get_db),
):
    tenant_id = get_current_tenant_id()
    q = db.query(CommunityProfile)
    if tenant_id:
        q = q.filter(CommunityProfile.organization_id == tenant_id)
    if category:
        q = q.filter(CommunityProfile.category == category.lower())
    if service_area:
        q = q.filter(CommunityProfile.service_area.ilike(f"%{service_area}%"))
    if available_only:
        q = q.filter(CommunityProfile.is_available == True)
    if verified_only:
        q = q.filter(CommunityProfile.is_verified == True)
    return [_build_out(p, db) for p in q.all()]


@router.post("/register", response_model=CommunityProfileOut, status_code=status.HTTP_201_CREATED)
def register_profile(
    payload: CommunityProfileRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member),
):
    tenant_id = get_current_tenant_id()
    existing = db.query(CommunityProfile).filter(CommunityProfile.user_id == current_user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="You already have a community profile. Use PATCH /me to update it.")
    profile = CommunityProfile(
        id=uuid.uuid4(),
        organization_id=tenant_id,
        user_id=current_user.id,
        **payload.model_dump(exclude_none=False),
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return _build_out(profile, db)


@router.get("/me", response_model=CommunityProfileOut)
def get_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member),
):
    profile = db.query(CommunityProfile).filter(CommunityProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="No community profile found. Register first.")
    return _build_out(profile, db)


@router.patch("/me", response_model=CommunityProfileOut)
def update_my_profile(
    payload: CommunityProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member),
):
    profile = db.query(CommunityProfile).filter(CommunityProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="No profile found.")
    for k, v in payload.model_dump(exclude_none=True).items():
        setattr(profile, k, v)
    db.commit()
    db.refresh(profile)
    return _build_out(profile, db)


@router.get("/{profile_id}", response_model=CommunityProfileOut)
def get_profile(profile_id: str, db: Session = Depends(get_db)):
    profile = db.query(CommunityProfile).filter(CommunityProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    return _build_out(profile, db)


@router.patch("/{profile_id}/verify", response_model=CommunityProfileOut)
def verify_profile(
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    profile = db.query(CommunityProfile).filter(CommunityProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    profile.is_verified = not profile.is_verified
    db.commit()
    db.refresh(profile)
    return _build_out(profile, db)


@router.delete("/{profile_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_profile(
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    profile = db.query(CommunityProfile).filter(CommunityProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    db.delete(profile)
    db.commit()
