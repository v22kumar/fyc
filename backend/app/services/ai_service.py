import httpx
import logging
import json
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from app.core.config import settings
from app.models.ai_content import AIContent

logger = logging.getLogger(__name__)

class AIService:
    """Service to interact with Google Gemini and cache responses."""
    
    def __init__(self, db: Session):
        self.db = db
        self.api_key = settings.GEMINI_API_KEY
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    def _call_gemini(self, prompt: str) -> Optional[str]:
        """Make an async-compatible HTTP call to the Gemini API."""
        if not self.api_key:
            logger.warning("GEMINI_API_KEY not set. AI features disabled.")
            return None
            
        url = f"{self.base_url}?key={self.api_key}"
        headers = {"Content-Type": "application/json"}
        payload = {
            "contents": [{"parts": [{"text": prompt}]}]
        }
        
        try:
            # We use httpx synchronously because this might be called from background jobs or sync routers
            # Alternatively we could use AsyncClient, but the standard architecture here calls services synchronously
            with httpx.Client(timeout=15.0) as client:
                response = client.post(url, headers=headers, json=payload)
                response.raise_for_status()
                data = response.json()
                
                # Extract text from Gemini response structure
                if "candidates" in data and len(data["candidates"]) > 0:
                    candidate = data["candidates"][0]
                    if "content" in candidate and "parts" in candidate["content"]:
                        return candidate["content"]["parts"][0]["text"].strip()
                return None
        except Exception as e:
            logger.error(f"Gemini API Error: {e}")
            return None

    def generate_smart_notification(self, original_title: str, original_body: str, notification_type: str = "") -> Dict[str, str]:
        """Rewrites a static notification into a smart, engaging AI notification."""
        if not self.api_key:
            return {"title": original_title, "body": original_body}
            
        prompt = f"""
        Rewrite the following notification to be more engaging, empathetic, and urgent (if necessary) for a community platform.
        Keep it concise (max 3 sentences). Include exactly one appropriate emoji in the title.
        
        Original Title: {original_title}
        Original Body: {original_body}
        Type: {notification_type}
        
        Return ONLY valid JSON in this exact format:
        {{
            "title": "New engaging title with emoji",
            "body": "New engaging body text"
        }}
        """
        
        response_text = self._call_gemini(prompt)
        if not response_text:
            return {"title": original_title, "body": original_body}
            
        try:
            # Clean up potential markdown formatting like ```json ... ```
            cleaned = response_text.strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.startswith("```"):
                cleaned = cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
                
            parsed = json.loads(cleaned.strip())
            return {
                "title": parsed.get("title", original_title),
                "body": parsed.get("body", original_body)
            }
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Gemini smart notification JSON: {e} \nRaw: {response_text}")
            return {"title": original_title, "body": original_body}

    def generate_daily_digest(self, organization_id) -> Optional[Dict[str, Any]]:
        """Aggregates today's data and generates a daily digest summary."""
        if not self.api_key:
            return None
            
        today = datetime.now(timezone.utc).date()
        
        # Check cache
        cached = self.db.query(AIContent).filter(
            AIContent.content_type == "DAILY_DIGEST",
            AIContent.content_date == today,
            AIContent.organization_id == organization_id
        ).first()
        
        if cached:
            return cached.content_data

        # Aggregate data (Mocking the exact fetch logic for brevity, ideally uses repositories)
        from app.models.event import Event
        from app.models.sports import Fixture
        from app.models.blood_donor import BloodDonor
        
        events = self.db.query(Event).filter(Event.organization_id == organization_id).limit(3).all()
        fixtures = self.db.query(Fixture).filter(Fixture.tournament_id != None).limit(3).all()
        blood_requests = self.db.query(BloodDonor).filter(BloodDonor.is_available == True).limit(2).all()
        
        context = "Today's Community Data:\\n"
        context += "Events: " + ", ".join([e.title for e in events]) + "\\n"
        context += "Sports: " + ", ".join([f"{f.team_a_score} vs {f.team_b_score}" for f in fixtures if f.team_a_score]) + "\\n"
        context += "Blood Donors: " + ", ".join([f"Available: {br.blood_group}" for br in blood_requests]) + "\\n"

        prompt = f"""
        You are the FYC Connect community AI assistant. Write a concise daily digest summary (max 3 sentences) based on the following data.
        Make it sound engaging and community-focused.
        
        Data:
        {context}
        
        Return JSON format:
        {{
            "summary": "Your generated summary text here"
        }}
        """
        
        response_text = self._call_gemini(prompt)
        if not response_text:
            return None
            
        try:
            cleaned = response_text.strip()
            if cleaned.startswith("```json"): cleaned = cleaned[7:]
            if cleaned.startswith("```"): cleaned = cleaned[3:]
            if cleaned.endswith("```"): cleaned = cleaned[:-3]
            parsed = json.loads(cleaned.strip())
            
            # Cache it
            content = AIContent(
                organization_id=organization_id,
                content_type="DAILY_DIGEST",
                content_date=today,
                content_data=parsed
            )
            self.db.add(content)
            self.db.commit()
            return parsed
        except Exception as e:
            logger.error(f"Failed to generate daily digest: {e}")
            return None
        
    def generate_news_summary(self, organization_id) -> Optional[Dict[str, Any]]:
        """Generates a summary of all news."""
        if not self.api_key:
            return None
            
        today = datetime.now(timezone.utc).date()
        cached = self.db.query(AIContent).filter(
            AIContent.content_type == "NEWS_SUMMARY",
            AIContent.content_date == today,
            AIContent.organization_id == organization_id
        ).first()
        
        if cached:
            return cached.content_data

        from app.services.news import get_kanyakumari_news, get_top_tamil_news
        import asyncio
        
        try:
            # The news functions are async (refactored in Phase 1 for performance)
            # If there's an existing event loop, run_until_complete, else asyncio.run
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # We can't use run_until_complete in a running loop, but in our architecture
                # this is called from a synchronous background thread (apscheduler) or sync route
                # where the loop is usually not running. 
                pass
            k_news = loop.run_until_complete(get_kanyakumari_news(limit=5))
            t_news = loop.run_until_complete(get_top_tamil_news(limit=5))
        except RuntimeError:
            k_news = asyncio.run(get_kanyakumari_news(limit=5))
            t_news = asyncio.run(get_top_tamil_news(limit=5))
            
        news_items = k_news + t_news
        
        context = "Latest News Headlines:\\n"
        for i, item in enumerate(news_items[:10]):
            context += f"- {item.get('title', '')}\\n"

        prompt = f"""
        You are a news summarizer. Given the following headlines, write a unified short summary of the day's news (max 3 sentences).
        Identify the most important trending topics.
        
        Headlines:
        {context}
        
        Return JSON format:
        {{
            "summary": "Your unified summary text here",
            "trending_topics": ["Topic 1", "Topic 2", "Topic 3"]
        }}
        """
        
        response_text = self._call_gemini(prompt)
        if not response_text:
            return None
            
        try:
            cleaned = response_text.strip()
            if cleaned.startswith("```json"): cleaned = cleaned[7:]
            if cleaned.startswith("```"): cleaned = cleaned[3:]
            if cleaned.endswith("```"): cleaned = cleaned[:-3]
            parsed = json.loads(cleaned.strip())
            
            # Cache it
            content = AIContent(
                organization_id=organization_id,
                content_type="NEWS_SUMMARY",
                content_date=today,
                content_data=parsed
            )
            self.db.add(content)
            self.db.commit()
            return parsed
        except Exception as e:
            logger.error(f"Failed to generate news summary: {e}")
            return None
