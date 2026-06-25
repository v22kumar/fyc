import uuid
from sqlalchemy import Column, String, Text, ForeignKey, JSON, Boolean, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class WorkflowState(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Defines available states for a generic workflow (e.g., Draft, Published).
    Planned for future milestone: Advanced Workflow Configuration.
    """
    __tablename__ = "workflow_states"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    entity_type = Column(String(50), nullable=False)
    state_code = Column(String(50), nullable=False)
    description = Column(String(200), nullable=True)
    is_initial = Column(Boolean, default=False)
    is_terminal = Column(Boolean, default=False)

class ApprovalRequest(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Generic approval request for any entity.
    Planned for future milestone: Universal Approval Engine.
    """
    __tablename__ = "approval_requests"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)
    requester_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), default="PENDING") # PENDING, APPROVED, REJECTED
    reviewer_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    review_notes = Column(Text, nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    
    requester = relationship("User", foreign_keys=[requester_id])
    reviewer = relationship("User", foreign_keys=[reviewer_id])
