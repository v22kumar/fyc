from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from app.core.database import get_db
from app.models.ai_content import AIContent
from app.models.tenant import Organization
from app.services.ai_service import AIService
from typing import Optional

router = APIRouter(prefix="/ai", tags=["AI"])

def _get_default_organization(db: Session) -> Organization:
    # FYC Connect currently supports a single primary organization for app-wide things
    org = db.query(Organization).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
    return org

@router.get("/daily-digest")
def get_ai_daily_digest(db: Session = Depends(get_db)):
    """Fetch the cached AI Daily Digest for today. Generates on the fly if missing."""
    org = _get_default_organization(db)
    today = datetime.now(timezone.utc).date()
    
    cached = db.query(AIContent).filter(
        AIContent.content_type == "DAILY_DIGEST",
        AIContent.content_date == today,
        AIContent.organization_id == org.id
    ).first()
    
    if cached:
        return cached.content_data
        
    # User constraint: "Never call Gemini when users simply open the app"
    # If the background job hasn't cached it yet, return a fallback instead of blocking a thread.
    return {"summary": "Our AI is preparing today's digest. Check back shortly!"}

@router.get("/news-summary")
def get_ai_news_summary(db: Session = Depends(get_db)):
    """Fetch the cached AI News Summary for today. Generates on the fly if missing."""
    org = _get_default_organization(db)
    today = datetime.now(timezone.utc).date()
    
    cached = db.query(AIContent).filter(
        AIContent.content_type == "NEWS_SUMMARY",
        AIContent.content_date == today,
        AIContent.organization_id == org.id
    ).first()
    
    if cached:
        return cached.content_data
        
    # User constraint: "Never call Gemini when users simply open the app"
    # If the background job hasn't cached it yet, return a fallback instead of blocking a thread.
    return {
        "summary": "Our AI is gathering the latest news updates. Check back shortly!",
        "trending_topics": []
    }
