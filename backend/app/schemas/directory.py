from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional
from app.models.directory import ContactCategory


class ContactCreate(BaseModel):
    category: ContactCategory
    name_ta: str
    name_en: str
    designation_ta: Optional[str] = None
    designation_en: Optional[str] = None
    phone_primary: str
    phone_secondary: Optional[str] = None
    whatsapp_number: Optional[str] = None
    address_ta: Optional[str] = None
    address_en: Optional[str] = None
    geography_id: Optional[UUID] = None
    is_active: bool = True
    display_order: int = 0


class ContactUpdate(BaseModel):
    category: Optional[ContactCategory] = None
    name_ta: Optional[str] = None
    name_en: Optional[str] = None
    designation_ta: Optional[str] = None
    designation_en: Optional[str] = None
    phone_primary: Optional[str] = None
    phone_secondary: Optional[str] = None
    whatsapp_number: Optional[str] = None
    address_ta: Optional[str] = None
    address_en: Optional[str] = None
    geography_id: Optional[UUID] = None
    is_active: Optional[bool] = None
    display_order: Optional[int] = None


class ContactOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    category: ContactCategory
    name_ta: str
    name_en: str
    designation_ta: Optional[str]
    designation_en: Optional[str]
    phone_primary: str
    phone_secondary: Optional[str]
    whatsapp_number: Optional[str]
    address_ta: Optional[str]
    address_en: Optional[str]
    geography_id: Optional[UUID]
    geography_name_en: Optional[str] = None
    geography_name_ta: Optional[str] = None
    is_active: bool
    display_order: int
    organization_id: UUID
    created_at: datetime
    updated_at: datetime
