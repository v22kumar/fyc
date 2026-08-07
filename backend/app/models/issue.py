import uuid
from sqlalchemy import (
    Column, String, Text, Numeric, Boolean, DateTime, Integer, ForeignKey,
    Enum as SAEnum,
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
