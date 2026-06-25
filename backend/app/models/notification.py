import uuid
from sqlalchemy import Column, String, Boolean, JSON, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class Notification(Base, TimestampMixin, TenantModelMixin):
    """
    Centralized notifications for users.
    Types: DAILY, EVENT, COMMUNITY, ADMIN
    """
    __tablename__ = "notifications"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title_en = Column(String(255), nullable=False)
    title_ta = Column(String(255), nullable=False)
    body_en = Column(String(1024), nullable=False)
    body_ta = Column(String(1024), nullable=False)
    notification_type = Column(String(50), nullable=False) # 'DAILY', 'EVENT', 'COMMUNITY', 'ADMIN'
    is_read = Column(Boolean(), default=False)
    data = Column(JSON, nullable=True) # Custom payload for navigation (e.g. {"route": "/tournament/123"})
    
    # Relationships
    user = relationship("User", backref="notifications")

class NotificationPreference(Base, TimestampMixin, TenantModelMixin):
    """
    User notification preferences for controlling delivery channels and topics.
    """
    __tablename__ = "notification_preferences"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Delivery Channels
    push_enabled = Column(Boolean(), default=True)
    whatsapp_enabled = Column(Boolean(), default=True)
    sms_enabled = Column(Boolean(), default=False) # Opt-in usually due to cost
    email_enabled = Column(Boolean(), default=True)

    # Topics
    news_enabled = Column(Boolean(), default=True)
    sports_enabled = Column(Boolean(), default=True)
    community_enabled = Column(Boolean(), default=True)
    events_enabled = Column(Boolean(), default=True)

    __table_args__ = (
        UniqueConstraint("organization_id", "user_id", name="uq_org_user_notif_pref"),
    )
    
    user = relationship("User", backref="notification_preferences")
