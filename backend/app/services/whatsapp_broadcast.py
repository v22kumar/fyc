"""
Daily WhatsApp morning broadcast — Thirukkural + Kanyakumari news.

Sends to:
  A) The FYC WhatsApp group via Meta Cloud API (if META_WA_* vars are set)
  B) Every registered user individually via Twilio (if TWILIO_* vars are set)

Triggered by APScheduler at 00:30 UTC (6:00 AM IST) when
MORNING_BROADCAST_ENABLED=true.
"""
import asyncio
import logging
import time
import uuid
from datetime import datetime, timezone

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.user import User
from app.services.thirukkural import get_daily_kural
from app.services.news import get_kanyakumari_news

logger = logging.getLogger(__name__)

_DEFAULT_ORG_ID = uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d")

# In-memory status for /broadcasts/status endpoint
_last_broadcast: dict = {
    "run_at": None,
    "group_ok": None,
    "members_sent": 0,
    "members_failed": 0,
}


def compose_morning_message() -> str:
    """Build the daily morning message string."""
    kural = get_daily_kural()
    news_items = get_kanyakumari_news(limit=3)

    lines = [
        "🌅 காலை வணக்கம்! Good Morning, FYC Family! 🙏",
        "",
        f"📜 *இன்றைய திருக்குறள் · Kural #{kural.get('number', '')}*",
        kural.get("line1", ""),
        kural.get("line2", ""),
        "",
        f"அர்த்தம்: {kural.get('tamil_meaning', '')}",
        f"Meaning: {kural.get('english_meaning', kural.get('english_couplet', ''))}",
        "",
        "📰 *இன்றைய செய்திகள் · Today's Headlines*",
    ]
    for i, item in enumerate(news_items, 1):
        title = (item.get("title") or "")[:80]
        source = item.get("source") or ""
        lines.append(f"{i}. {title} — {source}")

    lines += ["", "🔗 fyc-web.fly.dev"]
    return "\n".join(lines)


async def send_to_group(message: str) -> bool:
    """POST message to the FYC WhatsApp group via Meta Cloud API."""
    if not (settings.META_WA_TOKEN and settings.META_WA_PHONE_NUMBER_ID and settings.META_WA_GROUP_ID):
        logger.info("[broadcast] Meta Cloud API not configured — skipping group send")
        return False
    try:
        url = f"https://graph.facebook.com/v20.0/{settings.META_WA_PHONE_NUMBER_ID}/messages"
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "group",
            "to": settings.META_WA_GROUP_ID,
            "type": "text",
            "text": {"body": message, "preview_url": False},
        }
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                url,
                json=payload,
                headers={"Authorization": f"Bearer {settings.META_WA_TOKEN}"},
            )
            resp.raise_for_status()
            logger.info(f"[broadcast] Group message sent OK: {resp.json()}")
            return True
    except httpx.TimeoutException:
        logger.warning("[broadcast] Group send failed: Timeout")
        return False
    except httpx.HTTPStatusError as e:
        logger.warning(f"[broadcast] Group send failed: HTTP error {e.response.status_code}")
        return False
    except Exception as e:
        logger.warning(f"[broadcast] Group send failed: {e}")
        return False


async def send_to_members(message: str, org_id: uuid.UUID = _DEFAULT_ORG_ID) -> dict:
    """Send the message to all registered users with phone numbers via Twilio."""
    if not (settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN):
        logger.info("[broadcast] Twilio not configured — skipping individual sends")
        return {"sent": 0, "failed": 0}

    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    except Exception as e:
        logger.warning(f"[broadcast] Twilio init failed: {e}")
        return {"sent": 0, "failed": 0}

    sent = failed = 0
    db: Session = SessionLocal()
    try:
        users = (
            db.query(User.phone_number)
            .filter(
                User.organization_id == org_id,
                User.phone_number.isnot(None),
                User.phone_number != "",
            )
            .all()
        )
        phones = [row[0] for row in users]
    finally:
        db.close()

    logger.info(f"[broadcast] Sending to {len(phones)} members")
    for phone in phones:
        try:
            # Run the blocking Twilio call in a thread pool to avoid blocking the event loop
            await asyncio.to_thread(
                client.messages.create,
                from_=settings.TWILIO_WHATSAPP_FROM,
                to=f"whatsapp:{phone}",
                body=message,
            )
            sent += 1
        except Exception as e:
            logger.warning(f"[broadcast] Failed to send to {phone}: {e}")
            failed += 1
        await asyncio.sleep(1)  # 1 msg/sec to stay within Twilio rate limits

    return {"sent": sent, "failed": failed}


async def run_morning_broadcast() -> None:
    """Orchestrate the daily broadcast — called by APScheduler and the admin endpoint."""
    logger.info("[broadcast] Starting morning broadcast")
    try:
        message = compose_morning_message()
    except Exception as e:
        logger.error(f"[broadcast] Failed to compose message: {e}")
        return

    group_ok = await send_to_group(message)
    result = await send_to_members(message)

    _last_broadcast["run_at"] = datetime.now(timezone.utc).isoformat()
    _last_broadcast["group_ok"] = group_ok
    _last_broadcast["members_sent"] = result["sent"]
    _last_broadcast["members_failed"] = result["failed"]

    logger.info(
        f"[broadcast] Done — group: {'OK' if group_ok else 'SKIP/FAIL'} | "
        f"members: {result['sent']} sent, {result['failed']} failed"
    )
