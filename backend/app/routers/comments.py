from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.core_services import Comment
from app.models.user import User

router = APIRouter(prefix="/comments", tags=["Comments"])

class CommentCreatePayload(BaseModel):
    entity_type: str
    entity_id: UUID
    content: str

class CommentOut(BaseModel):
    id: UUID
    author_id: UUID
    entity_type: str
    entity_id: UUID
    content: str
    created_at: datetime

    class Config:
        from_attributes = True

@router.post("", response_model=CommentOut)
def create_comment(
    payload: CommentCreatePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add a lightweight comment to any entity."""
    comment = Comment(
        organization_id=current_user.organization_id,
        author_id=current_user.id,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        content=payload.content
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return comment

@router.get("/{entity_type}/{entity_id}", response_model=List[CommentOut])
def list_comments(
    entity_type: str,
    entity_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id)
):
    """List comments for an entity."""
    return db.query(Comment).filter(
        Comment.organization_id == tenant_id,
        Comment.entity_type == entity_type,
        Comment.entity_id == entity_id
    ).order_by(Comment.created_at.asc()).all()

@router.delete("/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment(
    comment_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a comment."""
    comment = db.query(Comment).filter(
        Comment.id == comment_id,
        Comment.organization_id == current_user.organization_id
    ).first()
    
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
        
    if comment.author_id != current_user.id and current_user.role not in ["ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER"]:
        raise HTTPException(status_code=403, detail="Not authorized to delete this comment")
        
    db.delete(comment)
    db.commit()
