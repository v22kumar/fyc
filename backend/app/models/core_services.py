import uuid
from sqlalchemy import Column, String, Text, ForeignKey, JSON, Boolean
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class CommunityActivity(Base, TimestampMixin, TenantModelMixin):
    """
    A unified activity stream for everything happening on the platform.
    Examples: 
    - action_type: 'CREATED', 'RESOLVED', 'JOINED', 'UPLOADED'
    - entity_type: 'TOURNAMENT', 'ISSUE', 'EVENT', 'NEWS', etc.
    """
    __tablename__ = "community_activities"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    actor_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action_type = Column(String(50), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)
    message_en = Column(Text, nullable=True)
    message_ta = Column(Text, nullable=True)
    metadata_json = Column(JSON, nullable=True)

    actor = relationship("User")

class Follow(Base, TimestampMixin, TenantModelMixin):
    """
    Allows users to 'follow' or 'favorite' any entity (Tournament, Event, Team, NewsCategory).
    """
    __tablename__ = "follows"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)

    user = relationship("User")

class Comment(Base, TimestampMixin, TenantModelMixin):
    """
    Lightweight commenting system attached to any entity.
    """
    __tablename__ = "comments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    author_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)
    content = Column(Text, nullable=False)

    author = relationship("User")

class Attachment(Base, TimestampMixin, TenantModelMixin):
    """
    Unified attachment system (images, documents, PDFs).
    """
    __tablename__ = "attachments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    uploader_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)
    file_url = Column(Text, nullable=False)
    file_type = Column(String(50), nullable=True)  # e.g., 'image/png', 'application/pdf'
    description = Column(String(255), nullable=True)

class MediaLibraryItem(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Unified media library.
    Planned for future milestone: Advanced Media Management.
    """
    __tablename__ = "media_library"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    uploader_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    entity_type = Column(String(50), nullable=True)
    entity_id = Column(GUID(), nullable=True)
    file_url = Column(Text, nullable=False)
    file_type = Column(String(50), nullable=False)
    file_size_bytes = Column(JSON, nullable=True)
    description = Column(String(255), nullable=True)
    is_public = Column(Boolean, default=True)
    tags_json = Column(JSON, nullable=True)

    uploader = relationship("User")

class Tag(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Generic tagging system.
    Planned for future milestone: Advanced Search & Categorization.
    """
    __tablename__ = "tags"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    name = Column(String(50), nullable=False)
    category = Column(String(50), nullable=True)
    color_hex = Column(String(10), nullable=True)

class EntityTag(Base, TimestampMixin, TenantModelMixin):
    __tablename__ = "entity_tags"
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    tag_id = Column(GUID(), ForeignKey("tags.id", ondelete="CASCADE"), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)
    tag = relationship("Tag")

class SavedItem(Base, TimestampMixin, TenantModelMixin):
    """
    [FOUNDATIONAL] Allow users to save/bookmark items for later.
    Planned for future milestone: Personal Collections.
    """
    __tablename__ = "saved_items"
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(GUID(), nullable=False)
    user = relationship("User")
