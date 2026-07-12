import uuid
import enum
from sqlalchemy import Column, String, Boolean, Enum as SAEnum
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class OpportunityType(str, enum.Enum):
    JOB = "JOB"              # a paid gig — carries a budget
    VOLUNTEER = "VOLUNTEER"  # unpaid community work
    COURSE = "COURSE"        # legacy only — retained so old rows parse; not posted or listed


# Types surfaced in the Jobs marketplace. COURSE is deliberately excluded — it is
# a retired concept folded into the Skills directory (see the re-architecture spec).
MARKETPLACE_TYPES = {OpportunityType.JOB.value, OpportunityType.VOLUNTEER.value}


class Opportunity(Base, TimestampMixin, TenantModelMixin):
    """A marketplace posting members apply to — a paid job or a volunteer drive."""
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
    # Pay/budget display, e.g. "₹500/day" or "₹2,000 fixed". Null ⇒ unspecified
    # (volunteer drives leave this empty). Informational only — no in-app payments.
    budget = Column(String(60), nullable=True)
    # How an applicant reaches the poster. Member-only: never returned on the
    # public list, only via the authenticated detail endpoint.
    contact_phone = Column(String(15), nullable=True)
    # The member who posted this (marketplace authorship). Null for legacy rows.
    posted_by = Column(GUID(), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)


class OpportunityApplication(Base, TimestampMixin):
    """Records a user's application/enrollment for an opportunity."""
    __tablename__ = "opportunity_applications"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    opportunity_id = Column(GUID(), nullable=False)
    user_id = Column(GUID(), nullable=False)
    organization_id = Column(GUID(), nullable=False)
