import uuid
from sqlalchemy import (
    Column, String, Text, Numeric, Boolean, DateTime, Integer, ForeignKey,
    Index, Enum as SAEnum,
)
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin
import enum

class IssueCategory(str, enum.Enum):
    """Allowed categories for NEW reports (enforced at the API layer). The column
    itself is a plain String, so historical rows with retired categories
    (ROAD, STREET_LIGHT, GARBAGE, SAFETY) remain readable and future category
    changes never require a DB/enum migration."""
    ROAD_TRAFFIC = "ROAD_TRAFFIC"
    POWER_CUT = "POWER_CUT"
    WATER = "WATER"
    SANITATION = "SANITATION"       # garbage, drainage, public cleanliness
    STREET_LIGHT = "STREET_LIGHT"
    PUBLIC_HEALTH = "PUBLIC_HEALTH"  # mosquitoes, stray animals, health hazards
    ENCROACHMENT = "ENCROACHMENT"    # illegal construction / obstruction
    SAFETY = "SAFETY"                # public safety, hazards, law & order
    OTHER = "OTHER"

class IssueStatus(str, enum.Enum):
    NEW = "NEW"
    ASSIGNED = "ASSIGNED"
    UNDER_REVIEW = "UNDER_REVIEW"
    ESCALATED = "ESCALATED"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"
    REJECTED = "REJECTED"

# Removed VALID_TRANSITIONS to allow flexible community updates

