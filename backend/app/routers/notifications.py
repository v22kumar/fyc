from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.notification import Notification
from app.schemas.notification import (
    NotificationResponse, 
    NotificationPreferenceResponse, 
    NotificationPreferenceUpdate,
    BroadcastRequest
)
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("", response_model=List[NotificationResponse])
def get_my_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get notifications for the current user, ordered by newest first."""
    notifications = db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).order_by(Notification.created_at.desc()).limit(50).all()
    return notifications

@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_as_read(
    notification_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif

@router.put("/read-all")
def mark_all_as_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).update({"is_read": True})
    db.commit()
    return {"message": "All notifications marked as read"}

@router.get("/preferences", response_model=NotificationPreferenceResponse)
def get_preferences(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    svc = NotificationService(db)
    return svc.get_preferences(current_user.id, current_user.organization_id)

@router.put("/preferences", response_model=NotificationPreferenceResponse)
def update_preferences(
    data: NotificationPreferenceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    svc = NotificationService(db)
    return svc.update_preferences(current_user.id, current_user.organization_id, data.model_dump())

@router.post("/broadcast")
def broadcast_notification(
    data: BroadcastRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Admin only: Broadcast a notification to all users or specific roles."""
    if current_user.role not in ["ADMIN", "SUPER_ADMIN"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    svc = NotificationService(db)
    # Run broadcast in background to avoid blocking response
    background_tasks.add_task(
        svc.broadcast,
        organization_id=current_user.organization_id,
        title_en=data.title_en,
        title_ta=data.title_ta,
        body_en=data.body_en,
        body_ta=data.body_ta,
        notification_type=data.notification_type,
        data=data.data,
        target_roles=data.target_roles
    )
    return {"message": "Broadcast scheduled successfully"}
