"""The local work index.

A carpenter in Nagercoil is invisible online — not for want of a phone, but
because there is no index he appears in, and the directory that would list him
wants about eleven thousand rupees a year. This is that index.

See docs/work/01-architecture.md. Two things shape every table here:

* **Everyone is one kind of thing.** A member who fixes motorbikes needs a
  tutor for his sister, so there are no separate "worker" and "employer"
  populations — only listings, owned by a person or a shop.
* **Trust is built from facts, not judgement.** There is no rating column and
  no approval flag, because gatekeeping costs an organiser's evening every week
  forever. What a listing shows is what is simply true about it: a verified
  number, how long they have been a member, how many jobs somebody confirmed.
"""
import enum
import uuid

from sqlalchemy import (
    Boolean, Column, DateTime, ForeignKey, Index, Integer, String, Text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.base import GUID, TenantModelMixin, TimestampMixin


class WorkCategory(str, enum.Enum):
    """Broad and flat, on purpose.

    "Software", not "React developer". A deep taxonomy is how a directory
    dies: nobody self-classifies into the right leaf, searchers pick a
    different leaf, and both sides conclude the place is empty. Anything more
    specific belongs in the free text, which is searched.
    """

    TUITION = "TUITION"
    CARPENTRY = "CARPENTRY"
    MASONRY = "MASONRY"
    PAINTING = "PAINTING"
    ELECTRICAL = "ELECTRICAL"
    PLUMBING = "PLUMBING"
    WELDING = "WELDING"
    BIKE_REPAIR = "BIKE_REPAIR"
    CAR_REPAIR = "CAR_REPAIR"
    MOBILE_REPAIR = "MOBILE_REPAIR"
    COMPUTER = "COMPUTER"
    SOFTWARE = "SOFTWARE"
    PHOTOGRAPHY = "PHOTOGRAPHY"
    VIDEOGRAPHY = "VIDEOGRAPHY"
    TAILORING = "TAILORING"
    CATERING = "CATERING"
    DRIVER = "DRIVER"
    DAILY_LABOUR = "DAILY_LABOUR"
    CLEANING = "CLEANING"
    BEAUTY = "BEAUTY"
    EVENTS = "EVENTS"
    REPAIRS_GENERAL = "REPAIRS_GENERAL"


class ListingKind(str, enum.Enum):
    """A person or a shop.

    The only real difference is that a shop has an address and opening hours,
    which is a nullable field rather than a second model.
    """

    PERSON = "PERSON"
    BUSINESS = "BUSINESS"


class Listing(Base, TimestampMixin, TenantModelMixin):
    """Somebody who does work, and can be rung about it."""

    __tablename__ = "work_listings"
    __table_args__ = (
        Index("ix_work_listings_category", "organization_id", "category",
              "is_active"),
        Index("ix_work_listings_owner", "owner_user_id"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    owner_user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                           nullable=False)

    kind = Column(String(12), nullable=False, default=ListingKind.PERSON.value)
    #: How they want to be known — a person's name or a shop's name. Not taken
    #: from the profile, because "Selvam Furniture" is not what the account is
    #: called.
    display_name = Column(String(120), nullable=False)
    category = Column(String(24), nullable=False)

    #: What they do, in their own words. This is where "I do interlock brick
    #: work" lives, and it is searched — the category is for browsing, the
    #: words are for finding.
    about = Column(Text, nullable=True)

    #: The part of town. Nagercoil is one place but "Vadasery" and "Putheri"
    #: are twenty minutes apart, and that decides whether somebody rings.
    area = Column(String(120), nullable=True)

    phone = Column(String(20), nullable=False)
    whatsapp = Column(String(20), nullable=True)

    # Shops only.
    address = Column(Text, nullable=True)
    hours = Column(String(120), nullable=True)

    is_active = Column(Boolean, nullable=False, default=True)

    #: Hidden by the report rule rather than by the owner. Kept separate from
    #: `is_active` so that somebody who was hidden and then cleared gets their
    #: listing back exactly as it was.
    is_hidden = Column(Boolean, nullable=False, default=False)

    #: How many people opened it. The only thing the app can honestly show
    #: somebody who listed once and heard nothing — and without it the supply
    #: side quietly decides it did not work.
    view_count = Column(Integer, nullable=False, default=0)

    owner = relationship("User", foreign_keys=[owner_user_id])


class WorkRecord(Base, TimestampMixin, TenantModelMixin):
    """A job that was done, confirmed by whoever received it.

    The point of the whole feature. A skill somebody claims is a claim; a job
    eleven people confirmed is a document — and a nineteen-year-old in
    Nagercoil currently has no way to obtain one.

    Unconfirmed records are never counted anywhere. A self-reported total is
    just the claim again, wearing a number.
    """

    __tablename__ = "work_records"
    __table_args__ = (
        Index("ix_work_records_listing", "listing_id", "confirmed_at"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    listing_id = Column(GUID(), ForeignKey("work_listings.id", ondelete="CASCADE"),
                        nullable=False)
    #: Who received the work. Null when they are not an app user — the job
    #: still happened, it simply cannot be confirmed, and so is not counted.
    client_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                            nullable=True)

    what = Column(Text, nullable=False)
    confirmed_at = Column(DateTime(timezone=True), nullable=True)


class ReportReason(str, enum.Enum):
    """Why somebody is reporting.

    Separate reasons because "the number does not work" and "he took money and
    did not come" need completely different responses, and a single free-text
    box makes an organiser read forty of them to find the one that matters.
    """

    WRONG_NUMBER = "WRONG_NUMBER"
    NOT_DOING_THIS_WORK = "NOT_DOING_THIS_WORK"
    TOOK_MONEY = "TOOK_MONEY"
    RUDE_OR_UNSAFE = "RUDE_OR_UNSAFE"
    NOT_A_REAL_PERSON = "NOT_A_REAL_PERSON"
    OTHER = "OTHER"


class ReportStatus(str, enum.Enum):
    OPEN = "OPEN"
    UPHELD = "UPHELD"
    DISMISSED = "DISMISSED"


class ListingReport(Base, TimestampMixin, TenantModelMixin):
    """The whole safety mechanism, so it gets more than a button.

    There is no approval queue in front of this feature — anybody may list.
    That was the club's decision and it is the right trade for an organiser's
    time, but it means reporting is the only line of defence and has to work
    without anybody being awake.
    """

    __tablename__ = "work_listing_reports"
    __table_args__ = (
        Index("ix_work_reports_status", "organization_id", "status"),
        Index("ix_work_reports_listing", "listing_id"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    listing_id = Column(GUID(), ForeignKey("work_listings.id", ondelete="CASCADE"),
                        nullable=False)
    reported_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                 nullable=True)

    reason = Column(String(24), nullable=False)
    note = Column(Text, nullable=True)

    status = Column(String(12), nullable=False, default=ReportStatus.OPEN.value)
    reviewed_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                 nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    review_note = Column(Text, nullable=True)
