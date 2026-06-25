import uuid
from sqlalchemy import Column, String, Text, ForeignKey, JSON, Boolean
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class FormDefinition(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Defines a dynamic form structure.
    Planned for future milestone: Dynamic Surveys & Applications.
    """
    __tablename__ = "form_definitions"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    entity_type = Column(String(50), nullable=True)
    entity_id = Column(GUID(), nullable=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    fields_schema = Column(JSON, nullable=False)

    submissions = relationship("FormSubmission", back_populates="form_definition", cascade="all, delete-orphan")

class FormSubmission(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Stores responses to a dynamic form.
    """
    __tablename__ = "form_submissions"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    form_id = Column(GUID(), ForeignKey("form_definitions.id", ondelete="CASCADE"), nullable=False)
    submitter_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    response_data = Column(JSON, nullable=False)
    
    form_definition = relationship("FormDefinition", back_populates="submissions")
    submitter = relationship("User")
