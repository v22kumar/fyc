from sqlalchemy import Column, String, Date, JSON
import uuid
from app.models.base import Base, GUID, TimestampMixin, TenantModelMixin

class AIContent(Base, TimestampMixin, TenantModelMixin):
    """Caches AI-generated content like Daily Digests and News Summaries."""
    __tablename__ = "ai_content"

    # Use the shared portable GUID() (SQLite + Postgres), like every other model —
    # the Postgres-only UUID type broke on the SQLite fallback.
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    content_type = Column(String(50), nullable=False, index=True) # e.g. "DAILY_DIGEST", "NEWS_SUMMARY"
    content_date = Column(Date, nullable=False, index=True)       # The date this content was generated for
    content_data = Column(JSON, nullable=False)                   # The parsed AI response or raw data
