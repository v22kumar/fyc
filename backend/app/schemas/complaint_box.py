"""Wire shapes for the Complaint Box.

See docs/civic/complaint-box-architecture.md. The unusual one is
`ComplaintEventOut`: it always names an author, because in Lane A nobody can
observe whether a letter was sent or answered, so the interface must render
"You said you sent this" rather than a status badge that might be wrong.
"""
from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class CallLogIn(BaseModel):
    """A call the member made. Recorded because they say so, never detected."""

    authority_id: Optional[UUID] = None
    authority_label: Optional[str] = Field(
        default=None, max_length=220,
        description="Kept verbatim so the timeline survives a directory edit.",
    )
    outcome: str = Field(description="REACHED | NO_ANSWER | PROMISED")
    note: Optional[str] = Field(default=None, max_length=2000)


class SentIn(BaseModel):
    """The member confirming they sent the letter.

    Only needed when the club's blind copy is off — with it on, the copy
    arriving is the proof and nobody has to be asked.
    """

    authority_id: Optional[UUID] = None
    authority_label: Optional[str] = Field(default=None, max_length=220)
    note: Optional[str] = Field(default=None, max_length=2000)


class ReplyIn(BaseModel):
    note: Optional[str] = Field(default=None, max_length=2000)


class CloseIn(BaseModel):
    """Ending a complaint.

    `resolved` says the problem is gone. Anything else is closed, with the
    member's own reason — "I gave up" and "I sorted it another way" are both
    legitimate endings and neither should need a category.
    """

    resolved: bool
    reason: Optional[str] = Field(default=None, max_length=2000)


class DraftIn(BaseModel):
    authority_id: Optional[UUID] = None
    #: Off means genuinely off: no copy to the club, no clock, and the app falls
    #: back to asking whether it was sent.
    bcc_club: bool = True
    use_ai: bool = True


class DraftOut(BaseModel):
    to_email: Optional[str] = None
    to_label: str
    cc: list[str] = []
    bcc: list[str] = []
    subject: str
    body: str
    #: True when the model filled the slots; false when the member's own words
    #: were used because it was unavailable. The screen says so quietly.
    ai_written: bool


class ComplaintEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    author: str
    author_name: Optional[str] = None
    event_type: str
    authority_label: Optional[str] = None
    call_outcome: Optional[str] = None
    note: Optional[str] = None
    created_at: datetime


class ComplaintStateOut(BaseModel):
    """What we are allowed to say about this complaint right now."""

    id: UUID

    #: What the complaint is about, in the member's own words and their own
    #: photograph. The screen used to open straight onto a ladder of officers
    #: with no reminder of which problem this was, which is unreadable for
    #: anybody carrying more than one complaint.
    category: str = ""
    description: str = ""
    place_name: Optional[str] = None
    photo_url: Optional[str] = None
    created_at: Optional[datetime] = None

    lane: str
    severity: str
    status: str
    #: "Waiting to hear · 12 days". Not "Unknown" — the absence of news is a
    #: real state and this is what a person would call it.
    waiting_days: Optional[int] = None
    is_closed: bool
    closed_reason: Optional[str] = None
    events: list[ComplaintEventOut] = []


class ComplaintSummaryOut(BaseModel):
    """One row in "my complaints".

    A summary rather than the full state: the list needs enough to say where
    each one stands and nothing more, and fetching every timeline to render a
    list would be a query per row for information nobody reads until they tap.
    """

    id: UUID
    category: str
    description: str
    place_name: Optional[str] = None
    photo_url: Optional[str] = None

    lane: str
    severity: str
    status: str
    is_closed: bool
    closed_reason: Optional[str] = None

    #: Days since the last thing that left — a letter, a call, a forward. Null
    #: when nothing has, which is not the same as nothing being known: a report
    #: nobody has acted on is not waiting for a reply.
    waiting_days: Optional[int] = None

    #: What the member last did, so the row can say it in their words rather
    #: than showing a status nobody asserted.
    last_event: Optional[str] = None
    last_event_at: Optional[datetime] = None

    created_at: datetime
