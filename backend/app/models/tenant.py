import uuid
from sqlalchemy import Column, String, Boolean
from app.core.database import Base
from app.models.base import GUID, TimestampMixin

class Organization(Base, TimestampMixin):
    """
    Multi-tenant Organization table.
    Enables data isolation for different branches, clubs, or associations.
    """
    __tablename__ = "organizations"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    slug = Column(String(50), unique=True, nullable=False, index=True)
    name_ta = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=False)
    is_active = Column(Boolean(), default=True)
