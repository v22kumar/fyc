"""
Push notification service via Firebase Cloud Messaging (FCM).
Set FCM_SERVER_KEY in .env to enable. When unset, notifications are logged only.
"""

import logging
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)

FCM_SERVER_KEY = settings.FCM_SERVER_KEY
FCM_URL = "https://fcm.googleapis.com/fcm/send"


def _send_fcm(token: str, title: str, body: str, data: dict | None = None) -> bool:
    if not FCM_SERVER_KEY:
        logger.info(f"[FCM disabled] To: {token[:12]}… | {title}: {body}")
        return False
    try:
        import httpx
        payload = {
            "to": token,
            "notification": {"title": title, "body": body, "sound": "default"},
            "data": data or {},
        }
        r = httpx.post(
            FCM_URL,
            json=payload,
            headers={"Authorization": f"key={FCM_SERVER_KEY}", "Content-Type": "application/json"},
            timeout=10,
        )
        r.raise_for_status()
        return True
    except Exception as e:
        logger.error(f"FCM send failed: {e}")
        return False


def _send_topic(topic: str, title: str, body: str, data: dict | None = None) -> bool:
    """Send to all subscribers of an FCM topic (e.g. 'org_fyc-nagercoil_blood')."""
    if not FCM_SERVER_KEY:
        logger.info(f"[FCM disabled] Topic: {topic} | {title}: {body}")
        return False
    try:
        import httpx
        payload = {
            "to": f"/topics/{topic}",
            "notification": {"title": title, "body": body, "sound": "default"},
            "data": data or {},
        }
        r = httpx.post(
            FCM_URL,
            json=payload,
            headers={"Authorization": f"key={FCM_SERVER_KEY}", "Content-Type": "application/json"},
            timeout=10,
        )
        r.raise_for_status()
        return True
    except Exception as e:
        logger.error(f"FCM topic send failed: {e}")
        return False


# ── Public helpers called from routers ────────────────────────────────────────

def notify_blood_request(org_slug: str, blood_group: str, location: str, lang: str = "ta") -> bool:
    """Broadcast urgent blood request to the org's blood topic."""
    if lang == "ta":
        title = f"அவசர இரத்தம் தேவை — {blood_group}"
        body = f"{location} பகுதியில் {blood_group} இரத்தம் அவசரமாக தேவை. உதவ முன்வாருங்கள்!"
    else:
        title = f"Urgent Blood Needed — {blood_group}"
        body = f"{blood_group} blood urgently needed near {location}. Please respond!"
    topic = f"org_{org_slug}_blood"
    return _send_topic(topic, title, body, {"type": "BLOOD_REQUEST", "blood_group": blood_group})


def notify_issue_assigned(fcm_token: str, issue_id: str, category: str, lang: str = "ta") -> bool:
    """Notify a volunteer they've been assigned an issue."""
    if lang == "ta":
        title = "புதிய பணி ஒதுக்கப்பட்டது"
        body = f"{category} பிரச்சனை உங்களுக்கு ஒதுக்கப்பட்டது. உடனடியாக செயல்படுங்கள்."
    else:
        title = "New Issue Assigned"
        body = f"A {category} issue has been assigned to you. Please act promptly."
    return _send_fcm(fcm_token, title, body, {"type": "ISSUE_ASSIGNED", "issue_id": issue_id})


def notify_issue_resolved(fcm_token: str, issue_id: str, lang: str = "ta") -> bool:
    """Notify the reporter their issue was resolved."""
    if lang == "ta":
        title = "உங்கள் புகார் தீர்க்கப்பட்டது"
        body = "நீங்கள் தெரிவித்த சிக்கல் தீர்க்கப்பட்டது. நன்றி!"
    else:
        title = "Your Issue is Resolved"
        body = "The issue you reported has been resolved. Thank you!"
    return _send_fcm(fcm_token, title, body, {"type": "ISSUE_RESOLVED", "issue_id": issue_id})


def notify_event_created(org_slug: str, title: str, date: str, lang: str = "ta") -> bool:
    """Broadcast new event to all org members."""
    if lang == "ta":
        notif_title = f"புதிய நிகழ்வு: {title}"
        body = f"{date} அன்று நடைபெறும். கலந்துக்கொள்ளுங்கள்!"
    else:
        notif_title = f"New Event: {title}"
        body = f"Happening on {date}. Come join us!"
    topic = f"org_{org_slug}_events"
    return _send_topic(topic, notif_title, body, {"type": "EVENT_CREATED"})


def notify_announcement(org_slug: str, title: str, category: str, lang: str = "ta") -> bool:
    """Broadcast announcement to org topic."""
    topic = f"org_{org_slug}_announcements"
    return _send_topic(topic, title, f"[{category}] {title}", {"type": "ANNOUNCEMENT", "category": category})
