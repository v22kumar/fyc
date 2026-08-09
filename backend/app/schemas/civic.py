"""Shapes for the department directory the club maintains by hand."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DepartmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    name_en: str
    name_ta: Optional[str]
    tier: str
    portal_url: Optional[str]
    helpline: Optional[str]


class AuthorityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    department_id: UUID
    department_code: str
    department_name_en: str
    rung: int
    designation_en: str
    designation_ta: Optional[str]
    local_body_type: Optional[str]
    office_name_en: Optional[str]
    email: Optional[str]
    phone: Optional[str]
    address_en: Optional[str]
    source_url: Optional[str]
    verified_at: Optional[datetime]
    #: A letter can be delivered here today.
    is_reachable: bool
    #: Somebody checked it, against a source, on a date.
    is_verified: bool
    #: True once the check is more than a year old. Officers transfer, and a
    #: stale address is a complaint that vanishes silently.
    is_stale: bool


class AuthorityPatch(BaseModel):
    """What the club fills in.

    `source_url` is not optional in spirit even though it is in type: without
    it the entry cannot count as verified, and the endpoint says so rather than
    accepting a contact nobody can trace.
    """

    email: Optional[str] = Field(default=None, max_length=255)
    cc_emails: Optional[str] = Field(default=None, max_length=500)
    phone: Optional[str] = Field(default=None, max_length=60)
    office_name_en: Optional[str] = None
    office_name_ta: Optional[str] = None
    address_en: Optional[str] = None
    address_ta: Optional[str] = None
    source_url: Optional[str] = Field(default=None, max_length=400)
    #: Set false to retire an office without deleting its history.
    is_active: Optional[bool] = None


class LadderHealthOut(BaseModel):
    """Whether one category can actually be filed in one kind of place."""

    category: str
    local_body_type: str
    total_rungs: int
    reachable_rungs: int
    #: The office a complaint would reach right now, if any.
    first_reachable: Optional[str] = None
    #: True when nothing on this ladder can be written to yet.
    blocked: bool


class GapOut(BaseModel):
    """An office with no contact, and how much filling it in would unblock."""

    authority_id: UUID
    department_code: str
    designation_en: str
    designation_ta: Optional[str]
    rung: int
    local_body_type: Optional[str]
    #: How many (category × place) ladders this office appears on. The club's
    #: to-do list, ordered by what buys the most.
    appears_on_ladders: int
    #: How many of those ladders currently have no reachable office at all.
    would_unblock: int


class DirectoryHealthOut(BaseModel):
    offices_total: int
    offices_reachable: int
    offices_verified: int
    offices_stale: int
    ladders_total: int
    ladders_blocked: int
    #: Fill these in first.
    top_gaps: list[GapOut]
    ladders: list[LadderHealthOut]


# ── The call ladder a member sees ────────────────────────────────────────────

class LadderRungOut(BaseModel):
    """One office a member can ring, with enough context to choose."""

    position: int
    #: Which office this is, so the screen can address a letter to *this* rung.
    #: Without it the Write button on a specific officer could only produce an
    #: unaddressed draft, which is the one thing it exists not to do.
    authority_id: Optional[UUID] = None
    department_code: str
    department_name_en: str
    department_name_ta: Optional[str] = None
    designation_en: Optional[str] = None
    designation_ta: Optional[str] = None
    #: What this office covers, in words: "your ward", "the division".
    covers_en: str
    covers_ta: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    #: Reachability is two different questions, and the directory answers them
    #: separately: an office with a mobile number and no published address can
    #: be rung today but not written to. Collapsing them into one flag would
    #: grey out a phone number somebody could have dialled.
    can_call: bool
    can_write: bool
    #: Days to wait at this rung before the next one is worth trying.
    wait_days: int


class CallLadderOut(BaseModel):
    """Every office worth trying for one complaint, nearest first.

    Deliberately the whole list. Showing a single number is worse than showing
    none: the member ignored by that one number has no visible next step, and
    stops. The ladder makes the next step obvious from the first screen.
    """

    category: str
    local_body_type: Optional[str] = None
    place_name: Optional[str] = None
    rungs: list[LadderRungOut]
    #: A published helpline or portal, for when no rung can be reached at all.
    fallback_helpline: Optional[str] = None
    fallback_portal_url: Optional[str] = None
    #: False when the complaint is from somewhere this directory does not
    #: speak for. An empty ladder then means "not our district", not "we have
    #: no offices for this" — two different sentences, and only one of them is
    #: an invitation to suggest a contact.
    covered: bool = True
    #: The place we understood the complaint to be in, when we could name it.
    #: Shown back so a member whose GPS was wrong can see why they were told
    #: this is out of area.
    outside_place: Optional[str] = None
