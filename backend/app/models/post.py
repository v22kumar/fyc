import uuid

from sqlalchemy import Column, Text, ForeignKey, JSON, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class Post(Base, TimestampMixin, TenantModelMixin):
    """A user-authored community post: text and/or images."""

    __tablename__ = "posts"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    author_id = Column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    content = Column(Text, nullable=False, default="")
    image_urls = Column(JSON, nullable=True)  # list[str]

    author = relationship("User")


class PostLike(Base, TimestampMixin, TenantModelMixin):
    """One like per user per post."""

    __tablename__ = "post_likes"
    __table_args__ = (
        UniqueConstraint("post_id", "user_id", name="uq_post_like"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    post_id = Column(
        GUID(), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
