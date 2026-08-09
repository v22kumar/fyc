"""Daily birthday notifications — runs at 6:01 AM IST (00:31 UTC).

Two messages: a personal greeting to the member whose birthday it is, and a
note to the rest of their club so somebody actually wishes them.

## Why this no longer uses topics

It used to broadcast the club greeting to an FCM topic named after a hardcoded
organisation slug (``org_fyc-nagercoil_announcements``), through the legacy FCM
HTTP API. Both halves were dead:

* the legacy endpoint was decommissioned by Google in June 2024, and
* nothing in this repository has ever called ``subscribeToTopic``, so that
  topic had no subscribers even before the endpoint went away.

So the greeting is now fanned out per member through ``NotificationService``,
which is what every other feature uses and what actually reaches a phone. It
also means the message respects each member's notification preferences and
leaves an in-app record.

The hardcoded slug is gone with it. A birthday in one club is announced to that
club, resolved from the member's own ``organization_id`` — so this stays
correct the moment there is a second tenant.
"""
import logging
from datetime import date

from sqlalchemy import extract

from app.core import i18n
from app.core.database import SessionLocal
from app.models.user import User, UserProfile
from app.schemas.notification import NotificationCategory
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)


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

        svc = NotificationService(db)

        for profile, user in rows:
            name_en = profile.full_name_en or profile.full_name_ta or "Friend"
            name_ta = profile.full_name_ta or profile.full_name_en or "நண்பர்"
            org_id = user.organization_id

            # 1. The member themselves.
            try:
                svc.send_push_only(
                    user_id=user.id,
                    organization_id=org_id,
                    title_en=i18n.t("birthday.self.title", "en") or "",
                    title_ta=i18n.t("birthday.self.title", "ta") or "",
                    body_en=i18n.t("birthday.self.body", "en") or "",
                    body_ta=i18n.t("birthday.self.body", "ta") or "",
                    notification_type=NotificationCategory.COMMUNITY.value,
                    data={"i18n_key": "birthday.self", "type": "BIRTHDAY_SELF"},
                )
            except Exception as e:
                logger.warning("[birthday] self greeting failed for %s: %s", name_en, e)

            # 2. Their club.
            #
            # Deliberately NOT broadcast_to_tenant: that routes every message
            # through the AI rewriter, and a person's name is a fact, not copy
            # to be made more engaging. It is also two blocking model calls in
            # front of a greeting.
            try:
                svc.broadcast(
                    organization_id=org_id,
                    title_en=i18n.t("birthday.member.title", "en", name=name_en) or "",
                    title_ta=i18n.t("birthday.member.title", "ta", name=name_ta) or "",
                    body_en=i18n.t("birthday.member.body", "en") or "",
                    body_ta=i18n.t("birthday.member.body", "ta") or "",
                    notification_type=NotificationCategory.COMMUNITY.value,
                    data={
                        "i18n_key": "birthday.member",
                        "i18n_params": {"name": name_en},
                        "type": "BIRTHDAY_MEMBER",
                    },
                )
            except Exception as e:
                logger.warning("[birthday] club greeting failed for %s: %s", name_en, e)

            logger.info("[birthday] Notified for %s", name_en)

    except Exception as e:
        logger.error(f"[birthday] Error: {e}")
    finally:
        db.close()
