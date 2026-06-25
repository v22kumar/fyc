import uuid
from sqlalchemy import Column, String, Text, ForeignKey, JSON, Boolean
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class OrganizationSettings(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Configurable settings for multi-tenant organizations.
    Planned for future milestone: Deep Organization Customization.
    """
    __tablename__ = "organization_settings"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    theme_colors_json = Column(JSON, nullable=True)
    contact_email = Column(String(100), nullable=True)
    contact_phone = Column(String(20), nullable=True)
    default_language = Column(String(10), default="ta")
    notification_preferences_json = Column(JSON, nullable=True)
    ui_config_json = Column(JSON, nullable=True)

class FeatureFlag(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Toggle features on/off per organization.
    """
    __tablename__ = "feature_flags"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    feature_code = Column(String(100), nullable=False)
    is_enabled = Column(Boolean, default=False)
    description = Column(String(200), nullable=True)
