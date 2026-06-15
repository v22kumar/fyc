import uuid
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Numeric, UniqueConstraint
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class Event(Base, TimestampMixin, TenantModelMixin):
    """
    Community events created by Executive Members. Supports bilingual content and QR check-in.
    """
    __tablename__ = "events"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    title_ta = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    description_ta = Column(Text, nullable=False)
    description_en = Column(Text, nullable=False)
    event_start = Column(DateTime(timezone=True), nullable=False)
    event_end = Column(DateTime(timezone=True), nullable=False)
    banner_url = Column(Text, nullable=True)
    geography_id = Column(GUID(), ForeignKey("geographic_nodes.id", ondelete="SET NULL"), nullable=True)
    created_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    attendances = relationship("EventAttendance", back_populates="event", cascade="all, delete-orphan")
    creator = relationship("User", foreign_keys=[created_by_user_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])

class EventAttendance(Base):
    """
    Records volunteer/member check-ins at events via QR code scan.
    """
    __tablename__ = "event_attendances"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    event_id = Column(GUID(), ForeignKey("events.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    checked_in_at = Column(DateTime(timezone=True), nullable=False)
    checked_out_at = Column(DateTime(timezone=True), nullable=True)
    hours_accrued = Column(Numeric(5, 2), nullable=True)

    event = relationship("Event", back_populates="attendances")
    user = relationship("User", foreign_keys=[user_id])

    __table_args__ = (
        UniqueConstraint("event_id", "user_id", name="uq_event_attendance"),
    )
