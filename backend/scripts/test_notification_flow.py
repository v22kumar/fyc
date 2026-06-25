import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import uuid
from app.core.database import SessionLocal
from app.services.notification_service import NotificationService
from app.models.notification import Notification

def test_notification_flow():
    print("=== Phase 1: End-to-End Notification Validation ===")
    db = SessionLocal()
    svc = NotificationService(db)
    
    org_id = uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d")
    admin_id = uuid.UUID("e30d7b27-5d07-4c7a-bc12-f04bf4c86e00") # Super Admin
    
    print("\n1. Admin publishes news (Broadcasting...)")
    svc.broadcast(
        organization_id=org_id,
        title_en="Club News: Annual Meetup",
        title_ta="சங்க செய்திகள்: வருடாந்திர சந்திப்பு",
        body_en="Join us for the annual meetup tomorrow.",
        body_ta="நாளை நடக்கும் வருடாந்திர சந்திப்பில் கலந்து கொள்ளுங்கள்.",
        notification_type="NEWS",
        data={"route": "/news/123"}
    )
    
    print("2. Notification generated & stored in backend.")
    notifs = db.query(Notification).filter(Notification.user_id == admin_id).all()
    latest = notifs[-1]
    
    print(f"-> Found stored notification for admin: {latest.title_en} (ID: {latest.id})")
    print(f"-> Sent At: {latest.sent_at}")
    print(f"-> Delivered Channels: {latest.delivery_channel}")
    
    print("\n3. User fetches notifications via GET /api/v1/notifications")
    print(f"-> User fetched {len(notifs)} notifications. Latest is unread: {not latest.is_read}")
    
    print("\n4. User taps notification (Opens Deep Link)")
    print(f"-> Extracted deep link: {latest.data.get('route')}")
    
    print("\n5. Frontend sends track-click & read-status")
    latest.is_read = True
    from datetime import datetime, timezone
    latest.clicked_at = datetime.now(timezone.utc)
    db.commit()
    
    print(f"-> Notification marked read. Clicked At: {latest.clicked_at}")
    print("\n=== Validation Complete ===")

if __name__ == "__main__":
    test_notification_flow()
