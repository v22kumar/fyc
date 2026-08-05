from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.blood_donor import VALID_BLOOD_GROUPS  # noqa: F401 (shared vocab)

URGENCIES = ["CRITICAL", "URGENT", "ROUTINE"]


class BloodRequestCreate(BaseModel):
    patient_blood_group: str = Field(..., description="A+, A-, B+, B-, AB+, AB-, O+, O-")
    units_needed: int = Field(1, ge=1, le=20)
    hospital_name: Optional[str] = Field(None, max_length=200)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    urgency: str = Field("URGENT", pattern="^(CRITICAL|URGENT|ROUTINE)$")
    note: Optional[str] = Field(None, max_length=500)
    contact_phone: Optional[str] = Field(None, max_length=20)
    target_donor_id: Optional[UUID] = Field(
        None,
        description="Ask this one donor instead of alerting the neighbourhood.",
    )


class PledgeCreate(BaseModel):
    status: str = Field("ACCEPTED", pattern="^(ACCEPTED|DECLINED|DONATED)$")


class PledgeOut(BaseModel):
    id: UUID
    donor_user_id: UUID
    donor_name: Optional[str] = None
    # Only ever filled in for the requester, and only once this donor has
    # accepted. Saying yes is what turns a stranger's number into a call they
    # are expecting.
    donor_phone: Optional[str] = None
    status: str
    responded_at: Optional[datetime] = None


class BloodRequestOut(BaseModel):
    id: UUID
    patient_blood_group: str
    units_needed: int
    hospital_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    urgency: str
    note: Optional[str] = None
    contact_phone: Optional[str] = None
    status: str
    target_donor_name: Optional[str] = None
    notified_count: int = 0
    accepted_count: int = 0
    created_at: Optional[datetime] = None
    requester_name: Optional[str] = None


class BloodRequestDetailOut(BloodRequestOut):
    pledges: List[PledgeOut] = []
    # The caller's own pledge status for this request (if any), so the app can
    # show "You accepted" / "You declined".
    my_pledge: Optional[str] = None
