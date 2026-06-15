import uuid
import enum
from sqlalchemy import Column, String, Text, Integer, Numeric, Boolean, Date, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class TreeStatus(str, enum.Enum):
    PLANTED = "PLANTED"
    GROWING = "GROWING"
    MATURE = "MATURE"
    DEAD = "DEAD"


class PlantationDrive(Base, TimestampMixin, TenantModelMixin):
    """
    A campaign or event that organises tree planting activity.
    Multiple trees (TreeRegistration) can be linked to a single drive.
    """
    __tablename__ = "plantation_drives"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    title_ta = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    description_ta = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)

    drive_date = Column(Date, nullable=False)

    location_ta = Column(String(200), nullable=True)
    location_en = Column(String(200), nullable=True)

    geography_id = Column(
        GUID(),
        ForeignKey("geographic_nodes.id", ondelete="SET NULL"),
        nullable=True,
    )

    target_count = Column(Integer, default=0)
    banner_url = Column(Text, nullable=True)

    created_by_user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    is_active = Column(Boolean, default=True)

    # Relationships
    trees = relationship("TreeRegistration", back_populates="drive")
    created_by = relationship("User", foreign_keys=[created_by_user_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])


class TreeRegistration(Base, TimestampMixin, TenantModelMixin):
    """
    An individual tree planted, optionally linked to a PlantationDrive.
    Tracks location, species, status, and growth photos.
    """
    __tablename__ = "tree_registrations"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    drive_id = Column(
        GUID(),
        ForeignKey("plantation_drives.id", ondelete="CASCADE"),
        nullable=True,
    )

    registered_by_user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    species_ta = Column(String(100), nullable=True)
    species_en = Column(String(100), nullable=True)

    latitude = Column(Numeric(10, 8), nullable=True)
    longitude = Column(Numeric(11, 8), nullable=True)

    geography_id = Column(
        GUID(),
        ForeignKey("geographic_nodes.id", ondelete="SET NULL"),
        nullable=True,
    )

    planted_date = Column(Date, nullable=False)

    photo_url = Column(Text, nullable=True)
    growth_photo_url = Column(Text, nullable=True)

    status = Column(
        SAEnum(TreeStatus, name="tree_status_enum"),
        default=TreeStatus.PLANTED,
        nullable=False,
    )

    notes = Column(Text, nullable=True)

    # Relationships
    drive = relationship("PlantationDrive", back_populates="trees")
    registered_by = relationship("User", foreign_keys=[registered_by_user_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])
