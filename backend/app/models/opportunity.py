import uuid
import enum
from sqlalchemy import Column, String, Boolean, Enum as SAEnum
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class OpportunityType(str, enum.Enum):
    VOLUNTEER = "VOLUNTEER"
    COURSE = "COURSE"


class Opportunity(Base, TimestampMixin, TenantModelMixin):
    """Volunteer opportunities and skill courses published by the organization."""
    __tablename__ = "opportunities"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    type = Column(SAEnum(OpportunityType), nullable=False)
    title_ta = Column(String(255), nullable=False)
    title_en = Column(String(255), nullable=False)
    organizer_ta = Column(String(100), nullable=True)
    organizer_en = Column(String(100), nullable=True)
    hours = Column(String(50), nullable=True)
    category_ta = Column(String(100), nullable=True)
    category_en = Column(String(100), nullable=True)
    location_ta = Column(String(200), nullable=True)
    location_en = Column(String(200), nullable=True)
    description_ta = Column(String(1000), nullable=True)
    description_en = Column(String(1000), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)


class OpportunityApplication(Base, TimestampMixin):
    """Records a user's application/enrollment for an opportunity."""
    __tablename__ = "opportunity_applications"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    opportunity_id = Column(GUID(), nullable=False)
    user_id = Column(GUID(), nullable=False)
    organization_id = Column(GUID(), nullable=False)
