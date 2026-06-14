import uuid
from sqlalchemy import Column, String, JSON
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class AuditLog(Base, TimestampMixin, TenantModelMixin):
    """
    Tracks administrative and critical user actions for transparency (SNO-007).
    """
    __tablename__ = "audit_logs"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), nullable=True)  # Nullable if action is anonymous public
    action_type = Column(String(100), nullable=False)  # e.g., 'STATUS_CHANGE_ISSUE', 'CONTACT_EXTRACTION_DONOR'
    target_table = Column(String(50), nullable=False)
    target_id = Column(GUID(), nullable=False)
    old_values = Column(JSON, nullable=True)
    new_values = Column(JSON, nullable=True)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(255), nullable=True)
