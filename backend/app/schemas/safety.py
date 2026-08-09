"""Wire shapes for SOS.

The unusual one is `SosIncidentOut.responders`: it carries every person who was
told, with what each of them did, rather than a single "help is coming" flag.
Published response rates for volunteer first responders run 17–47%, so "told,
no answer yet" is the *normal* case and the screen has to be able to say it.
Collapsing that into a boolean is how a member ends up believing somebody is on
the way when nobody is.
"""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ── Trusted contacts ─────────────────────────────────────────────────────────

class SafetyContactIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    phone: str = Field(min_length=4, max_length=32)
    relationship_label: Optional[str] = Field(default=None, max_length=60)
    notify_sms: bool = True
    notify_push: bool = True

    @field_validator("phone")
    @classmethod
    def _tidy(cls, v: str) -> str:
        """Spaces and dashes out, everything else left alone.

        Deliberately not a strict E.164 regex. A number that fails validation
        at 2 a.m. is a contact that never gets added, and a slightly odd number
        the SMS app can still dial is worth more than a clean rejection.
        """
        cleaned = "".join(ch for ch in v if ch.isdigit() or ch == "+")
        if not cleaned:
            raise ValueError("that does not look like a phone number")
        return cleaned


class SafetyContactPatch(BaseModel):
    name: Optional[str] = Field(default=None, max_length=120)
    relationship_label: Optional[str] = Field(default=None, max_length=60)
    notify_sms: Optional[bool] = None
    notify_push: Optional[bool] = None
    position: Optional[int] = None


class SafetyContactOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    phone: str
    relationship_label: Optional[str] = None
    notify_sms: bool
    notify_push: bool
    #: Null until a test message has actually gone. The setup screen says
    #: "not tested yet" rather than showing a tick nobody earned.
    verified_at: Optional[datetime] = None
    position: int


# ── Being a responder ────────────────────────────────────────────────────────

class ResponderSettingsIn(BaseModel):
    is_available: bool
    max_distance_m: int = Field(default=2000, ge=200, le=20000)
    quiet_from_hour: Optional[int] = Field(default=None, ge=0, le=23)
    quiet_to_hour: Optional[int] = Field(default=None, ge=0, le=23)
    #: Coarsened to ~1 km before it is stored. See `sos_dispatch.coarsen`.
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class ResponderSettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    is_available: bool
    max_distance_m: int
    quiet_from_hour: Optional[int] = None
    quiet_to_hour: Optional[int] = None
    #: Whether we have any idea where this member is. Not the position itself —
    #: nothing in this API ever hands back a responder's location.
    has_position: bool = False


# ── Raising, and what comes back ─────────────────────────────────────────────

class SosRaiseIn(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy_m: Optional[float] = None
    place_name: Optional[str] = Field(default=None, max_length=300)
    kind: Optional[str] = None
    #: A panicking thumb presses twice. Same key, same incident.
    idempotency_key: Optional[str] = Field(default=None, max_length=80)


class SosLocationIn(BaseModel):
    latitude: float
    longitude: float
    accuracy_m: Optional[float] = None
    place_name: Optional[str] = Field(default=None, max_length=300)


class StandDownIn(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=500)
    #: An organiser standing down somebody else's SOS must tick this. Guessing
    #: that a member is fine is exactly the inference this whole design forbids.
    spoke_to_them: bool = False


class SosResponderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    name: str
    wave: int
    distance_m: Optional[int] = None
    notified_at: Optional[datetime] = None
    acknowledged_at: Optional[datetime] = None
    arrived_at: Optional[datetime] = None
    declined_at: Optional[datetime] = None
    #: Their number, and only once they have said they are coming. Before that
    #: it is a phone number handed out for an event they have not agreed to.
    phone: Optional[str] = None


class SosEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    author: str
    author_name: Optional[str] = None
    event_type: str
    detail: Optional[str] = None
    created_at: datetime


class SosIncidentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    kind: Optional[str] = None
    raised_by_user_id: Optional[UUID] = None
    raised_by_name: str = "A member"

    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy_m: Optional[float] = None
    located_at: Optional[datetime] = None
    place_name: Optional[str] = None

    wave: int = 0
    radius_m: Optional[int] = None
    #: How many members have been told. An observed number, not a reassurance.
    alerted_count: int = 0
    contacts_notified: int = 0
    #: How many of those said they are coming. Usually a minority, and the
    #: screen is built to say so honestly rather than hide it.
    acknowledged_count: int = 0

    is_throttled: bool = False
    is_open: bool = True
    stood_down_at: Optional[datetime] = None
    stood_down_reason: Optional[str] = None
    created_at: datetime

    responders: list[SosResponderOut] = []
    events: list[SosEventOut] = []


class SosSummaryOut(BaseModel):
    """One row in a history or an organiser's live board."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    kind: Optional[str] = None
    raised_by_user_id: Optional[UUID] = None
    raised_by_name: str = "A member"
    place_name: Optional[str] = None
    alerted_count: int = 0
    acknowledged_count: int = 0
    is_open: bool = True
    is_throttled: bool = False
    created_at: datetime
    stood_down_at: Optional[datetime] = None


class ResponderAlertOut(BaseModel):
    """What a responder is shown when they tap the push.

    Three facts and two buttons. Distance and how long ago are the two things
    that decide whether somebody goes, and neither survives being buried in a
    notification body.
    """

    incident_id: UUID
    raised_by_name: str
    distance_m: Optional[int] = None
    place_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy_m: Optional[float] = None
    raised_at: datetime
    status: str
    #: Set once this responder has answered, so reopening the push does not
    #: ask them again.
    my_acknowledged_at: Optional[datetime] = None
    my_declined_at: Optional[datetime] = None
    my_arrived_at: Optional[datetime] = None
    #: Only after they accept.
    raiser_phone: Optional[str] = None
