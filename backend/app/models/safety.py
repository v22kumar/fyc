"""An SOS is an incident, not a notification.

The feature this replaces had no table at all. `POST /notifications/sos-alert`
pushed to every member of the organisation and returned
`{"message": "Alert sent to members"}` to somebody who was, by hypothesis, in
danger. Because nothing was stored, nobody could say *I'm coming*, nobody could
say *I'm safe*, no organiser could see a live incident, and there was no record
afterwards of an event that may end up in front of the police.

## The shape, and why

**FYC is not the ambulance. FYC is the neighbours.** 112 and Kavalan already do
emergency response; the phone in the member's hand already does Emergency SOS.
The one thing this club has that none of them has is a few hundred people who
live in this district. So the model is about *dispatching neighbours*, and
everything else is a link to somebody else's system.

The number that governs the design: published response rates for volunteer
first responders run **17–47%** (GoodSAM, PulsePoint). Most of the people you
alert will not come. That rules out alerting one person, and it rules out
alerting everyone — so the model has to carry **waves**, **per-responder
outcomes**, and an **authored timeline**, because "we told six people" and
"Suresh is 300 m away and coming" are different facts and the member needs the
second one.

`SosEvent` is deliberately the same shape as `ComplaintEvent`: every row names
its author, and the server never infers a state nobody asserted. An incident is
stood down by a person, never by a timer. A timed-out incident is one nobody
answered — a fact worth showing, not a state worth inventing.
"""
import enum
import uuid

from sqlalchemy import (
    Boolean, Column, DateTime, Float, ForeignKey, Index, Integer, String, Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.base import GUID, TenantModelMixin, TimestampMixin


class SosStatus(str, enum.Enum):
    """Where an incident stands.

    `RAISED` → `WIDENING` → `ESCALATED` are the three dispatch waves, and a
    complaint moves through them only because *nobody answered* — silence, not
    severity. `ACKNOWLEDGED` is the only good news in the list and it is set by
    a responder, not by us.
    """

    RAISED = "RAISED"
    #: Wave 1 went unanswered; a wider ring has been told.
    WIDENING = "WIDENING"
    #: Wave 2 went unanswered; organisers and the whole district roster.
    ESCALATED = "ESCALATED"
    #: At least one person said they are coming.
    ACKNOWLEDGED = "ACKNOWLEDGED"
    #: Ended by the member, or by an organiser who has spoken to them.
    STOOD_DOWN = "STOOD_DOWN"


class SosKind(str, enum.Enum):
    """What it turned out to be.

    Asked *after* the alert has gone, never before. Nobody chooses from a menu
    while they are in trouble, and a responder learns far more from "300 m away,
    Vadasery bus stand" than from a category.
    """

    MEDICAL = "MEDICAL"
    THREAT = "THREAT"
    ACCIDENT = "ACCIDENT"
    FIRE = "FIRE"
    OTHER = "OTHER"


class SosEventType(str, enum.Enum):
    RAISED = "RAISED"
    WAVE_SENT = "WAVE_SENT"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    ARRIVED = "ARRIVED"
    DECLINED = "DECLINED"
    LOCATION_UPDATED = "LOCATION_UPDATED"
    CONTACTS_NOTIFIED = "CONTACTS_NOTIFIED"
    KIND_SET = "KIND_SET"
    STOOD_DOWN = "STOOD_DOWN"
    REOPENED = "REOPENED"


class SosAuthor(str, enum.Enum):
    """Who says so. There is no `SYSTEM_INFERRED`, and there will not be."""

    MEMBER = "MEMBER"
    RESPONDER = "RESPONDER"
    FYC = "FYC"
    #: The server, and only for things it genuinely did itself — sending a
    #: wave, sending the contact messages. Never for what a person felt or
    #: whether they are safe.
    SYSTEM = "SYSTEM"


class SafetyContact(Base, TimestampMixin, TenantModelMixin):
    """The people who love you — Lane 1, kept on the server.

    These lived in `SharedPreferences` as a JSON array of bare phone strings.
    Three things followed, all bad: they vanished on reinstall, they had no
    names so the list was unreadable, and — worst — the **server could not
    reach them**. A phone that is taken, smashed or out of battery took the
    only copy with it, and the people who would actually come never heard.
    """

    __tablename__ = "safety_contacts"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)

    #: "Amma", not "+919840011111". A responder list of bare digits cannot be
    #: read under stress and cannot be safely deleted from.
    name = Column(String(120), nullable=False)
    phone = Column(String(32), nullable=False)
    #: Optional, and only so the member can confirm they picked the right
    #: person. Never shown to anybody else.
    relationship_label = Column(String(60), nullable=True)

    notify_sms = Column(Boolean, nullable=False, default=True)
    notify_push = Column(Boolean, nullable=False, default=True)

    #: When a test message was last delivered. A number nobody has ever tested
    #: is a number we should not promise anything about, and the setup screen
    #: says so rather than showing a reassuring tick.
    verified_at = Column(DateTime(timezone=True), nullable=True)

    position = Column(Integer, nullable=False, default=0)

    __table_args__ = (
        UniqueConstraint("user_id", "phone", name="uq_safety_contact_number"),
        Index("ix_safety_contacts_user_position", "user_id", "position"),
    )


