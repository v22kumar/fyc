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

# In-memory status for /broadcasts/status endpoint.
#
# `group_ok` is gone with the group send. It only ever reported False, so an
# admin reading this screen was being told a delivery had failed when in fact
# no such delivery was possible.
_last_broadcast: dict = {
    "run_at": None,
    "members_sent": 0,
    "members_failed": 0,
}


async def compose_morning_message() -> str:
    """Build the daily morning message string."""
    kural = get_daily_kural()
    # get_kanyakumari_news is async (httpx) — await it; calling it bare returned
    # a coroutine and broke message composition (the broadcast silently aborted).
    news_items = await get_kanyakumari_news(limit=3)

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

    lines += ["", "🔗 fycconnect.com"]
    return "\n".join(lines)


# The group send is gone, and this note is why.
#
# It used to POST `"recipient_type": "group"` with a `…@g.us` id to
# `/{phone_number_id}/messages`. The WhatsApp Cloud API has no group messaging
# on that endpoint: `recipient_type` takes `individual`, and a group JID is not
# a recipient it will deliver to. The call could only ever fail — and it did.
# The exception was caught, logged at WARNING, and `group_ok` reported False on
# every run since the feature was written.
#
# It stayed invisible because failing looked exactly like not-being-configured.
# Both paths returned False, and the credentials were never set, so nothing
# distinguished "we skipped it" from "it cannot work".
#
# Removed rather than replaced, deliberately. Posting to a WhatsApp group
# programmatically needs a group-enabled number through Meta's Business
# Management API, or a third-party BSP — a vendor decision with a monthly bill
# attached, not a code fix. Until somebody makes that decision, the per-member
# send below is the delivery path, and it works.
#
# META_WA_GROUP_ID stays in config.py as an inert setting so an existing
# deployment does not fail to boot; nothing reads it.


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
        message = await compose_morning_message()
    except Exception as e:
        logger.error(f"[broadcast] Failed to compose message: {e}")
        return

    result = await send_to_members(message)

    _last_broadcast["run_at"] = datetime.now(timezone.utc).isoformat()
    _last_broadcast["members_sent"] = result["sent"]
    _last_broadcast["members_failed"] = result["failed"]

    logger.info(
        f"[broadcast] Done — "
        f"members: {result['sent']} sent, {result['failed']} failed"
    )
