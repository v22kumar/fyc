from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime

class OrganizationBase(BaseModel):
    slug: str = Field(..., max_length=50, description="Unique URL friendly slug")
    name_ta: str = Field(..., max_length=150, description="Tamil name of the organization")
    name_en: str = Field(..., max_length=150, description="English name of the organization")

class OrganizationCreate(OrganizationBase):
    pass

class OrganizationOut(OrganizationBase):
    id: UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
        # Pydantic v2 support for model attributes conversion
