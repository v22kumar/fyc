from typing import List, Optional
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.announcement import Announcement, AnnouncementCategory
from app.models.user import User
from app.schemas.announcement import AnnouncementCreate, AnnouncementUpdate, AnnouncementOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/announcements", tags=["Announcements"])

require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


@router.get("", response_model=List[AnnouncementOut])
def list_announcements(
    category: Optional[AnnouncementCategory] = None,
    include_expired: bool = False,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    List announcements for the current tenant (public, no auth required).
    By default only active (non-expired) items are returned.
    Results are ordered pinned-first, then by newest created_at.
    Pass ?include_expired=true to see all records regardless of expiry.
    """
    query = db.query(Announcement).filter(Announcement.organization_id == tenant_id)
    if category:
        query = query.filter(Announcement.category == category)
    if not include_expired:
        now = datetime.now(timezone.utc)
        query = query.filter(
            (Announcement.expires_at == None) | (Announcement.expires_at > now)
        )
    announcements = query.order_by(
        Announcement.is_pinned.desc(),
        Announcement.created_at.desc(),
    ).all()
    return announcements


@router.get("/{announcement_id}", response_model=AnnouncementOut)
def get_announcement(
    announcement_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Retrieve a single announcement by ID, scoped to current tenant (public)."""
    announcement = db.query(Announcement).filter(
        Announcement.id == announcement_id,
        Announcement.organization_id == tenant_id,
    ).first()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found",
        )
    return announcement


@router.post("", response_model=AnnouncementOut, status_code=status.HTTP_201_CREATED)
def create_announcement(
    payload: AnnouncementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive),
):
    """Create a new announcement (Executive Member, Admin, or Super Admin)."""
    announcement = Announcement(
        organization_id=current_user.organization_id,
        title_ta=payload.title_ta,
        title_en=payload.title_en,
        body_ta=payload.body_ta,
        body_en=payload.body_en,
        category=payload.category,
        is_pinned=payload.is_pinned,
        expires_at=payload.expires_at,
        banner_url=payload.banner_url,
        geography_id=payload.geography_id,
        created_by_user_id=current_user.id,
    )
    db.add(announcement)
    db.commit()
    db.refresh(announcement)
    return announcement


@router.patch("/{announcement_id}", response_model=AnnouncementOut)
def update_announcement(
    announcement_id: UUID,
    payload: AnnouncementUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive),
):
    """Update an announcement (Executive Member, Admin, or Super Admin)."""
    announcement = db.query(Announcement).filter(
        Announcement.id == announcement_id,
        Announcement.organization_id == current_user.organization_id,
    ).first()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found",
        )

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(announcement, field, value)

    db.commit()
    db.refresh(announcement)
    return announcement


@router.delete("/{announcement_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_announcement(
    announcement_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Permanently delete an announcement (Admin / Super Admin only).
    Returns 204 No Content on success.
    """
    announcement = db.query(Announcement).filter(
        Announcement.id == announcement_id,
        Announcement.organization_id == current_user.organization_id,
    ).first()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found",
        )

    db.delete(announcement)
    db.commit()
