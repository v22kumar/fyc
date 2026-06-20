import uuid
from sqlalchemy import Column, String, Boolean, Date, ForeignKey, Index
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class BloodDonor(Base, TimestampMixin, TenantModelMixin):
    """
    Blood donor registry. Supports anonymous searching (name/location visible),
    but contact details are gated behind authenticated request + audit log.
    """
    __tablename__ = "blood_donors"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    blood_group = Column(String(5), nullable=False)  # 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
    geography_id = Column(GUID(), ForeignKey("geographic_nodes.id", ondelete="SET NULL"), nullable=True)
    is_available = Column(Boolean(), default=True)
    last_donation_date = Column(Date, nullable=True)

    user = relationship("User", foreign_keys=[user_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])

    __table_args__ = (
        Index("ix_bd_org_bg_avail", "organization_id", "blood_group", "is_available"),
        Index("ix_bd_geography", "geography_id"),
    )
