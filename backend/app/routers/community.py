from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.community import CommunityProfile
from app.models.user import User, UserProfile
from app.schemas.community import CommunityProfileRegister, CommunityProfileUpdate, CommunityProfileOut, CommunityFeedItem, CommunityStatsOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id
from app.models.event import Event
from app.models.sports import Tournament
from app.models.issue import PublicIssue
from app.models.announcement import Announcement

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


@router.get("/feed", response_model=List[CommunityFeedItem])
def get_community_feed(
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    feed = []

    # NOTE: a dedicated News source was removed here — there is no News model
    # in the schema. The home feed aggregates Events, Tournaments and resolved
    # Issues. (Public news on the website is sourced separately from Google RSS.)

    # Events
    events = db.query(Event).filter(Event.organization_id == tenant_id, Event.is_published == True).order_by(Event.event_start.desc()).offset(offset).limit(limit).all()
    for e in events:
        feed.append(CommunityFeedItem(
            item_type="EVENT",
            id=str(e.id),
            title_en=e.title_en,
            title_ta=e.title_ta,
            subtitle_en=e.description_en[:100] if e.description_en else "",
            subtitle_ta=e.description_ta[:100] if e.description_ta else "",
            image_url=e.banner_url,
            created_at=e.created_at.isoformat()
        ))
        
    # 3. Sports Tournaments
    sports = db.query(Tournament).filter(Tournament.organization_id == tenant_id, Tournament.status.in_(["PUBLISHED", "ONGOING"])).order_by(Tournament.created_at.desc()).offset(offset).limit(limit).all()
    for s in sports:
        feed.append(CommunityFeedItem(
            item_type="TOURNAMENT",
            id=str(s.id),
            title_en=s.name_en,
            title_ta=s.name_ta,
            subtitle_en=f"Sport: {s.sport}",
            subtitle_ta=f"விளையாட்டு: {s.sport}",
            image_url=None,
            created_at=s.created_at.isoformat()
        ))
        
    # 4. Public Issues
    issues = db.query(PublicIssue).filter(PublicIssue.organization_id == tenant_id, PublicIssue.status.in_(["RESOLVED", "CLOSED"])).order_by(PublicIssue.updated_at.desc()).offset(offset).limit(limit).all()
    for i in issues:
        feed.append(CommunityFeedItem(
            item_type="ISSUE",
            id=str(i.id),
            title_en="Issue Resolved",
            title_ta="பிரச்சனை தீர்க்கப்பட்டது",
            subtitle_en=i.description_en[:100] if i.description_en else "",
            subtitle_ta=i.description_ta[:100] if i.description_ta else "",
            image_url=i.verification_photo_url or i.photo_url,
            created_at=i.updated_at.isoformat()
        ))

    # Sort all feed items by date desc and return the paginated slice
    feed.sort(key=lambda x: x.created_at, reverse=True)
    # We slice again because we gathered `limit` from each category, meaning we have up to 4*limit items.
    return feed[:limit]

@router.get("/stats", response_model=CommunityStatsOut)
def get_community_stats(
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    from app.models.user import User
    from app.models.blood_donor import BloodDonor
    from app.models.green_fyc import TreeRegistration
    
    total_volunteers = db.query(User).filter(
        User.organization_id == tenant_id,
        User.role == "VOLUNTEER"
    ).count()
    
    total_events = db.query(Event).filter(
        Event.organization_id == tenant_id,
        Event.is_published == True
    ).count()
    
    total_blood_donations = db.query(BloodDonor).filter(
        BloodDonor.organization_id == tenant_id
    ).count()
    
    total_trees_planted = db.query(TreeRegistration).filter(
        TreeRegistration.organization_id == tenant_id
    ).count()
    
    total_issues_solved = db.query(PublicIssue).filter(
        PublicIssue.organization_id == tenant_id,
        PublicIssue.status == "RESOLVED"
    ).count()
    
    return CommunityStatsOut(
        total_volunteers=total_volunteers,
        total_events=total_events,
        total_blood_donations=total_blood_donations,
        total_trees_planted=total_trees_planted,
        total_issues_solved=total_issues_solved
    )


@router.get("", response_model=List[CommunityProfileOut])
def search_directory(
    category: Optional[str] = None,
    service_area: Optional[str] = None,
    available_only: bool = True,
    verified_only: bool = False,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    q = db.query(CommunityProfile).filter(CommunityProfile.organization_id == tenant_id)
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
    existing = db.query(CommunityProfile).filter(CommunityProfile.user_id == current_user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="You already have a community profile. Use PATCH /me to update it.")
    profile = CommunityProfile(
        id=uuid.uuid4(),
        organization_id=current_user.organization_id,
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
def get_profile(
    profile_id: str,
    db: Session = Depends(get_db),
    tenant_id: uuid.UUID = Depends(require_tenant_id),
):
    profile = db.query(CommunityProfile).filter(
        CommunityProfile.id == profile_id,
        CommunityProfile.organization_id == tenant_id,
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    return _build_out(profile, db)


@router.patch("/{profile_id}/verify", response_model=CommunityProfileOut)
def verify_profile(
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    profile = db.query(CommunityProfile).filter(
        CommunityProfile.id == profile_id,
        CommunityProfile.organization_id == current_user.organization_id,
    ).first()
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
    profile = db.query(CommunityProfile).filter(
        CommunityProfile.id == profile_id,
        CommunityProfile.organization_id == current_user.organization_id,
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    db.delete(profile)
    db.commit()