class PublicIssue(Base, TimestampMixin, TenantModelMixin):
    """
    Community-reported infrastructure/safety issues with a strict state machine workflow.
    """
    __tablename__ = "public_issues"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    reported_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    # Stored as a plain string (not a DB enum) so retired categories on old rows
    # stay readable and adding/renaming a category never needs an enum migration.
    # New submissions are still validated against IssueCategory at the API layer.
    category = Column(String(50), nullable=False)
    description_ta = Column(Text, nullable=False)
    description_en = Column(Text, nullable=False)
    latitude = Column(Numeric(10, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    # Human-readable address reverse-geocoded from lat/lng (added to the complaint
    # + the department email). Nullable: geocoding is best-effort.
    location_name = Column(Text, nullable=True)
    geography_id = Column(GUID(), ForeignKey("geographic_nodes.id", ondelete="SET NULL"), nullable=True)
    photo_url = Column(Text, nullable=True)
    verification_photo_url = Column(Text, nullable=True)
    is_emergency = Column(Boolean, nullable=True, default=False)
    status = Column(SAEnum(IssueStatus, name="issue_status"), default=IssueStatus.NEW, nullable=False)
    assigned_volunteer_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    # ── The club review gate ────────────────────────────────────────────────
    # Nothing reaches a government office without a member of the club reading
    # it first. These record who did, when, and what they decided — the club's
    # name goes on every letter, so the decision has an owner.
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    reviewed_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    # Shown to the person who reported it. A rejection with no reason teaches
    # them only that reporting is pointless.
    review_note = Column(Text, nullable=True)

    # ── Where this happened, as the router understood it ────────────────────
    # Stored rather than recomputed: the tree can be reclassified later, and a
    # complaint's history should say where it was actually sent, not where it
    # would be sent today. `jurisdiction_confidence` carries DECLARED /
    # INHERITED / GUESSED so a reviewer knows whether to check.
    local_body_type = Column(String(30), nullable=True)
    jurisdiction_confidence = Column(String(20), nullable=True)
    jurisdiction_reason = Column(Text, nullable=True)

    # ── Position on the ladder ──────────────────────────────────────────────
    # Which rung the complaint is on now (matches RoutingStep.position), and
    # when the club should be ASKED whether to climb. Never a trigger: no email
    # leaves this system without a person pressing send.
    current_position = Column(Integer, nullable=True)
    next_action_due_at = Column(DateTime(timezone=True), nullable=True)

    # Road class cannot be derived from a coordinate — a state highway and a
    # corporation street look identical to GPS. When a reviewer recognises the
    # road, this pins the complaint to NHAI or the Highways Department instead
    # of the local body.
    department_code_override = Column(String(40), nullable=True)

    # Which language the citizen actually wrote in. They are asked once, in
    # their own language; the other description column is filled by translation
    # or by copying, and this records which one came from a human.
    description_lang = Column(String(8), nullable=True)

    # ── Complaint Box ────────────────────────────────────────────────────────
    #: SELF or VIA_CLUB. Decides who is allowed to state what happened.
    lane = Column(String(12), nullable=True, default="SELF")
    #: ROUTINE or SERIOUS. Steers the member towards a call or a letter.
    severity = Column(String(12), nullable=True, default="ROUTINE")
    #: Whether the member kept the club's blind copy on. When true a copy of
    #: their letter reaches FYC, which is how the escalation clock starts
    #: without anyone being asked. Disclosed on the draft screen, never silent.
    bcc_club = Column(Boolean, nullable=True, default=True)
    #: Why it was closed, in the member's own words. Never a dropdown — "I
    #: sorted it another way" is a legitimate ending and should not need a
    #: category.
    closed_reason = Column(Text, nullable=True)

    reporter = relationship("User", foreign_keys=[reported_by_user_id])
    assigned_volunteer = relationship("User", foreign_keys=[assigned_volunteer_id])
    geography = relationship("GeographicNode", foreign_keys=[geography_id])

class IssueEmailLog(Base, TimestampMixin, TenantModelMixin):
    """
    Tracks emails sent to relevant authorities regarding a public issue.
    """
    __tablename__ = "issue_email_logs"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    issue_id = Column(GUID(), ForeignKey("public_issues.id", ondelete="CASCADE"), nullable=False)
    sent_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    authority_email = Column(String(255), nullable=False)
    subject = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    
    issue = relationship("PublicIssue")
    sender = relationship("User")


class ComplaintDepartment(Base, TimestampMixin, TenantModelMixin):
    """The routing directory: which department/officer a complaint category goes
    to. Seeded with the real TN public channels (CM Helpline 1100, TANGEDCO 1912,
    TWAD, Highways/Municipality, Police 100); admins fill in the actual local
    officer email so complaints are dispatched by SMTP. Where no email is set, the
    app surfaces the phone/portal so the citizen is never left with a dead end."""

    __tablename__ = "complaint_departments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    category = Column(String(50), nullable=False, index=True)
    name_en = Column(String(150), nullable=False)
    name_ta = Column(String(150), nullable=True)
    email = Column(String(255), nullable=True)        # official officer email (admin-set)
    cc_emails = Column(String(500), nullable=True)     # comma-separated extra recipients
    phone = Column(String(50), nullable=True)
    helpline = Column(String(50), nullable=True)       # e.g. 1100 / 1912
    portal_url = Column(String(300), nullable=True)    # official grievance portal
    is_active = Column(Boolean, nullable=False, default=True)


# ── Complaint Box ─────────────────────────────────────────────────────────────

class ComplaintLane(str, enum.Enum):
    """Who carries the complaint, which decides who knows anything about it.

    See docs/civic/complaint-box-architecture.md §6. In SELF the member sends
    from their own mail and is the source of truth; in VIA_CLUB the club sends
    and can be complete.
    """

    SELF = "SELF"
    VIA_CLUB = "VIA_CLUB"


class ComplaintSeverity(str, enum.Enum):
    """How bad it is, which decides what the app suggests.

    ROUTINE goes to the phone: faster, and usually enough. SERIOUS goes to
    writing, because a call leaves no evidence and a letter is dated, addressed
    and quotable. The app suggests; it never blocks.
    """

    ROUTINE = "ROUTINE"
    SERIOUS = "SERIOUS"


class ComplaintAuthor(str, enum.Enum):
    """Who says a thing happened.

    The reason this column exists: in Lane A nobody can observe whether a letter
    was sent or answered, so the app must never assert it. Every timeline row
    names its author, and the UI renders "You said you sent this" rather than a
    status badge that might be wrong.
    """

    MEMBER = "MEMBER"
    FYC = "FYC"
    #: Only for things the server genuinely observed — a BCC copy arriving, a
    #: waiting period elapsing. Never for anything inferred.
    SYSTEM = "SYSTEM"


class ComplaintEventType(str, enum.Enum):
    CAPTURED = "CAPTURED"
    CALLED = "CALLED"
    DRAFTED = "DRAFTED"
    SENT = "SENT"
    COPY_RECEIVED = "COPY_RECEIVED"
    REPLY_RECEIVED = "REPLY_RECEIVED"
    HANDED_TO_FYC = "HANDED_TO_FYC"
    FYC_FORWARDED = "FYC_FORWARDED"
    ESCALATED = "ESCALATED"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"
    REOPENED = "REOPENED"


class CallOutcome(str, enum.Enum):
    REACHED = "REACHED"
    NO_ANSWER = "NO_ANSWER"
    PROMISED = "PROMISED"


class ComplaintEvent(Base, TimestampMixin, TenantModelMixin):
    """One thing that happened to a complaint, and who says so.

    This table is why the interface can never claim something nobody stated.
    A complaint has no status column of its own that the server maintains by
    guessing; it has a list of authored statements, and the current state is
    read from them.
    """

    __tablename__ = "complaint_events"
    __table_args__ = (
        Index("ix_complaint_events_issue_created", "issue_id", "created_at"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    issue_id = Column(GUID(), ForeignKey("public_issues.id", ondelete="CASCADE"),
                      nullable=False, index=True)

    author = Column(String(10), nullable=False, default=ComplaintAuthor.MEMBER.value)
    #: The member or organiser who said it. Null for SYSTEM.
    author_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                            nullable=True)
    event_type = Column(String(20), nullable=False)

    #: Which rung this concerns, when it concerns one.
    authority_id = Column(GUID(), ForeignKey("civic_authorities.id", ondelete="SET NULL"),
                          nullable=True)
    #: Denormalised so a timeline still reads correctly after an office is
    #: renamed or a directory row is deleted. A record of what happened should
    #: not change because the directory did.
    authority_label = Column(String(220), nullable=True)

    #: REACHED / NO_ANSWER / PROMISED, for CALLED.
    call_outcome = Column(String(20), nullable=True)
    #: Free text the member added, and the reason on CLOSED.
    note = Column(Text, nullable=True)
