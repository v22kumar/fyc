import logging
from sqlalchemy.orm import Session
from uuid import UUID
from typing import List, Dict, Any, Optional
from app.models.notification import Notification, NotificationPreference
from app.models.user import User
import uuid

logger = logging.getLogger(__name__)

class NotificationService:
    def __init__(self, db: Session):
        self.db = db

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
        """
        Main entry point for sending a notification to a specific user.
        Evaluates user preferences and dispatches to appropriate channels.
        """
        pref = self.get_preferences(user_id, organization_id)
        user = self.db.query(User).filter(User.id == user_id).first()

        if not user:
            return

        # 1. Topic filtering
        if notification_type == "NEWS" and not pref.news_enabled: return
        if notification_type == "EVENT" and not pref.events_enabled: return
        if notification_type == "COMMUNITY" and not pref.community_enabled: return
        if notification_type == "SPORTS" and not pref.sports_enabled: return

        # 2. In-App Notification (Always stored)
        notification = Notification(
            user_id=user_id,
            organization_id=organization_id,
            title_en=title_en,
            title_ta=title_ta,
            body_en=body_en,
            body_ta=body_ta,
            notification_type=notification_type,
            data=data
        )
        self.db.add(notification)
        self.db.commit()

        # 3. Push Notification (FCM)
        if pref.push_enabled and user.fcm_token:
            self._dispatch_push(user.fcm_token, title_en, body_en, data)

        # 4. WhatsApp
        if pref.whatsapp_enabled and user.phone_number:
            self._dispatch_whatsapp(user.phone_number, title_en, body_en)

        # 5. SMS (usually reserved for OTP/emergencies)
        if pref.sms_enabled and user.phone_number and notification_type in ["EMERGENCY", "OTP"]:
            self._dispatch_sms(user.phone_number, body_en)

        # 6. Email
        if pref.email_enabled and user.email:
            self._dispatch_email(user.email, title_en, body_en)

    def _dispatch_push(self, token: str, title: str, body: str, data: dict = None):
        logger.info(f"FCM -> {token}: {title} - {body}")
        # Integration with firebase_admin goes here

    def _dispatch_whatsapp(self, phone: str, title: str, body: str):
        logger.info(f"WhatsApp -> {phone}: {title} - {body}")
        # Integration with WhatsApp API goes here

    def _dispatch_sms(self, phone: str, body: str):
        logger.info(f"SMS -> {phone}: {body}")
        # Integration with SMS API goes here

    def _dispatch_email(self, email: str, title: str, body: str):
        logger.info(f"Email -> {email}: {title} - {body}")
        # Integration with SendGrid/SMTP goes here

    def broadcast(self, organization_id: UUID, title_en: str, title_ta: str, body_en: str, body_ta: str, notification_type: str, data: Optional[dict] = None, target_roles: Optional[List[str]] = None):
        """
        Broadcast to all users or specific roles.
        """
        query = self.db.query(User).filter(User.organization_id == organization_id)
        if target_roles:
            query = query.filter(User.role.in_(target_roles))
            
        users = query.all()
        for u in users:
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
