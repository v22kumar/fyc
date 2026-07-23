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

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

def test_ai_features():
    logger.info("Initializing AI Test Script...")
    
    with SessionLocal() as db:
        # 1. Setup
        org = db.query(Organization).first()
        if not org:
            logger.error("No organization found in database. Cannot run AI test.")
            sys.exit(1)
            
        ai_svc = AIService(db)
        if not ai_svc.api_key:
            logger.error("GEMINI_API_KEY is not set in the environment variables!")
            sys.exit(1)
            
        today = datetime.now(timezone.utc).date()
        
        # Force a fresh generation by clearing today's cache
        db.query(AIContent).filter(AIContent.content_date == today).delete()
        db.commit()
        
        print("\n" + "="*50)
        print("🤖 TESTING FEATURE 1: Smart Notification Rewriting")
        print("="*50)
        
        original_title = "Meeting Reminder"
        original_body = "The weekly club meeting is tomorrow at 5 PM. Please be on time."
        
        print(f"Original Title: {original_title}")
        print(f"Original Body: {original_body}\n")
        
        print("Sending to Gemini...")
        smart_notification = ai_svc.generate_smart_notification(original_title, original_body, "CLUB_MEETING")
        
        print(f"✨ AI Title: {smart_notification.get('title')}")
        print(f"✨ AI Body: {smart_notification.get('body')}")


        print("\n" + "="*50)
        print("🤖 TESTING FEATURE 2: Community Daily Digest")
        print("="*50)
        
        print("Gathering database events, sports, and donors, and sending to Gemini...")
        digest = ai_svc.generate_daily_digest(org.id)
        if digest:
            print(f"✨ AI Daily Digest:")
            print(json.dumps(digest, indent=2, ensure_ascii=False))
        else:
            print("Failed to generate Daily Digest.")


        print("\n" + "="*50)
        print("🤖 TESTING FEATURE 3: Trending News Summarizer")
        print("="*50)
        
        print("Scraping live news headlines and sending to Gemini...")
        news = ai_svc.generate_news_summary(org.id)
        if news:
            print(f"✨ AI News Summary:")
            print(json.dumps(news, indent=2, ensure_ascii=False))
        else:
            print("Failed to generate News Summary.")

        print("\n" + "="*50)
        print("✅ AI Feature Testing Complete!")
        print("="*50 + "\n")

if __name__ == "__main__":
    test_ai_features()
