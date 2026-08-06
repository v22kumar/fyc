import uuid

from sqlalchemy import Column, String, DateTime, ForeignKey, Index, UniqueConstraint

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class ProfileAttribute(Base, TimestampMixin, TenantModelMixin):
    """Something the club has learned about a member.

    This is the answer to "how does the profile stay expandable when every new
    question would otherwise be a new column". A new question is a new **row**
    here, never a migration — so asking the club something new is a catalogue
    edit and a deploy of nothing.

    It is deliberately separate from `profile_prompt_states`, which records what
    we have *asked*. The two have different lifetimes: the asking record is
    bookkeeping and could be reset without loss, while what we have learned
    should outlive any change to how or whether we ask.

    ### When a key should stop living here

    A key earns a real column on `user_profiles` when a feature needs to
    **query, filter, sort or index** by it. `blood_group` earned one — the donor
    search filters on it. Education has not: nobody searches members by degree.

    Promote by adding the column, backfilling from these rows, and pointing the
    reader at the column. Once, when a real query needs it — never "in case",
    because that is how a profile table ends up eighty mostly-empty columns wide.
    """

    __tablename__ = "profile_attributes"
    __table_args__ = (
        # One current value per key per member. An updated answer overwrites.
        UniqueConstraint("user_id", "key", name="uq_profile_attribute_user_key"),
        # "everyone who answered X" — the club's own view of its membership.
        Index("ix_profile_attribute_org_key", "organization_id", "key"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)

    # Matches a question id in the catalogue. A plain string, so the catalogue
    # can grow without touching the schema.
    key = Column(String(64), nullable=False)
    value = Column(String(200), nullable=False)

    # When the member told us. Kept per answer rather than per profile, so
    # "what did the club look like last year" stays answerable — which a single
    # JSON blob on the profile could not do.
    answered_at = Column(DateTime(timezone=True), nullable=False)
