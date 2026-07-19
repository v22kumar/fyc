from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel

from app.core.database import get_db
from app.dependencies import get_current_user
from app.models.user import User, UserProfile
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

class TestPushResult(BaseModel):
    firebase_initialised: bool
    has_device_token: bool
    push_sent: bool
    detail: str


@router.post("/test", response_model=TestPushResult)
def send_test_notification(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Self-test: push a notification to the caller's OWN device and report the
    exact reason if it can't — so an admin can verify the FCM pipeline end to end
    and see immediately whether the block is server config or a missing token."""
    try:
        import firebase_admin  # local import so a missing dep never breaks the module
        fb_ready = bool(firebase_admin._apps)
    except ImportError:
        fb_ready = False
    has_token = bool(current_user.fcm_token)

    # Always drop an in-app record so it's visible in the bell regardless of push.
    db.add(Notification(
        user_id=current_user.id,
        organization_id=current_user.organization_id,
        title_en="FYC Connect — test",
        title_ta="FYC Connect — சோதனை",
        body_en="🔔 Test notification — push is working!",
        body_ta="🔔 சோதனை அறிவிப்பு",
        notification_type="TEST",
        data={"type": "TEST", "route": "/notifications"},
        sent_at=datetime.now(timezone.utc),
    ))
    db.commit()

    sent = False
    if fb_ready and has_token:
        sent = NotificationService(db)._dispatch_push(
            current_user.fcm_token,
            "FYC Connect — test",
            "🔔 Push notifications are working!",
            {"type": "TEST", "route": "/notifications"},
        )

    if not fb_ready:
        detail = "Firebase isn't configured on the server — set FIREBASE_CREDENTIALS_JSON and redeploy."
    elif not has_token:
        detail = "No device token registered yet — reopen the app and allow notifications, then try again."
    elif sent:
        detail = "Push sent — check your notification bar."
    else:
        detail = "Firebase is configured but the send failed (token may be stale — reopen the app)."

    return TestPushResult(
        firebase_initialised=fb_ready,
        has_device_token=has_token,
        push_sent=sent,
        detail=detail,
    )


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

@router.put("/{notification_id}/track-click")
def track_click(
    notification_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from datetime import datetime, timezone
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    if notif and not notif.clicked_at:
        notif.clicked_at = datetime.now(timezone.utc)
        db.commit()
    return {"status": "tracked"}

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


class SosAlertRequest(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@router.post("/sos-alert")
def sos_alert(
    data: SosAlertRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Any member: raise an SOS to fellow members in the org so nearby FYC
    members are notified they need urgent help. Includes a maps link when a
    location is shared."""
    prof = (
        db.query(UserProfile)
        .filter(UserProfile.user_id == current_user.id)
        .first()
    )
    name = (prof.full_name_en or prof.full_name_ta) if prof else "A member"
    maps = None
    if data.latitude is not None and data.longitude is not None:
        maps = f"https://maps.google.com/?q={data.latitude},{data.longitude}"
    payload = {"type": "SOS", "from_user_id": str(current_user.id)}
    if maps:
        payload["location_url"] = maps
    svc = NotificationService(db)
    background_tasks.add_task(
        svc.broadcast,
        organization_id=current_user.organization_id,
        title_en=f"🆘 SOS from {name}",
        title_ta=f"🆘 {name} உதவி கேட்கிறார்",
        body_en="A member needs urgent help." + (f" Location: {maps}" if maps else ""),
        body_ta="ஒரு உறுப்பினருக்கு அவசர உதவி தேவை." + (f" இடம்: {maps}" if maps else ""),
        notification_type="SOS",
        data=payload,
    )
    return {"message": "Alert sent to members"}
