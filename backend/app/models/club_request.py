import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, func
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class ClubMemberRequest(Base, TimestampMixin, TenantModelMixin):
    """
    Tracks pending/approved/rejected requests for CLUB_MEMBER role.
    When a user registers with role=CLUB_MEMBER they are stored as
    PUBLIC_CITIZEN and a PENDING request is created here. An admin
    must approve before the user gains the CLUB_MEMBER role.
    """
    __tablename__ = "club_member_requests"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    requested_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    status = Column(String(20), nullable=False, default="PENDING")  # PENDING | APPROVED | REJECTED
    reviewed_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
