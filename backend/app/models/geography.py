import uuid
from sqlalchemy import Column, String, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin
import enum

class GeoLevel(str, enum.Enum):
    STATE = "STATE"
    DISTRICT = "DISTRICT"
    TALUK = "TALUK"
    VILLAGE = "VILLAGE"
    WARD = "WARD"
    STREET = "STREET"

class GeographicNode(Base, TimestampMixin):
    """
    Hierarchical geographic location tree (State → District → Taluk → Village → Ward → Street).
    Used to scope users, issues, and donors to a location.
    """
    __tablename__ = "geographic_nodes"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    parent_id = Column(GUID(), ForeignKey("geographic_nodes.id", ondelete="SET NULL"), nullable=True, index=True)
    level = Column(SAEnum(GeoLevel, name="geo_level"), nullable=False)
    name_ta = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=False)
    pincode = Column(String(10), nullable=True)

    # Self-referential: child.parent_id → parent.id (many-to-one from child's perspective)
    parent_node = relationship(
        "GeographicNode",
        foreign_keys=[parent_id],
        remote_side="GeographicNode.id",
        backref="children"
    )
