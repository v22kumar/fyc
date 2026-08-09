import json
import logging
import os
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone
from sqlalchemy import or_
from sqlalchemy.orm import Session
from uuid import UUID

import firebase_admin
from firebase_admin import credentials, messaging
from app.core.config import settings
from app.models.notification import Notification, NotificationPreference
from app.models.user import User
from app.services.whatsapp_service import whatsapp_queue

logger = logging.getLogger(__name__)


def _init_firebase() -> None:
    """Initialise firebase-admin from an explicit service-account credential.

    Order of preference: FIREBASE_CREDENTIALS_JSON (inline JSON, ideal for
    Fly.io secrets) → FIREBASE_CREDENTIALS_PATH (file) → application-default
    (GOOGLE_APPLICATION_CREDENTIALS). If none is available, push is disabled
    but the app keeps running (in-app notifications still work)."""
    if firebase_admin._apps:
        return
    try:
        cred = None
        if settings.FIREBASE_CREDENTIALS_JSON.strip():
            cred = credentials.Certificate(json.loads(settings.FIREBASE_CREDENTIALS_JSON))
        elif settings.FIREBASE_CREDENTIALS_PATH.strip():
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)

        if cred is not None:
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin initialised — push notifications enabled.")
        elif os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
            # Only use application-default creds when explicitly pointed at a key
            # file; otherwise leave Firebase uninitialised so we don't attempt
            # doomed sends on every notification.
            firebase_admin.initialize_app()
            logger.info("Firebase Admin initialised from application-default credentials.")
        else:
            logger.info(
                "Firebase credentials not set — push disabled (in-app notifications "
                "still work). Set FIREBASE_CREDENTIALS_JSON to enable tray pushes."
            )
    except Exception as e:
        logger.warning(
            "Firebase Admin not initialised — push notifications disabled "
            f"(set FIREBASE_CREDENTIALS_JSON to enable): {e}"
        )


_init_firebase()

