import uuid
from sqlalchemy import (
    Column, String, Integer, Float, ForeignKey, UniqueConstraint, Index,
)
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class BloodRequest(Base, TimestampMixin, TenantModelMixin):
    """An emergency/scheduled request for blood. On creation the server fans out
    push alerts to nearby, compatible, eligible, opted-in FYC donors."""

    __tablename__ = "blood_requests"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    requester_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    patient_blood_group = Column(String(5), nullable=False)
    units_needed = Column(Integer, default=1)
    hospital_name = Column(String(200), nullable=True)
    # Where the blood is needed — drives the proximity fan-out + donor distance.
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    urgency = Column(String(12), nullable=False, default="URGENT")  # CRITICAL / URGENT / ROUTINE
    note = Column(String(500), nullable=True)
    contact_phone = Column(String(20), nullable=True)
    # OPEN → FULFILLED / CLOSED / EXPIRED
    status = Column(String(12), nullable=False, default="OPEN")
    notified_count = Column(Integer, default=0)

    __table_args__ = (
        Index("ix_breq_org_status", "organization_id", "status"),
    )


class BloodPledge(Base, TimestampMixin, TenantModelMixin):
    """A donor's response to a request — accepted / declined / donated."""

    __tablename__ = "blood_pledges"
    __table_args__ = (
        UniqueConstraint("request_id", "donor_user_id", name="uq_blood_pledge"),
        Index("ix_bpledge_request", "request_id"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    request_id = Column(
        GUID(), ForeignKey("blood_requests.id", ondelete="CASCADE"), nullable=False
    )
    donor_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # ACCEPTED (on my way / willing) / DECLINED / DONATED
    status = Column(String(12), nullable=False, default="ACCEPTED")
