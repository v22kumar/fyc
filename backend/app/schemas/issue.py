from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from typing import Optional
from app.models.issue import IssueCategory, IssueStatus

class IssueCreate(BaseModel):
    category: IssueCategory
    description_ta: str
    description_en: str
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    geography_id: Optional[UUID] = None
    photo_url: Optional[str] = None
    is_emergency: bool = False

class IssueStatusUpdate(BaseModel):
    status: IssueStatus
    assigned_volunteer_id: Optional[UUID] = None
    verification_photo_url: Optional[str] = None

class IssueOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    # Plain string, not the enum: historical rows may hold a retired category
    # (ROAD, STREET_LIGHT, GARBAGE, SAFETY) that is no longer an enum member, and
    # serializing those must not 500. New reports are validated via IssueCreate.
    category: str
    description_ta: str
    description_en: str
    latitude: float
    longitude: float
    geography_id: Optional[UUID]
    location_name: Optional[str] = None
    photo_url: Optional[str]
    verification_photo_url: Optional[str]
    is_emergency: Optional[bool] = False
    status: IssueStatus
    assigned_volunteer_id: Optional[UUID]
    reported_by_user_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime

class IssueStats(BaseModel):
    total: int
    resolved: int
    resolution_rate: int        # percentage 0–100
    avg_response_days: float
    active_citizens: int

class IssueEmailCreate(BaseModel):
    # Optional so "Log email sent to authorities" can be recorded with one tap;
    # the router fills sensible defaults when omitted.
    authority_email: Optional[str] = None
    subject: Optional[str] = None
    body: Optional[str] = None

class IssueEmailOut(BaseModel):
    id: UUID
    issue_id: UUID
    sent_by_user_id: Optional[UUID]
    authority_email: str
    subject: str
    body: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── Complaint departments (routing directory) ────────────────────────────────
class DepartmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    category: str
    name_en: str
    name_ta: Optional[str] = None
    email: Optional[str] = None
    cc_emails: Optional[str] = None
    phone: Optional[str] = None
    helpline: Optional[str] = None
    portal_url: Optional[str] = None
    is_active: bool = True


class DepartmentUpsert(BaseModel):
    category: str
    name_en: str
    name_ta: Optional[str] = None
    email: Optional[str] = None
    cc_emails: Optional[str] = None
    phone: Optional[str] = None
    helpline: Optional[str] = None
    portal_url: Optional[str] = None
    is_active: bool = True


class DepartmentPatch(BaseModel):
    name_en: Optional[str] = None
    name_ta: Optional[str] = None
    email: Optional[str] = None
    cc_emails: Optional[str] = None
    phone: Optional[str] = None
    helpline: Optional[str] = None
    portal_url: Optional[str] = None
    is_active: Optional[bool] = None


# ── AI complaint draft (preview before forwarding) ───────────────────────────
class ComplaintDraftIn(BaseModel):
    category: IssueCategory
    description: str
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    is_emergency: bool = False


class ComplaintDraftOut(BaseModel):
    subject: str
    body_en: str
    body_ta: Optional[str] = None
    location_name: Optional[str] = None
    department: Optional[DepartmentOut] = None
    ai_used: bool = False


class ForwardIn(BaseModel):
    # Optional overrides — when omitted, the router AI-drafts (or falls back to
    # the raw description) and routes by category.
    subject: Optional[str] = None
    body: Optional[str] = None
    use_ai: bool = True


class ForwardOut(BaseModel):
    sent: bool                      # True if actually emailed via SMTP
    recipient: Optional[str] = None
    department: Optional[DepartmentOut] = None
    needs_manual: bool = False      # True → no dept email; show phone/portal to citizen
    helpline: Optional[str] = None
    portal_url: Optional[str] = None
    subject: str
    email_log_id: Optional[UUID] = None


# ── One description, in the language the person speaks ───────────────────────

class IssueCreateV2(BaseModel):
    """What a person actually submits, after the redesign.

    The old `IssueCreate` required `description_ta` **and** `description_en`,
    both non-empty. Somebody standing in front of an overflowing drain had to
    compose the complaint in Tamil and then again in English. This asks once.

    The other column is still filled — the letter to an officer is written in
    English and the app displays Tamil — but that is the server's job.
    """

    category: str
    description: str = Field(..., min_length=3)
    #: Which language `description` is in. Recorded so it is always clear which
    #: text came from a human and which was produced for them.
    description_lang: str = Field(default="ta", max_length=8)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    geography_id: Optional[UUID] = None
    photo_url: Optional[str] = None
    is_emergency: bool = False


# ── The route a complaint will take ──────────────────────────────────────────

class RouteRungOut(BaseModel):
    position: int
    department_code: str
    department_name_en: str
    department_name_ta: Optional[str] = None
    designation_en: Optional[str] = None
    designation_ta: Optional[str] = None
    rung: int
    wait_days: int
    #: False when nobody has filled in an address for this office yet. The
    #: complaint walks past it rather than stopping.
    reachable: bool


class RouteOut(BaseModel):
    category: str
    scope: str
    local_body_type: str
    #: DECLARED / INHERITED / GUESSED — how confident the jurisdiction is.
    jurisdiction_confidence: str
    jurisdiction_reason: str
    #: True when a reviewer should confirm the area before anything is sent.
    needs_human_check: bool
    rungs: list[RouteRungOut]
    #: Where the citizen is pointed when no rung can be reached yet.
    fallback_portal: Optional[str] = None
    fallback_helpline: Optional[str] = None


class ReviewIn(BaseModel):
    """The club's decision on a report."""

    approve: bool
    #: Required when rejecting. Shown to the person who reported it.
    reason: Optional[str] = None
    #: Set when the reviewer recognises the road as a highway, so the complaint
    #: climbs the highway chain instead of the local body's.
    department_code_override: Optional[str] = None


class DispatchIn(BaseModel):
    """Send the letter. Both fields optional — the server writes a complete one."""

    subject: Optional[str] = None
    body: Optional[str] = None


class DispatchOut(BaseModel):
    sent: bool
    position: Optional[int] = None
    sent_to: Optional[str] = None
    due_at: Optional[datetime] = None
    #: What to show the citizen when nothing could be sent — never a dead end.
    fallback_portal: Optional[str] = None
    fallback_helpline: Optional[str] = None


class EscalationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    position: int
    sent_to_label: Optional[str]
    sent_to_email: Optional[str]
    dispatched_at: Optional[datetime]
    due_at: Optional[datetime]
    outcome: str
    response_note: Optional[str]


class QueueItemOut(BaseModel):
    id: UUID
    category: str
    status: str
    description: str
    created_at: datetime
    #: waiting_on_us / waiting_on_them / overdue
    bucket: str
    current_position: Optional[int] = None
    next_action_due_at: Optional[datetime] = None
    days_overdue: Optional[int] = None


class QueueOut(BaseModel):
    waiting_on_us: list[QueueItemOut]
    waiting_on_them: list[QueueItemOut]
    overdue: list[QueueItemOut]