class NotificationService:
    def __init__(self, db: Session):
        self.db = db
        self.whatsapp_queue = whatsapp_queue

    def get_preferences(self, user_id: UUID, organization_id: UUID) -> NotificationPreference:
        pref = self.db.query(NotificationPreference).filter(
            NotificationPreference.user_id == user_id,
            NotificationPreference.organization_id == organization_id
        ).first()
        if not pref:
            pref = NotificationPreference(
                user_id=user_id,
                organization_id=organization_id
            )
            self.db.add(pref)
            self.db.commit()
            self.db.refresh(pref)
        return pref

    def update_preferences(self, user_id: UUID, organization_id: UUID, prefs_data: dict) -> NotificationPreference:
        pref = self.get_preferences(user_id, organization_id)
        for key, value in prefs_data.items():
            if hasattr(pref, key):
                setattr(pref, key, value)
        self.db.commit()
        self.db.refresh(pref)
        return pref

    def _push_text(self, user, title_en, title_ta, body_en, body_ta, data):
        """Pick the push title/body in the user's language.

        If the notification carries an ``i18n_key`` in ``data``, the text is
        resolved from the central registry (``app.core.i18n``) in the user's
        language — so pushes localize to ANY registered language, not just
        Tamil/English. Otherwise it falls back to the stored en/ta columns
        (Tamil for Tamil members, English for everyone else)."""
        from app.core import i18n

        lang = i18n._norm(getattr(user, "preferred_language", None) or "en")
        key = (data or {}).get("i18n_key")
        params = (data or {}).get("i18n_params") or {}

        def col(en, ta):
            return ta if lang.startswith("ta") else en

        # Title and body resolve independently: a digest can localize its static
        # title from the registry while its dynamic body (a headline, a kural)
        # falls back to the stored column.
        title = (i18n.t(f"{key}.title", lang, **params) if key else None) or col(title_en, title_ta)
        body = (i18n.t(f"{key}.body", lang, **params) if key else None) or col(body_en, body_ta)
        return title, body

    @staticmethod
    def _tray_data(data):
        """Strip i18n control keys so they never leak into the FCM payload."""
        if not data:
            return data
        return {k: v for k, v in data.items() if k not in ("i18n_key", "i18n_params")}

    def send_notification(self,
                          user_id: UUID, 
                          organization_id: UUID, 
                          title_en: str, 
                          title_ta: str, 
                          body_en: str, 
                          body_ta: str, 
                          notification_type: str, 
                          data: Optional[Dict[str, Any]] = None):
        
        pref = self.get_preferences(user_id, organization_id)
        user = self.db.query(User).filter(User.id == user_id).first()

        if not user:
            return

        # Category Filtering mapping
        type_mapping = {
            "NEWS": pref.news_enabled,
            "EVENT": pref.events_enabled,
            "COMMUNITY": pref.community_enabled,
            "TOURNAMENT": pref.sports_enabled,
            "SYSTEM": True # System always enabled
        }
        
        enabled = type_mapping.get(notification_type, True)
        if not enabled:
            return

        # Save to DB
        notification = Notification(
            user_id=user_id,
            organization_id=organization_id,
            title_en=title_en,
            title_ta=title_ta,
            body_en=body_en,
            body_ta=body_ta,
            notification_type=notification_type,
            data=data,
            sent_at=datetime.now(timezone.utc)
        )
        self.db.add(notification)
        self.db.commit()
        self.db.refresh(notification)

        channels = []

        if pref.push_enabled and user.fcm_token:
            # Dispatch in the user's language — the tray only shows one title/body.
            # Resolves ANY registered language via an optional i18n_key in data,
            # else falls back to the stored en/ta columns.
            _title, _body = self._push_text(user, title_en, title_ta, body_en, body_ta, data)
            success = self._dispatch_push(
                user.fcm_token,
                _title,
                _body,
                self._tray_data(data),
            )
            if success:
                channels.append("FCM")
                notification.delivered_at = datetime.now(timezone.utc)

        if pref.whatsapp_enabled and user.phone_number:
            success = self.whatsapp_queue.enqueue_template(
                phone=user.phone_number,
                template_name=notification_type.lower(),
                parameters={"title": title_en, "body": body_en}
            )
            if success: channels.append("WHATSAPP")

        if pref.sms_enabled and user.phone_number and notification_type in ["SYSTEM", "COMMUNITY"]:
            channels.append("SMS")

        if pref.email_enabled and user.email:
            channels.append("EMAIL")

        notification.delivery_channel = ",".join(channels)
        self.db.commit()

    def send_push_only(self,
                       user_id: UUID,
                       organization_id: UUID,
                       title_en: str,
                       title_ta: str,
                       body_en: str,
                       body_ta: str,
                       notification_type: str,
                       data: Optional[Dict[str, Any]] = None,
                       channel_id: Optional[str] = None):
        """Push + in-app record only — no WhatsApp / SMS / email fan-out.

        `channel_id` picks the Android notification channel, and for one
        message type that is the whole difference between arriving and being
        missed: an SOS goes on `fyc_sos`, whose sound is the siren played at
        alarm volume, so it rings through a silenced phone at two in the
        morning. A channel's sound is fixed by Android when the channel is
        created, which is why urgency has to be a channel rather than a flag.

        For transient, real-time alerts (e.g. a live chess challenge) where
        blasting WhatsApp or email on every event would be spammy and
        inappropriate. Still respects the user's push_enabled preference and
        requires an fcm_token; falls back to just the in-app record if push
        isn't available.
        """
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return

        pref = self.get_preferences(user_id, organization_id)

        notification = Notification(
            user_id=user_id,
            organization_id=organization_id,
            title_en=title_en,
            title_ta=title_ta,
            body_en=body_en,
            body_ta=body_ta,
            notification_type=notification_type,
            data=data,
            sent_at=datetime.now(timezone.utc),
        )
        self.db.add(notification)
        self.db.commit()
        self.db.refresh(notification)

        if pref.push_enabled and user.fcm_token:
            _title, _body = self._push_text(user, title_en, title_ta, body_en, body_ta, data)
            if self._dispatch_push(
                user.fcm_token,
                _title,
                _body,
                self._tray_data(data),
                channel_id=channel_id,
            ):
                notification.delivered_at = datetime.now(timezone.utc)
                notification.delivery_channel = "FCM"
                self.db.commit()

    def _dispatch_push(self, token: str, title: str, body: str, data: dict = None,
                       channel_id: Optional[str] = None) -> bool:
        if not firebase_admin._apps:
            logger.warning("FCM skipped (firebase not initialized).")
            return False
            
        try:
            # Prepare FCM Message. AndroidConfig with high priority + an explicit
            # channel_id makes Android reliably post to the system tray when the
            # app is backgrounded/killed (the channel is created app-side).
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id=channel_id or "fyc_default",
                        # The SOS channel carries its own sound — the siren, at
                        # alarm volume. Asking for the default here would
                        # replace it with a notification blip.
                        default_sound=(channel_id != "fyc_sos"),
                        sound=None if channel_id != "fyc_sos" else "sos_siren",
                    ),
                ),
                data={k: str(v) for k, v in (data or {}).items()},
                token=token,
            )
            response = messaging.send(message)
            logger.info(f"FCM message sent successfully: {response}")
            return True
        except Exception as e:
            logger.error(f"FCM Send Error: {e}")
            return False

    @classmethod
    def broadcast_to_tenant(
        cls,
        db: Session,
        tenant_id: UUID,
        category,
        title_en: str,
        title_ta: str,
        body_en: str,
        body_ta: str,
        route: Optional[str] = None,
        target_roles: Optional[List[str]] = None,
    ):
        """Convenience entry point used by routers: broadcast a categorized
        notification to every user in a tenant. Never raises into the caller —
        notification delivery must not break the primary action (e.g. scoring)."""
        try:
            notification_type = getattr(category, "value", str(category))
            
            # Rewrite notification using AI
            from app.services.ai_service import AIService
            ai_svc = AIService(db)
            smart_en = ai_svc.generate_smart_notification(title_en, body_en, notification_type)
            smart_ta = ai_svc.generate_smart_notification(title_ta, body_ta, notification_type)
            
            title_en = smart_en["title"]
            body_en = smart_en["body"]
            title_ta = smart_ta["title"]
            body_ta = smart_ta["body"]

            data = {"route": route} if route else None
            
            svc = cls(db)
            svc.broadcast(
                tenant_id,
                title_en,
                title_ta,
                body_en,
                body_ta,
                notification_type,
                data,
                target_roles,
            )
        except Exception as e:  # pragma: no cover - best-effort delivery
            logger.warning(f"broadcast_to_tenant failed (non-fatal): {e}")

    def broadcast(self, organization_id: UUID, title_en: str, title_ta: str, body_en: str, body_ta: str, notification_type: str, data: Optional[dict] = None, target_roles: Optional[List[str]] = None):
        query = self.db.query(User).filter(User.organization_id == organization_id)
        if target_roles:
            query = query.filter(User.role.in_(target_roles))
        else:
            # Everyone who is actually a member of this club.
            #
            # This used to read `role.in_(["SUPER_ADMIN", "ADMIN", "MEMBER"])`.
            # "MEMBER" is not a role this app assigns — the roles are
            # PUBLIC_CITIZEN, VOLUNTEER, CLUB_MEMBER, EXECUTIVE_MEMBER, ADMIN
            # and SUPER_ADMIN — so every broadcast since it was written reached
            # administrators and nobody else. Announcements, new events, new
            # tournaments: all of them, to a handful of people.
            #
            # The intent behind it was right and is kept: do not send club news
            # to Friends2Support directory contacts, who never joined and never
            # asked. That is now expressible directly, against the flag that
            # actually marks them, instead of through a role that cannot carry
            # the distinction.
            query = query.filter(
                or_(User.source.is_(None), User.source != "F2S_IMPORT")
            )
            
        for u in query.all():
            self.send_notification(
                user_id=u.id,
                organization_id=organization_id,
                title_en=title_en,
                title_ta=title_ta,
                body_en=body_en,
                body_ta=body_ta,
                notification_type=notification_type,
                data=data
            )
