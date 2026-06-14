from pydantic import BaseModel, ConfigDict
from uuid import UUID
from typing import Optional
from app.models.geography import GeoLevel

class GeographicNodeCreate(BaseModel):
    parent_id: Optional[UUID] = None
    level: GeoLevel
    name_ta: str
    name_en: str
    pincode: Optional[str] = None

class GeographicNodeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    parent_id: Optional[UUID]
    level: GeoLevel
    name_ta: str
    name_en: str
    pincode: Optional[str]
