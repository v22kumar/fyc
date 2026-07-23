from sqlalchemy import Column, String, Date, JSON
from sqlalchemy.dialects.postgresql import UUID
import uuid
from app.models.base import Base, TimestampMixin, TenantModelMixin

class AIContent(Base, TimestampMixin, TenantModelMixin):
    """Caches AI-generated content like Daily Digests and News Summaries."""
    __tablename__ = "ai_content"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content_type = Column(String(50), nullable=False, index=True) # e.g. "DAILY_DIGEST", "NEWS_SUMMARY"
    content_date = Column(Date, nullable=False, index=True)       # The date this content was generated for
    content_data = Column(JSON, nullable=False)                   # The parsed AI response or raw data
