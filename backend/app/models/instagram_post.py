import uuid
import enum
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class InstagramPostStatus(str, enum.Enum):
    PENDING_REVIEW = "PENDING_REVIEW"
    APPROVED = "APPROVED"
    PUBLISHED = "PUBLISHED"
    REJECTED = "REJECTED"


class InstagramPost(Base, TimestampMixin, TenantModelMixin):
    """
    Represents a post submitted for publication on the organisation's
    Instagram feed.  Posts from trusted roles are published immediately;
    posts from lower-privilege users sit in PENDING_REVIEW until an admin
    approves or rejects them.
    """
    __tablename__ = "instagram_posts"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    # TenantModelMixin already provides organization_id

    created_by_user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Public CDN URL of the image to post (Cloudinary or local)
    image_url = Column(String(2048), nullable=False)

    # Instagram caption — IG limit is 2 200 characters
    caption = Column(String(2200), nullable=False, default="")

    status = Column(
        SAEnum(InstagramPostStatus, name="instagram_post_status"),
        nullable=False,
        default=InstagramPostStatus.PENDING_REVIEW,
        index=True,
    )

    # Set after a successful publish call to the Instagram Graph API
    instagram_media_id = Column(String(64), nullable=True)

    # Admin who reviewed this post
    reviewed_by_user_id = Column(
        GUID(),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    reviewed_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    creator = relationship("User", foreign_keys=[created_by_user_id])
    reviewer = relationship("User", foreign_keys=[reviewed_by_user_id])
