import uuid
from sqlalchemy import Column, String, Boolean, Integer, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

CATEGORIES = [
    "carpenter", "electrician", "plumber", "mason", "painter",
    "mechanic", "ac_technician", "mobile_repair", "welder",
    "tailor", "tutor", "doctor", "nurse", "lawyer", "accountant",
    "photographer", "driver", "caterer", "event_organizer",
    "grocery", "hardware", "pharmacy", "printing", "computer_service",
    "other",
]

class CommunityProfile(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "community_profiles"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    category = Column(String(50), nullable=False)
    business_name_ta = Column(String(150), nullable=True)
    business_name_en = Column(String(150), nullable=True)
    description_ta = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)
    contact_phone = Column(String(15), nullable=True)
    contact_whatsapp = Column(String(15), nullable=True)
    service_area = Column(String(200), nullable=True)
    years_experience = Column(Integer, nullable=True)
    is_available = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)

    user = relationship("User", foreign_keys=[user_id])
