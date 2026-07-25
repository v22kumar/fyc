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
    import asyncio
    from app.services.news import get_kanyakumari_news
    # get_kanyakumari_news is async (httpx); this sync scheduler job runs in a
    # thread with no loop, so drive it with asyncio.run — calling it bare left
    # news_items as an un-awaited coroutine and the digest silently failed.
    news_items = asyncio.run(get_kanyakumari_news(limit=1))
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
        for org in db.query(Organization).all():
            # Isolate per-org failures (a Gemini hiccup for one org must not
            # abort caching for the rest).
            try:
                svc.generate_daily_digest(org.id)
            except Exception as e:  # noqa: BLE001 - best-effort pre-cache
                logger.warning(f"AI daily digest failed for org {org.id}: {e}")

def run_ai_news_summary_job():
    """Scheduled job to pre-cache the AI News Summary"""
    logger.info("Running AI News Summary Job...")
    with SessionLocal() as db:
        from app.services.ai_service import AIService
        svc = AIService(db)
        for org in db.query(Organization).all():
            try:
                svc.generate_news_summary(org.id)
            except Exception as e:  # noqa: BLE001 - best-effort pre-cache
                logger.warning(f"AI news summary failed for org {org.id}: {e}")

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
    """Prune in-app notification history older than the retention window.

    A notification row is just a "something was sent" record — the underlying
    event / post / match still lives in its own table — so a uniform N-day
    retention (NOTIFICATION_RETENTION_DAYS, default 7) keeps the table small
    without losing any real data. Applies to every type."""
    from app.core.config import settings
    days = settings.NOTIFICATION_RETENTION_DAYS
    logger.info(f"Running Notification Cleanup Job (retaining {days} days)...")
    with SessionLocal() as db:
        deleted = prune_old_notifications(db, days)
        logger.info(f"[Cleanup] Deleted {deleted} notifications older than {days} days.")


def prune_old_notifications(db, days: int) -> int:
    """Delete every notification older than `days`. Returns the number removed."""
    from datetime import timedelta
    from sqlalchemy import delete
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)
    result = db.execute(delete(Notification).where(Notification.created_at < cutoff_date))
    db.commit()
    return result.rowcount or 0
