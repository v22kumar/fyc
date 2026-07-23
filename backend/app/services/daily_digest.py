import logging
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.tenant import Organization
from app.models.user import User
from app.models.notification import Notification
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

def run_thirukkural_digest():
    """Scheduled job for Thirukkural (9 AM IST)"""
    logger.info("Running Thirukkural Notification Digest...")
    from app.services.thirukkural import get_daily_kural
    kural = get_daily_kural()
    
    title_ta = f"இன்றைய திருக்குறள் (Kural #{kural.get('number', '')})"
    title_en = f"Daily Thirukkural (Kural #{kural.get('number', '')})"
    
    # Send the first two lines of the Kural as the body in Tamil, and the English meaning in English.
    body_ta = f"{kural.get('line1', '')}\n{kural.get('line2', '')}"
    body_en = kural.get("english_meaning", kural.get("english_couplet", ""))

    with SessionLocal() as db:
        svc = NotificationService(db)
        orgs = db.query(Organization).all()
        for org in orgs:
            svc.broadcast(
                organization_id=org.id,
                title_en=title_en,
                title_ta=title_ta,
                body_en=body_en,
                body_ta=body_ta,
                notification_type="SYSTEM"
            )

def run_news_digest():
    """Scheduled job for News (10 AM IST)"""
    logger.info("Running News Notification Digest...")
    from app.services.news import get_kanyakumari_news
    news_items = get_kanyakumari_news(limit=1)
    if not news_items:
        logger.warning("No news items found for the digest.")
        return
        
    item = news_items[0]
    title = (item.get("title") or "")[:80]
    source = item.get("source") or ""
    
    body = f"{title} — {source}"
    
    with SessionLocal() as db:
        svc = NotificationService(db)
        orgs = db.query(Organization).all()
        for org in orgs:
            svc.broadcast(
                organization_id=org.id,
                title_en="Latest News 📰",
                title_ta="முக்கிய செய்திகள் 📰",
                body_en=body,
                body_ta=body,
                notification_type="NEWS"
            )

def run_ai_daily_digest_job():
    """Scheduled job to pre-cache the AI Daily Digest"""
    logger.info("Running AI Daily Digest Job...")
    with SessionLocal() as db:
        from app.services.ai_service import AIService
        svc = AIService(db)
        orgs = db.query(Organization).all()
        for org in orgs:
            svc.generate_daily_digest(org.id)

def run_ai_news_summary_job():
    """Scheduled job to pre-cache the AI News Summary"""
    logger.info("Running AI News Summary Job...")
    with SessionLocal() as db:
        from app.services.ai_service import AIService
        svc = AIService(db)
        orgs = db.query(Organization).all()
        for org in orgs:
            svc.generate_news_summary(org.id)

def run_evening_digest():
    """Scheduled job for Evening Summary"""
    logger.info("Running Evening Notification Digest...")
    with SessionLocal() as db:
        svc = NotificationService(db)
        orgs = db.query(Organization).all()
        for org in orgs:
            # Broadcast Evening Summary
            svc.broadcast(
                organization_id=org.id,
                title_en="Evening Digest 🌙",
                title_ta="மாலை சுருக்கம் 🌙",
                body_en="Review the updates and achievements from today.",
                body_ta="இன்றைய புதுப்பிப்புகள் மற்றும் சாதனைகளை மதிப்பாய்வு செய்யவும்.",
                notification_type="SYSTEM"
            )

def run_notification_cleanup():
    """Scheduled job to permanently delete old, transient notifications to save storage (e.g. 7 days old)"""
    logger.info("Running Notification Cleanup Job...")
    import datetime
    cutoff_date = datetime.datetime.now(timezone.utc) - datetime.timedelta(days=7)
    
    with SessionLocal() as db:
        # We delete NEWS, SYSTEM, DAILY, COMMUNITY notifications older than 7 days.
        # We do not delete ADMIN or specific targeted types unless they are marked as transient.
        from sqlalchemy import delete
        
        stmt = delete(Notification).where(
            Notification.notification_type.in_(["NEWS", "SYSTEM", "COMMUNITY", "DAILY"]),
            Notification.created_at < cutoff_date
        )
        result = db.execute(stmt)
        db.commit()
        logger.info(f"[Cleanup] Deleted {result.rowcount} old notifications.")
