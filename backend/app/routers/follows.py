from typing import List, Any
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.dependencies import get_current_user
from app.models.core_services import Follow
from app.models.user import User

router = APIRouter(prefix="/follows", tags=["Follows"])

class FollowTogglePayload(BaseModel):
    entity_type: str
    entity_id: UUID

class FollowOut(BaseModel):
    id: UUID
    user_id: UUID
    entity_type: str
    entity_id: UUID

    class Config:
        from_attributes = True

@router.post("/toggle", response_model=FollowOut)
def toggle_follow(
    payload: FollowTogglePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Toggle following an entity."""
    existing = db.query(Follow).filter(
        Follow.user_id == current_user.id,
        Follow.entity_type == payload.entity_type,
        Follow.entity_id == payload.entity_id
    ).first()

    if existing:
        db.delete(existing)
        db.commit()
        return existing
    else:
        follow = Follow(
            organization_id=current_user.organization_id,
            user_id=current_user.id,
            entity_type=payload.entity_type,
            entity_id=payload.entity_id
        )
        db.add(follow)
        db.commit()
        db.refresh(follow)
        return follow

@router.get("/me", response_model=List[FollowOut])
def get_my_follows(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all entities followed by the user."""
    return db.query(Follow).filter(Follow.user_id == current_user.id).all()