class ResponderProfile(Base, TimestampMixin, TenantModelMixin):
    """A member who has agreed to be told when somebody near them needs help.

    Opt-in, never a default. Being on this list means your phone may ring at
    two in the morning because a stranger three streets away pressed a button,
    and that is a thing a person consents to explicitly or not at all.

    The coarse position is the compromise this feature turns on. Ranking by
    distance needs to know roughly where people are; storing where members are
    is the most invasive thing this app could do. So it keeps two decimal
    places — about a kilometre — refreshed opportunistically, for opted-in
    members only, and never shows it to anybody. It is precise enough to pick
    the five nearest and far too coarse to follow somebody home.
    """

    __tablename__ = "responder_profiles"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, unique=True, index=True)

    is_available = Column(Boolean, nullable=False, default=False, index=True)

    #: How far out this member is willing to be called. Their choice, not ours.
    max_distance_m = Column(Integer, nullable=False, default=2000)

    #: Local hours, 0–23. Null means any time. A member who works nights
    #: should be able to say so without leaving the roster entirely.
    quiet_from_hour = Column(Integer, nullable=True)
    quiet_to_hour = Column(Integer, nullable=True)

    #: Rounded to two decimal places on write. See the class docstring.
    coarse_lat = Column(Float, nullable=True)
    coarse_lng = Column(Float, nullable=True)
    coarse_at = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_responder_available_org", "organization_id", "is_available"),
    )


class SosIncident(Base, TimestampMixin, TenantModelMixin):
    """One SOS, from the press to the stand-down."""

    __tablename__ = "sos_incidents"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    raised_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                               nullable=True, index=True)

    status = Column(String(20), nullable=False, default=SosStatus.RAISED.value,
                    index=True)
    kind = Column(String(20), nullable=True)

    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    #: Stored because a responder must be able to tell a 12-metre fix from a
    #: two-kilometre one, and because "location: unknown" is a real answer that
    #: changes what the alert should say.
    accuracy_m = Column(Float, nullable=True)
    located_at = Column(DateTime(timezone=True), nullable=True)
    place_name = Column(Text, nullable=True)

    #: The wave this incident has reached, and the radius that wave used.
    #: Recorded rather than recomputed: the rules will change, and an incident
    #: should always be explainable as it actually happened.
    wave = Column(Integer, nullable=False, default=0)
    radius_m = Column(Integer, nullable=True)

    #: How many members have been told, across every wave.
    alerted_count = Column(Integer, nullable=False, default=0)
    #: How many trusted contacts the server managed to message.
    contacts_notified = Column(Integer, nullable=False, default=0)

    #: Set when the rate limit was hit. The incident is still raised — you never
    #: refuse somebody who might be dying — but dispatch stops at wave 1 and an
    #: organiser is asked to look.
    is_throttled = Column(Boolean, nullable=False, default=False)

    stood_down_at = Column(DateTime(timezone=True), nullable=True)
    stood_down_by_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                                   nullable=True)
    stood_down_reason = Column(Text, nullable=True)

    #: A panicking thumb presses twice. The client sends a key and the second
    #: press returns the first incident instead of raising another.
    idempotency_key = Column(String(80), nullable=True)

    responders = relationship("SosResponder", back_populates="incident",
                              cascade="all, delete-orphan")
    events = relationship("SosEvent", back_populates="incident",
                          cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_sos_open", "organization_id", "status"),
        UniqueConstraint("raised_by_user_id", "idempotency_key",
                         name="uq_sos_idempotency"),
    )

    @property
    def is_open(self) -> bool:
        return self.status != SosStatus.STOOD_DOWN.value

    @property
    def has_location(self) -> bool:
        return self.latitude is not None and self.longitude is not None


class SosResponder(Base, TimestampMixin, TenantModelMixin):
    """One person who was told, and what they did about it.

    Four separate timestamps rather than one status column, because each is
    written by the person it is about and none can be inferred from the others.
    Somebody who acknowledged and never arrived is a different, and useful,
    fact from somebody who declined.
    """

    __tablename__ = "sos_responders"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    incident_id = Column(GUID(), ForeignKey("sos_incidents.id", ondelete="CASCADE"),
                         nullable=False, index=True)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)

    #: Which dispatch round told them.
    wave = Column(Integer, nullable=False, default=1)
    #: Frozen at dispatch. Recomputing it later would quietly rewrite history
    #: every time somebody moved.
    distance_m = Column(Integer, nullable=True)

    notified_at = Column(DateTime(timezone=True), nullable=True)
    acknowledged_at = Column(DateTime(timezone=True), nullable=True)
    arrived_at = Column(DateTime(timezone=True), nullable=True)
    #: A decline is not a non-answer. It is what lets the next wave go early
    #: instead of waiting out the timer.
    declined_at = Column(DateTime(timezone=True), nullable=True)

    incident = relationship("SosIncident", back_populates="responders")

    __table_args__ = (
        UniqueConstraint("incident_id", "user_id", name="uq_sos_responder"),
    )


class SosEvent(Base, TimestampMixin, TenantModelMixin):
    """One thing that happened, and who says so.

    The same rule as `ComplaintEvent`, for the same reason and with higher
    stakes: this screen is read by somebody in trouble, and a state the app
    invented is a state that can be wrong in front of them at the moment it
    matters most.
    """

    __tablename__ = "sos_events"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    incident_id = Column(GUID(), ForeignKey("sos_incidents.id", ondelete="CASCADE"),
                         nullable=False, index=True)

    author = Column(String(20), nullable=False)
    author_user_id = Column(GUID(), ForeignKey("users.id", ondelete="SET NULL"),
                            nullable=True)
    event_type = Column(String(30), nullable=False)

    #: Free-form detail: "wave 2 · 3 km · 9 members", "on my way".
    detail = Column(Text, nullable=True)

    incident = relationship("SosIncident", back_populates="events")

    __table_args__ = (
        Index("ix_sos_events_incident_time", "incident_id", "created_at"),
    )
