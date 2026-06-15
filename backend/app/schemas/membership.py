from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional

class MembershipCardGenerate(BaseModel):
    user_id: UUID
    designation_ta: Optional[str] = "உறுப்பினர்"
    designation_en: Optional[str] = "Member"
    expires_at: datetime

class MembershipCardOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    membership_number: str
    qr_code_payload: str
    status: str
    designation_ta: str
    designation_en: str
    issued_at: Optional[datetime]
    expires_at: datetime
