import httpx
import logging
import json
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from app.core.config import settings
from app.models.ai_content import AIContent

logger = logging.getLogger(__name__)


def _parse_bilingual(response_text: str, keep: tuple = ()) -> Dict[str, Any]:
    """Parse Gemini's JSON reply into {summary_en, summary_ta, summary}.

    `summary` mirrors the English text for older clients (web / pre-i18n app)
    that still read a single `summary` field. Extra keys named in `keep` (e.g.
    trending_topics) are carried through. Tolerates a model that only returned a
    single `summary`."""
    cleaned = response_text.strip()
    if cleaned.startswith("```json"):
        cleaned = cleaned[7:]
    if cleaned.startswith("```"):
        cleaned = cleaned[3:]
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3]
    parsed = json.loads(cleaned.strip())
    en = (parsed.get("summary_en") or parsed.get("summary") or "").strip()
    ta = (parsed.get("summary_ta") or "").strip()
    out: Dict[str, Any] = {"summary_en": en, "summary_ta": ta, "summary": en}
    for k in keep:
        if k in parsed:
            out[k] = parsed[k]
    return out


class AIService:
    """Service to interact with Google Gemini and cache responses."""
    
    def __init__(self, db: Session):
        self.db = db
        self.api_key = settings.GEMINI_API_KEY
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"
    
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

        # Aggregate today's community data. Wrapped defensively: a single bad
        # field must not abort the whole digest (this is why it was silently
        # empty — Event has title_en/title_ta, not `title`, so `e.title` raised
        # for every org that had any events).
        # Gather what members can ACT ON today — open registrations, live
        # tournaments, blood availability — not just titles. Each block is
        # defensive so one bad field can't blank the whole digest.
        context = "Today's Community Data (tell members what's happening and what they can DO today):\\n"
        try:
            from app.models.event import Event
            from app.models.sports import Tournament
            from app.models.blood_donor import BloodDonor
            from sqlalchemy import func as _func

            # Upcoming / registration-open events.
            events = (
                self.db.query(Event)
                .filter(
                    Event.organization_id == organization_id,
                    Event.status == "active",
                    Event.is_published == True,
                    Event.event_end >= today,
                )
                .order_by(Event.event_start.asc())
                .limit(5)
                .all()
            )
            ev_lines = []
            for e in events:
                title = e.title_en or e.title_ta or ""
                if not title:
                    continue
                when = e.event_start.strftime("%d %b") if e.event_start else ""
                reg = "registration OPEN — invite members to register" if getattr(e, "registration_enabled", False) else "details only"
                ev_lines.append(f"{title} ({when}; {reg})")
            if ev_lines:
                context += "Events: " + "; ".join(ev_lines) + "\\n"

            # Tournaments open for team registration or live now.
            tournaments = (
                self.db.query(Tournament)
                .filter(
                    Tournament.organization_id == organization_id,
                    Tournament.status.in_(["UPCOMING", "ONGOING"]),
                )
                .limit(4)
                .all()
            )
            t_lines = []
            for t in tournaments:
                nm = t.name_en or t.name_ta or ""
                if not nm:
                    continue
                state = "LIVE now — invite members to watch" if t.status == "ONGOING" else "registration open — invite teams to enter"
                t_lines.append(f"{nm} ({t.sport}; {state})")
            if t_lines:
                context += "Tournaments: " + "; ".join(t_lines) + "\\n"

            # Blood availability by group.
            bd = (
                self.db.query(BloodDonor.blood_group, _func.count(BloodDonor.id))
                .filter(
                    BloodDonor.organization_id == organization_id,
                    BloodDonor.is_available == True,
                )
                .group_by(BloodDonor.blood_group)
                .all()
            )
            groups = [f"{g} ({c} ready)" for g, c in bd if g]
            if groups:
                context += "Blood donors available: " + ", ".join(groups) + "\\n"
        except Exception as e:
            logger.warning(f"Daily digest data aggregation partial failure: {e}")

        prompt = f"""
        You are the FYC Connect community assistant. Using ONLY the data below,
        write a warm, concise daily briefing (2-4 short sentences) that tells
        members what is happening and, crucially, what they can DO today. When a
        registration is OPEN, explicitly invite them to register/enter; when a
        tournament is LIVE, invite them to watch; if blood donors are listed,
        mention support is available. Do NOT invent anything not in the data. If
        there is little data, keep it short and welcoming. Provide BOTH English
        and Tamil.

        Data:
        {context}

        Return ONLY JSON (no markdown):
        {{
            "summary_en": "the briefing in English",
            "summary_ta": "the same briefing written in Tamil (தமிழில்)"
        }}
        """

        response_text = self._call_gemini(prompt)
        if not response_text:
            return None

        try:
            parsed = _parse_bilingual(response_text)
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
        You are a news summarizer. Given the following headlines, write a unified
        short summary of the day's news (max 3 sentences), in BOTH English and Tamil.
        Also identify the most important trending topics.

        Headlines:
        {context}

        Return ONLY JSON (no markdown):
        {{
            "summary_en": "unified summary in English",
            "summary_ta": "the same summary written in Tamil (தமிழில்)",
            "trending_topics": ["Topic 1", "Topic 2", "Topic 3"]
        }}
        """

        response_text = self._call_gemini(prompt)
        if not response_text:
            return None

        try:
            parsed = _parse_bilingual(response_text, keep=("trending_topics",))
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
