from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.core_services import Attachment
from app.models.user import User

router = APIRouter(prefix="/attachments", tags=["Attachments"])

class AttachmentCreatePayload(BaseModel):
    entity_type: str
    entity_id: UUID
    file_url: str
    file_type: Optional[str] = None
    description: Optional[str] = None

class AttachmentOut(BaseModel):
    id: UUID
    uploader_id: Optional[UUID]
    entity_type: str
    entity_id: UUID
    file_url: str
    file_type: Optional[str]
    description: Optional[str]

    class Config:
        from_attributes = True

@router.post("", response_model=AttachmentOut)
def add_attachment(
    payload: AttachmentCreatePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add a file attachment to any entity."""
    attachment = Attachment(
        organization_id=current_user.organization_id,
        uploader_id=current_user.id,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        file_url=payload.file_url,
        file_type=payload.file_type,
        description=payload.description
    )
    db.add(attachment)
    db.commit()
    db.refresh(attachment)
    return attachment

@router.get("/{entity_type}/{entity_id}", response_model=List[AttachmentOut])
def list_attachments(
    entity_type: str,
    entity_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id)
):
    """List attachments for an entity."""
    return db.query(Attachment).filter(
        Attachment.organization_id == tenant_id,
        Attachment.entity_type == entity_type,
        Attachment.entity_id == entity_id
    ).order_by(Attachment.created_at.asc()).all()

@router.delete("/{attachment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_attachment(
    attachment_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete an attachment."""
    attachment = db.query(Attachment).filter(
        Attachment.id == attachment_id,
        Attachment.organization_id == current_user.organization_id
    ).first()
    
    if not attachment:
        raise HTTPException(status_code=404, detail="Attachment not found")
        
    if attachment.uploader_id != current_user.id and current_user.role not in ["ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER"]:
        raise HTTPException(status_code=403, detail="Not authorized to delete this attachment")
        
    db.delete(attachment)
    db.commit()
