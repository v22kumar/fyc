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
    # Which kind of local body governs this place — Corporation, Municipality,
    # Town Panchayat or Village Panchayat (see civic.LocalBodyType).
    #
    # The tree knew a place's *level* (taluk, village, ward) but not who runs
    # it, and those are different questions: a "VILLAGE" node inside Nagercoil
    # city is governed by a Corporation, and a complaint routed to a village
    # panchayat president there reaches nobody.
    #
    # Nullable, because it is only known for places somebody has filled in.
    # Resolution walks up to the parent when a node has not been classified.
    local_body_type = Column(String(30), nullable=True)

    # Self-referential: child.parent_id → parent.id (many-to-one from child's perspective)
    parent_node = relationship(
        "GeographicNode",
        foreign_keys=[parent_id],
        remote_side="GeographicNode.id",
        backref="children"
    )
