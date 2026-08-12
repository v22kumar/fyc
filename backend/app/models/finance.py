"""The club's money, recorded once and reusable every year.

Three tables and no changes to any existing one. That is deliberate: this
repository has no migration tool — schema changes ride a startup reconcile in
`main.py`, where `create_all` makes brand-new tables for free but an altered
column needs a hand-written ALTER line that has been forgotten before, taking
every read of `user_profiles` down with it. New tables are the safe shape.

The domain is deliberately not "anniversary payments". A campaign is the money
side of *something the club is doing* — an anniversary, a tournament, a relief
collection — and next year is another row, not another deployment.
"""
import uuid

from sqlalchemy import (Boolean, Column, Date, DateTime, ForeignKey, Index,
                        Integer, String, Text, UniqueConstraint)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.base import GUID, TenantModelMixin, TimestampMixin

# ── Vocabularies ────────────────────────────────────────────────────────────
#
# Strings, not enums, for the same reason `event_kind` is a string: a village
# club will invent a payment method nobody planned for — a demand draft, gold,
# money handed over at the temple — and with no migration tool in this repo an
# enum is a genuinely expensive mistake. These are lists the UI offers, not
# cages the database enforces.

PAYMENT_METHODS = ("UPI", "CASH", "BANK_TRANSFER", "CHEQUE", "OTHER")

# Which methods carry a reference somebody could later look up. Cash never
# does, and demanding a transaction id for a note handed across a table is the
# fastest way to make a treasurer stop using the app.
METHODS_WITH_REFERENCE = ("UPI", "BANK_TRANSFER", "CHEQUE")

CAMPAIGN_STATUSES = ("DRAFT", "ACTIVE", "CLOSED", "ARCHIVED")

# RECORDED — a treasurer says this happened.
# VERIFIED — an executive has confirmed it. This is the club's record.
# REJECTED — confirmed as not real (wrong entry, bounced, never arrived).
# CANCELLED— real once, withdrawn since. Both keep the row and a reason.
CONTRIBUTION_STATUSES = ("RECORDED", "VERIFIED", "REJECTED", "CANCELLED")

# Statuses that count toward money the club believes it has.
COUNTED_STATUSES = ("RECORDED", "VERIFIED")


class FinanceCampaign(Base, TimestampMixin, TenantModelMixin):
    """A collection: what is being raised, for what, between which dates."""

    __tablename__ = "finance_campaigns"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)

    # Nullable on purpose. The Anniversary is an Event and should reuse it; a
    # general fundraiser is not, and forcing a hollow Event to exist so money
    # has somewhere to live would be the wrong kind of reuse. A campaign can
    # also be attached to an Event later, once somebody creates one.
    event_id = Column(GUID(), ForeignKey("events.id", ondelete="SET NULL"),
                      nullable=True, index=True)

    title_en = Column(String(200), nullable=False)
    title_ta = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)

    # ANNIVERSARY | FESTIVAL | TOURNAMENT | RELIEF | CONSTRUCTION | OTHER
    purpose = Column(String(30), nullable=True, default="OTHER")

    # No target until somebody sets one, and re-settable at any time. A club
    # that has not decided yet is a normal state, not a missing value to be
    # papered over with zero — zero would make the dashboard claim 100%
    # collected on the first rupee.
    target_amount_paise = Column(Integer, nullable=True)

    # What the club planned per head. The entry screen pre-fills it; people
    # give more and less and the schema does not care. Storing it on the
    # campaign is what stops it from being a constant in the app that has to
    # be changed — and re-released — every year.
    suggested_amount_paise = Column(Integer, nullable=True)

    currency = Column(String(3), nullable=False, default="INR")

    starts_on = Column(Date, nullable=True)
    ends_on = Column(Date, nullable=True)

    status = Column(String(20), nullable=False, default="DRAFT", index=True)

    created_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                nullable=True)

    event = relationship("Event", foreign_keys=[event_id])
    creator = relationship("User", foreign_keys=[created_by_user_id])
    assignments = relationship("FinanceCampaignAssignment",
                               back_populates="campaign",
                               cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_finance_campaign_org_status", "organization_id", "status"),
    )


class FinanceCampaignAssignment(Base, TimestampMixin):
    """Who the club appointed to collect for this campaign.

    An appointment, not a role. A seventh entry in the `users.role` vocabulary
    would follow the person into every other campaign and every future year,
    and the requirement is the opposite: a treasurer for the anniversary is not
    thereby a treasurer for anything else.

    Revoked rather than deleted, because "who was allowed to take money in
    August" is a question the club may need to answer later.
    """

    __tablename__ = "finance_campaign_assignments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    campaign_id = Column(GUID(), ForeignKey("finance_campaigns.id", ondelete="CASCADE"),
                         nullable=False, index=True)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)

    # One word for the appointment, because the club uses one word for it.
    # Verification is decided by the person's *role* — executive and above —
    # not by this column, so a treasurer who is not an executive records money
    # and someone else confirms it.
    capacity = Column(String(20), nullable=False, default="TREASURER")

    assigned_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                 nullable=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)

    campaign = relationship("FinanceCampaign", back_populates="assignments")
    user = relationship("User", foreign_keys=[user_id])

    __table_args__ = (
        Index("ix_finance_assignment_lookup", "campaign_id", "user_id", "revoked_at"),
    )


