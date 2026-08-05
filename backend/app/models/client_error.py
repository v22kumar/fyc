import uuid

from sqlalchemy import Column, String, Text, Integer, ForeignKey, Index

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class ClientError(Base, TimestampMixin, TenantModelMixin):
    """An error that happened in someone's app or browser.

    Without this the club is blind: a member's app can die silently and nobody
    ever finds out — which matters most when the people who could reproduce it
    have no device to test on. Reports go to our own backend rather than a
    third-party service, so there is no extra account, no new secret, and the
    data stays with the club.
    """

    __tablename__ = "client_errors"
    __table_args__ = (
        # The admin view is "recent errors for this org", newest first.
        Index("ix_client_errors_org_created", "organization_id", "created_at"),
        # Grouping identical failures is the first thing anyone wants.
        Index("ix_client_errors_fingerprint", "organization_id", "fingerprint"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    # Null for someone who is not signed in — an error during login is exactly
    # the kind we most want to hear about.
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                     nullable=True, index=True)

    platform = Column(String(20), nullable=False, default="unknown")  # android/ios/web
    app_version = Column(String(40), nullable=True)
    # Where in the app it happened, e.g. a route — never free-form user content.
    context = Column(String(200), nullable=True)

    message = Column(Text, nullable=False)
    stack = Column(Text, nullable=True)

    # Stable hash of (platform, message head, top stack frame) so the same crash
    # from fifty phones is one row to look at, with a count.
    # No index=True here: it would auto-generate a name that collides with the
    # composite index above, and the composite already covers the lookup.
    fingerprint = Column(String(64), nullable=False)
    occurrences = Column(Integer, nullable=False, default=1)
