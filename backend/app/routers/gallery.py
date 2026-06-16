from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.gallery import EventPhoto
from app.models.event import Event
from app.models.user import User
from app.schemas.gallery import PhotoCreate, PhotoOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/gallery", tags=["Gallery"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


@router.get("", response_model=List[PhotoOut])
def list_photos(
    event_id: Optional[UUID] = None,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    List photos across all events for the current tenant (public).
    Optionally filter by ?event_id=<uuid>.
    Results are returned newest first.
    """
    query = db.query(EventPhoto).filter(EventPhoto.organization_id == tenant_id)
    if event_id:
        query = query.filter(EventPhoto.event_id == event_id)
    return query.order_by(EventPhoto.created_at.desc()).all()


@router.get("/events/{event_id}", response_model=List[PhotoOut])
def list_photos_for_event(
    event_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """List all photos belonging to a specific event (public), scoped to current tenant."""
    query = db.query(EventPhoto).filter(
        EventPhoto.event_id == event_id,
        EventPhoto.organization_id == tenant_id,
    )
    return query.order_by(EventPhoto.created_at.desc()).all()


@router.post(
    "/events/{event_id}",
    response_model=PhotoOut,
    status_code=status.HTTP_201_CREATED,
)
def upload_photo(
    event_id: UUID,
    payload: PhotoCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload a photo to an event (any authenticated user).
    The event must belong to the same tenant as the uploading user.
    """
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id,
    ).first()
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )

    photo = EventPhoto(
        organization_id=current_user.organization_id,
        event_id=event_id,
        uploaded_by_user_id=current_user.id,
        photo_url=payload.photo_url,
        caption_ta=payload.caption_ta,
        caption_en=payload.caption_en,
        taken_at=payload.taken_at,
    )
    db.add(photo)
    db.commit()
    db.refresh(photo)
    return photo


@router.delete("/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_photo(
    photo_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Delete a photo. Allowed for:
    - The user who originally uploaded it, OR
    - Any ADMIN / SUPER_ADMIN in the same tenant.
    Returns 204 No Content on success.
    """
    photo = db.query(EventPhoto).filter(
        EventPhoto.id == photo_id,
        EventPhoto.organization_id == current_user.organization_id,
    ).first()
    if not photo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo not found",
        )

    is_uploader = photo.uploaded_by_user_id == current_user.id
    is_admin = current_user.role in ("ADMIN", "SUPER_ADMIN")

    if not (is_uploader or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to delete this photo.",
        )

    db.delete(photo)
    db.commit()
