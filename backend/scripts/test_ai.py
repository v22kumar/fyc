import os
import sys
import logging
from datetime import datetime, timezone
from pathlib import Path
import json

# Ensure the app package is discoverable
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import SessionLocal
from app.models.tenant import Organization
from app.models.ai_content import AIContent
from app.services.ai_service import AIService
from app.services.notification_service import NotificationService

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

def test_ai_features():
    logger.info("Initializing AI Test Script (Push Notification Mode)...")
    
    with SessionLocal() as db:
        org = db.query(Organization).first()
        if not org:
            logger.error("No organization found.")
            sys.exit(1)
            
        ai_svc = AIService(db)
        notif_svc = NotificationService(db)
        
        today = datetime.now(timezone.utc).date()
        db.query(AIContent).filter(AIContent.content_date == today).delete()
        db.commit()
        
        print("\n" + "="*50)
        print("🤖 TESTING FEATURE 1: Smart Notification Rewriting")
        print("="*50)
        
        print("Broadcasting a boring meeting reminder to the organization...")
        print("The backend will automatically intercept this and rewrite it using AI before pushing it to your Flutter app!")
        
        # This automatically triggers generate_smart_notification internally before sending!
        NotificationService.broadcast_to_tenant(
            db=db,
            tenant_id=org.id,
            category="COMMUNITY",
            title_en="Meeting Reminder",
            title_ta="மீட்டிங் நினைவூட்டல்",
            body_en="The weekly club meeting is tomorrow at 5 PM. Please be on time.",
            body_ta="நாளைய கிளப் மீட்டிங் மாலை 5 மணிக்கு நடைபெறும்."
        )
        print("✅ Sent! Check your phone for the AI-enhanced push notification.")


        print("\n" + "="*50)
        print("🤖 TESTING FEATURE 2: Community Daily Digest")
        print("="*50)
        
        print("Generating Daily Digest...")
        digest = ai_svc.generate_daily_digest(org.id)
        if digest:
            print("Broadcasting Digest to Flutter UI...")
            notif_svc.broadcast(
                organization_id=org.id,
                title_en="🌅 Your Daily Community Digest",
                title_ta="🌅 இன்றைய சுருக்கம்",
                body_en=digest.get("summary", ""),
                body_ta=digest.get("summary", ""),
                notification_type="SYSTEM"
            )
            print("✅ Sent! Check your phone.")
        else:
            print("Failed to generate Daily Digest.")


        print("\n" + "="*50)
        print("🤖 TESTING FEATURE 3: Trending News Summarizer")
        print("="*50)
        
        print("Generating News Summary...")
        news = ai_svc.generate_news_summary(org.id)
        if news:
            print("Broadcasting News to Flutter UI...")
            notif_svc.broadcast(
                organization_id=org.id,
                title_en="📰 Trending News Summary",
                title_ta="📰 முக்கிய செய்திகள்",
                body_en=news.get("summary", ""),
                body_ta=news.get("summary", ""),
                notification_type="NEWS"
            )
            print("✅ Sent! Check your phone.")
        else:
            print("Failed to generate News Summary.")

        print("\n" + "="*50)
        print("✅ AI Push Notification Testing Complete! You should have received 3 push notifications on your device.")
        print("="*50 + "\n")

if __name__ == "__main__":
    test_ai_features()
