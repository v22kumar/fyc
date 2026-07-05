import uuid

from sqlalchemy import Column, Text, String, ForeignKey, JSON, UniqueConstraint, Boolean, Index, text
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class Post(Base, TimestampMixin, TenantModelMixin):
    """A user-authored community post: text and/or images."""

    __tablename__ = "posts"
    __table_args__ = (
        # Enforce idempotency at the DB boundary: at most one post per
        # (org, author, idempotency_key). Partial (WHERE key IS NOT NULL) so the
        # many NULL-key rows (posts created without a key) are unconstrained.
        Index(
            "uq_post_idempotency",
            "organization_id", "author_id", "idempotency_key",
            unique=True,
            sqlite_where=text("idempotency_key IS NOT NULL"),
        ),
    )

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
    # server_default so newly-created rows are never NULL at the DB level; the
    # feed query also treats NULL as not-hidden for rows that predate this column.
    is_hidden = Column(Boolean(), nullable=False, default=False, server_default="0")
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


class PostReport(Base, TimestampMixin, TenantModelMixin):
    """A user flagging a post for admin moderation review.

    One report per user per post (a second report from the same user is a no-op
    rather than a duplicate row), so admins see a distinct list of flagged posts.
    """

    __tablename__ = "post_reports"
    __table_args__ = (
        UniqueConstraint("post_id", "reporter_id", name="uq_post_report"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    post_id = Column(
        GUID(), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    reporter_id = Column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    reason = Column(String(300), nullable=True)
