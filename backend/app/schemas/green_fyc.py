import enum
from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import date
from typing import Optional


class TreeStatus(str, enum.Enum):
    PLANTED = "PLANTED"
    GROWING = "GROWING"
    MATURE = "MATURE"
    DEAD = "DEAD"


# ---------------------------------------------------------------------------
# PlantationDrive schemas
# ---------------------------------------------------------------------------

class DriveCreate(BaseModel):
    title_ta: str
    title_en: str
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    drive_date: date
    location_ta: Optional[str] = None
    location_en: Optional[str] = None
    geography_id: Optional[UUID] = None
    target_count: int = 0
    banner_url: Optional[str] = None
    is_active: bool = True


class DriveUpdate(BaseModel):
    title_ta: Optional[str] = None
    title_en: Optional[str] = None
    description_ta: Optional[str] = None
    description_en: Optional[str] = None
    drive_date: Optional[date] = None
    location_ta: Optional[str] = None
    location_en: Optional[str] = None
    geography_id: Optional[UUID] = None
    target_count: Optional[int] = None
    banner_url: Optional[str] = None
    is_active: Optional[bool] = None


class DriveOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organization_id: UUID
    title_ta: str
    title_en: str
    description_ta: Optional[str]
    description_en: Optional[str]
    drive_date: date
    location_ta: Optional[str]
    location_en: Optional[str]
    geography_id: Optional[UUID]
    target_count: int
    banner_url: Optional[str]
    created_by_user_id: Optional[UUID]
    is_active: bool
    tree_count: int = 0


# ---------------------------------------------------------------------------
# TreeRegistration schemas
# ---------------------------------------------------------------------------

class TreeCreate(BaseModel):
    drive_id: Optional[UUID] = None
    species_ta: Optional[str] = None
    species_en: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    geography_id: Optional[UUID] = None
    planted_date: date
    photo_url: Optional[str] = None
    notes: Optional[str] = None


class TreeUpdate(BaseModel):
    species_ta: Optional[str] = None
    species_en: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    geography_id: Optional[UUID] = None
    planted_date: Optional[date] = None
    photo_url: Optional[str] = None
    notes: Optional[str] = None


class TreeGrowthUpdate(BaseModel):
    growth_photo_url: str
    status: TreeStatus


class TreeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organization_id: UUID
    drive_id: Optional[UUID]
    registered_by_user_id: Optional[UUID]
    species_ta: Optional[str]
    species_en: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    geography_id: Optional[UUID]
    planted_date: date
    photo_url: Optional[str]
    growth_photo_url: Optional[str]
    status: TreeStatus
    notes: Optional[str]