class Contribution(Base, TimestampMixin):
    """One payment. The only table in this application that holds money.

    Income only — never a sign, a direction flag or a type discriminator. An
    expense is a different table under the same campaign, with its own approver
    and its own vocabulary. Letting money flow both ways through this table is
    precisely what would make the eventual expense module a rewrite instead of
    an addition.
    """

    __tablename__ = "contributions"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    campaign_id = Column(GUID(), ForeignKey("finance_campaigns.id", ondelete="CASCADE"),
                         nullable=False, index=True)

    # Denormalised from the campaign so every query in this module can gate on
    # the organisation without a join. A role check proves the caller is an
    # executive of *their* club, not that this row belongs to it.
    organization_id = Column(GUID(), nullable=False, index=True)

    # ── Who paid ───────────────────────────────────────────────────────────
    #
    # The same shape EventRegistration already proved: a nullable link to a
    # member beside a plain name and number. A fourth table of contributors
    # would need its own de-duplication, merge tooling and privacy rules to
    # answer a question this answers directly.
    contributor_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                 nullable=True, index=True)
    contributor_name = Column(String(150), nullable=False)
    contributor_phone = Column(String(20), nullable=True)

    # Derived at write time: "u:<user id>" when a member was picked, else
    # "p:<last ten digits>", else "n:<casefolded name>". This is what makes
    # "Contributors: 48" a COUNT(DISTINCT …) rather than a guess, and what
    # makes one person's history across years a single indexed lookup.
    contributor_key = Column(String(80), nullable=False, index=True)

    # ── What ───────────────────────────────────────────────────────────────
    amount_paise = Column(Integer, nullable=False)
    currency = Column(String(3), nullable=False, default="INR")
    method = Column(String(20), nullable=False)
    reference_no = Column(String(60), nullable=True)
    paid_on = Column(Date, nullable=False, index=True)

    # ── Lifecycle ──────────────────────────────────────────────────────────
    status = Column(String(20), nullable=False, default="RECORDED", index=True)
    recorded_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                 nullable=True, index=True)
    verified_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                 nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)

    # True when the person who confirmed it is the person who recorded it. A
    # club of five cannot always afford two pairs of eyes, so this is allowed —
    # but it is counted and shown, rather than quietly indistinguishable from
    # an independent check.
    self_verified = Column(Boolean, nullable=False, default=False)

    # Why it was rejected or cancelled. Required by the router for both, so a
    # withdrawn payment can never be a silent hole in the total.
    resolution_reason = Column(String(300), nullable=True)
    notes = Column(Text, nullable=True)

    # ── Integrity ──────────────────────────────────────────────────────────
    #
    # Generated on the phone before the network is involved, so a double tap, a
    # retried request and an offline entry replayed after it already landed are
    # all the same row. The uniqueness lives in the database rather than in a
    # check-then-insert, which two concurrent requests would both pass.
    client_contribution_id = Column(String(64), nullable=True)

    campaign = relationship("FinanceCampaign", foreign_keys=[campaign_id])
    contributor = relationship("User", foreign_keys=[contributor_user_id])
    recorder = relationship("User", foreign_keys=[recorded_by_user_id])
    verifier = relationship("User", foreign_keys=[verified_by_user_id])

    __table_args__ = (
        UniqueConstraint("campaign_id", "recorded_by_user_id", "client_contribution_id",
                         name="uq_contribution_client_id"),
        Index("ix_contribution_campaign_status", "campaign_id", "status"),
        Index("ix_contribution_campaign_recorder", "campaign_id", "recorded_by_user_id"),
        Index("ix_contribution_campaign_day", "campaign_id", "paid_on"),
        Index("ix_contribution_dupe_probe", "campaign_id", "contributor_key", "amount_paise"),
    )


# Executed by the startup reconcile in app/main.py. Lives here so a test can
# run the exact string production runs — a partial-index syntax error is
# swallowed by that block's try/except and logged as a warning, which is
# indistinguishable from working until two identical UTRs turn up in the ledger.
REFERENCE_UNIQUE_INDEX_DDL = (
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_contribution_reference "
    "ON contributions (campaign_id, reference_no) "
    "WHERE reference_no IS NOT NULL "
    "AND status NOT IN ('CANCELLED', 'REJECTED')"
)
