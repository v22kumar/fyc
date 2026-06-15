import uuid
import enum
from sqlalchemy import Column, String, Text, Boolean, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class AnnouncementCategory(str, enum.Enum):
    GENERAL = "GENERAL"
    BLOOD_REQUEST = "BLOOD_REQUEST"
    EVENT = "EVENT"
    OPPORTUNITY = "OPPORTUNITY"
    ALERT = "ALERT"
    GREEN_DRIVE = "GREEN_DRIVE"


class Announcement(Base, TimestampMixin, TenantModelMixin):
    """
    Notice board posts for a tenant: general notices, blood requests, events,
    opportunities, alerts, and green-drive campaigns. Pinned items float to
    the top; expired items are hidden from the default listing.
    """
    __tablename__ = "announcements"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    title_ta = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    body_ta = Column(Text, nullable=False)
    body_en = Column(Text, nullable=False)
    category = Column(
        SAEnum(AnnouncementCategory, name="announcement_category"),
        nullable=False
    )
    is_pinned = Column(Boolean, default=False, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    banner_url = Column(Text, nullable=True)
    created_by_user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    geography_id = Column(
        GUID(),
        ForeignKey("geographic_nodes.id", ondelete="SET NULL"),
        nullable=True
    )

    creator = relationship("User", foreign_keys=[created_by_user_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])
