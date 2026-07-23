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

import requests
import logging
from app.models.tenant import Organization
from app.models.post import Post

logger = logging.getLogger(__name__)

@router.post("", response_model=CommentOut)
def create_comment(
    payload: CommentCreatePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add a lightweight comment to any entity, and sync it to social media if applicable."""
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
    
    # Cross-Platform Comment Sync
    if payload.entity_type == "post":
        post = db.query(Post).filter(Post.id == payload.entity_id).first()
        if post and post.source in ["instagram", "threads"] and post.idempotency_key:
            org = db.query(Organization).filter(Organization.id == current_user.organization_id).first()
            if org:
                # Prepend the user's name since it will be posted from the business account
                full_name = "User"
                profile = current_user.profile
                if profile:
                    full_name = profile.full_name_en or profile.full_name_ta or "User"
                
                comment_text = f"{full_name}: {payload.content}"
                
                if post.source == "instagram" and org.instagram_access_token:
                    media_id = post.idempotency_key.replace("ig_", "")
                    try:
                        res = requests.post(
                            f"https://graph.facebook.com/v19.0/{media_id}/comments",
                            data={
                                "message": comment_text,
                                "access_token": org.instagram_access_token
                            }
                        )
                        if res.status_code != 200:
                            logger.error(f"Failed to sync IG comment: {res.text}")
                    except Exception as e:
                        logger.error(f"Error syncing IG comment: {e}")
                        
                elif post.source == "threads" and org.threads_access_token and org.threads_account_id:
                    media_id = post.idempotency_key.replace("threads_", "")
                    try:
                        # 1. Create Reply Container
                        c_res = requests.post(
                            f"https://graph.threads.net/v1.0/{org.threads_account_id}/threads",
                            data={
                                "media_type": "TEXT",
                                "text": comment_text,
                                "reply_to_id": media_id,
                                "access_token": org.threads_access_token
                            }
                        )
                        if c_res.status_code == 200:
                            creation_id = c_res.json().get("id")
                            # 2. Publish Reply Container
                            requests.post(
                                f"https://graph.threads.net/v1.0/{org.threads_account_id}/threads_publish",
                                data={
                                    "creation_id": creation_id,
                                    "access_token": org.threads_access_token
                                }
                            )
                        else:
                            logger.error(f"Failed to create Threads reply container: {c_res.text}")
                    except Exception as e:
                        logger.error(f"Error syncing Threads comment: {e}")

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
