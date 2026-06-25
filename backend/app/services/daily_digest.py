import logging
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.tenant import Organization
from app.models.user import User
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)

def run_morning_digest():
    """Scheduled job for Morning Summary"""
    logger.info("Running Morning Notification Digest...")
    with SessionLocal() as db:
        svc = NotificationService(db)
        orgs = db.query(Organization).all()
        for org in orgs:
            # Broadcast Morning Summary
            svc.broadcast(
                organization_id=org.id,
                title_en="Morning Digest ☀️",
                title_ta="காலை சுருக்கம் ☀️",
                body_en="Here's what's happening today in your community.",
                body_ta="இன்று உங்கள் சமூகத்தில் நடப்பவை இதோ.",
                notification_type="SYSTEM"
            )

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
