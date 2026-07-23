import sys
import os
import uuid
import logging

logging.basicConfig(level=logging.INFO)

# Make sure we can import from app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.tenant import Organization
from app.services.notification_service import NotificationService
from app.services.ai_service import AIService

def run():
    print("Starting AI generation and Push Notification...")
    db = SessionLocal()
    org = db.query(Organization).first()
    if not org:
        print("No organization found in database.")
        db.close()
        return

    print(f"Generating Daily Digest for Org {org.id}...")
    ai_svc = AIService(db)
    ai_svc.generate_daily_digest(org.id)
    
    print(f"Generating News Summary for Org {org.id}...")
    ai_svc.generate_news_summary(org.id)

    print("Broadcasting Push Notifications...")
    notif_svc = NotificationService(db)
    
    # Broadcast to all users in the organization who have push enabled
    notif_svc.broadcast(
        organization_id=org.id,
        title_en="AI Daily Digest Ready ✨",
        title_ta="AI தினசரி சுருக்கம் தயார் ✨",
        body_en="Your personalized AI digest and news summary are ready for you. Tap to read!",
        body_ta="உங்கள் தனிப்பயனாக்கப்பட்ட AI சுருக்கம் தயாராக உள்ளது. படிக்க கிளிக் செய்க!",
        notification_type="SYSTEM"
    )
    
    print("Done! Check your mobile phone for the notification.")
    db.close()

if __name__ == "__main__":
    run()
