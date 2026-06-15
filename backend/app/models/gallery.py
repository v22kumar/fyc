import uuid
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class EventPhoto(Base, TimestampMixin, TenantModelMixin):
    """
    Photos uploaded to a specific event. Belongs to the same tenant as the
    parent event. Uploader link is nullable so photos survive user deletion.
    """
    __tablename__ = "event_photos"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    event_id = Column(
        GUID(),
        ForeignKey("events.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    uploaded_by_user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    photo_url = Column(Text, nullable=False)
    caption_ta = Column(String(200), nullable=True)
    caption_en = Column(String(200), nullable=True)
    taken_at = Column(DateTime(timezone=True), nullable=True)

    event = relationship("Event", foreign_keys=[event_id])
    uploader = relationship("User", foreign_keys=[uploaded_by_user_id])
