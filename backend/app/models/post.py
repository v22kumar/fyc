import uuid

from sqlalchemy import Column, Text, String, ForeignKey, JSON, UniqueConstraint, Boolean
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
    # Category shown as a tab/chip: General, Cricket, Events, Environment,
    # Achievements, Announcement, Other.
    category = Column(String(30), nullable=True)
    # Where the post lives: "thread" (community feed) or "instagram" (also
    # cross-posted to the club Instagram page).
    source = Column(String(20), nullable=True, default="thread")
    location = Column(String(200), nullable=True)
    is_hidden = Column(Boolean(), default=False)
    idempotency_key = Column(String(100), nullable=True, index=True)

    author = relationship("User")


class PostRepost(Base, TimestampMixin, TenantModelMixin):
    """One repost per user per post (like a retweet)."""

    __tablename__ = "post_reposts"
    __table_args__ = (
        UniqueConstraint("post_id", "user_id", name="uq_post_repost"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    post_id = Column(
        GUID(), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )


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
