import uuid
from sqlalchemy import Column, String, Text, Numeric, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin
import enum

class IssueCategory(str, enum.Enum):
    ROAD = "ROAD"
    WATER = "WATER"
    STREET_LIGHT = "STREET_LIGHT"
    GARBAGE = "GARBAGE"
    SAFETY = "SAFETY"
    OTHER = "OTHER"

class IssueStatus(str, enum.Enum):
    NEW = "NEW"
    ASSIGNED = "ASSIGNED"
    UNDER_REVIEW = "UNDER_REVIEW"
    ESCALATED = "ESCALATED"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"
    REJECTED = "REJECTED"

# Valid status transitions for the state machine
VALID_TRANSITIONS = {
    IssueStatus.NEW: {IssueStatus.ASSIGNED, IssueStatus.REJECTED},
    IssueStatus.ASSIGNED: {IssueStatus.UNDER_REVIEW, IssueStatus.ESCALATED},
    IssueStatus.UNDER_REVIEW: {IssueStatus.RESOLVED, IssueStatus.ESCALATED},
    IssueStatus.ESCALATED: {IssueStatus.UNDER_REVIEW, IssueStatus.RESOLVED},
    IssueStatus.RESOLVED: {IssueStatus.CLOSED},
    IssueStatus.CLOSED: set(),
    IssueStatus.REJECTED: set(),
}

class PublicIssue(Base, TimestampMixin, TenantModelMixin):
    """
    Community-reported infrastructure/safety issues with a strict state machine workflow.
    """
    __tablename__ = "public_issues"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    reported_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    category = Column(SAEnum(IssueCategory, name="issue_category"), nullable=False)
    description_ta = Column(Text, nullable=False)
    description_en = Column(Text, nullable=False)
    latitude = Column(Numeric(10, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    geography_id = Column(GUID(), ForeignKey("geographic_nodes.id", ondelete="SET NULL"), nullable=True)
    photo_url = Column(Text, nullable=True)
    verification_photo_url = Column(Text, nullable=True)
    status = Column(SAEnum(IssueStatus, name="issue_status"), default=IssueStatus.NEW, nullable=False)
    assigned_volunteer_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    reporter = relationship("User", foreign_keys=[reported_by_user_id])
    assigned_volunteer = relationship("User", foreign_keys=[assigned_volunteer_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])
