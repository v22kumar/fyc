"""
Daily birthday notification — runs at 6:01 AM IST (00:31 UTC).
Sends a personal FCM notification to users whose birthday is today,
and broadcasts a greeting to the org's announcements topic.
"""
import logging
from datetime import date

from sqlalchemy import extract

from app.core.database import SessionLocal
from app.models.user import User, UserProfile
from app.services.notifications import _send_fcm, _send_topic

logger = logging.getLogger(__name__)

_DEFAULT_ORG_SLUG = "fyc-nagercoil"


def run_birthday_notifications() -> None:
    today = date.today()
    db = SessionLocal()
    try:
        rows = (
            db.query(UserProfile, User)
            .join(User, User.id == UserProfile.user_id)
            .filter(
                UserProfile.date_of_birth.isnot(None),
                extract("month", UserProfile.date_of_birth) == today.month,
                extract("day", UserProfile.date_of_birth) == today.day,
            )
            .all()
        )

        if not rows:
            logger.info("[birthday] No birthdays today.")
            return

        topic = f"org_{_DEFAULT_ORG_SLUG}_announcements"
        for profile, user in rows:
            name_ta = profile.full_name_ta or profile.full_name_en or "நண்பர்"
            name_en = profile.full_name_en or profile.full_name_ta or "Friend"

            # Personal notification to the birthday person
            if user.fcm_token:
                _send_fcm(
                    user.fcm_token,
                    "🎂 பிறந்த நாள் வாழ்த்துக்கள்!",
                    "FYC குடும்பத்தின் அன்பான வாழ்த்துக்கள்! உங்கள் நாள் மகிழ்ச்சியாக அமையட்டும்!",
                    {"type": "BIRTHDAY_SELF"},
                )

            # Broadcast to all org members
            _send_topic(
                topic,
                f"🎂 {name_ta} அவர்களுக்கு பிறந்த நாள் வாழ்த்துக்கள்!",
                f"Happy Birthday {name_en}! FYC குடும்பத்தின் சார்பாக அன்பான வாழ்த்துக்கள்!",
                {"type": "BIRTHDAY_MEMBER", "name_en": name_en},
            )
            logger.info(f"[birthday] Notified for {name_en}")

    except Exception as e:
        logger.error(f"[birthday] Error: {e}")
    finally:
        db.close()
