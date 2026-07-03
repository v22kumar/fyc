import json
import logging
import os
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone
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
            success = self._dispatch_push(user.fcm_token, title_en, body_en, data)
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

    def _dispatch_push(self, token: str, title: str, body: str, data: dict = None) -> bool:
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
                        channel_id="fyc_default",
                        default_sound=True,
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
            data = {"route": route} if route else None
            cls(db).broadcast(
                organization_id=tenant_id,
                title_en=title_en,
                title_ta=title_ta,
                body_en=body_en,
                body_ta=body_ta,
                notification_type=notification_type,
                data=data,
                target_roles=target_roles,
            )
        except Exception as e:  # pragma: no cover - best-effort delivery
            logger.warning(f"broadcast_to_tenant failed (non-fatal): {e}")

    def broadcast(self, organization_id: UUID, title_en: str, title_ta: str, body_en: str, body_ta: str, notification_type: str, data: Optional[dict] = None, target_roles: Optional[List[str]] = None):
        query = self.db.query(User).filter(User.organization_id == organization_id)
        if target_roles:
            query = query.filter(User.role.in_(target_roles))
            
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
