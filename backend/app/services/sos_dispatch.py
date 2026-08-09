"""Who gets told, and when the ring widens.

The rule this replaces was `SELECT * FROM users WHERE organization_id = ?`,
behind a button labelled "Alert nearby FYC members". There was no radius
anywhere in the feature.

That is not a cosmetic fault. A club woken twice by an SOS from somebody six
hundred kilometres away mutes the channel, and then the real one arrives and
nobody sees it. Broadcast destroys the only asset this feature has.

## Where the numbers come from

* **PulsePoint** dispatches to opted-in volunteers within roughly 400 m.
* **GoodSAM** alerts the *three nearest* and moves to the next if one does not
  accept within 20 seconds.
* Published response rates for volunteer first responders run **17–47%**.

That last figure decides the shape. Most people you alert will not come, so
one is not enough; but the fifth-nearest cannot help either, so everyone is
worse than useless. Hence: a small nearest-N ring, and a wider one only after
silence — which is the one signal that genuinely means "this is not working".

Wave 3 is the only path that reaches the whole roster. It happens after
**135 seconds of total silence**, and it still never leaves the district.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.safety import (
    ResponderProfile, SosAuthor, SosEvent, SosEventType, SosIncident,
    SosResponder, SosStatus,
)
from app.models.user import User, UserProfile


@dataclass(frozen=True)
class Wave:
    """One dispatch round: how far, how many, and how long before the next."""

    number: int
    radius_m: int
    max_responders: int
    #: Seconds of silence after this wave before the next one is due. `None`
    #: on the last wave — there is nowhere further to go, and pretending
    #: otherwise would put a countdown on a screen with nothing behind it.
    quiet_seconds: Optional[int]
    status: str


WAVES: tuple[Wave, ...] = (
    Wave(1, 1_000, 5, 45, SosStatus.RAISED.value),
    Wave(2, 3_000, 10, 90, SosStatus.WIDENING.value),
    # The whole district. `radius_m` is larger than Kanniyakumari is wide, on
    # purpose: at this point the question is no longer "who is closest" but
    # "is anybody at all", and the district boundary is enforced by the roster
    # rather than by a circle.
    Wave(3, 60_000, 60, None, SosStatus.ESCALATED.value),
)

#: How many incidents one member may raise before dispatch is contained.
#: Exceeding it never refuses the SOS — you do not turn away somebody who might
#: be dying — it stops the ring from widening and asks an organiser to look.
RATE_LIMIT_PER_HOUR = 3
RATE_LIMIT_PER_DAY = 10

EARTH_RADIUS_M = 6_371_000.0


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in metres."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lng2 - lng1)
    a = (math.sin(dp / 2) ** 2
         + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2)
    return 2 * EARTH_RADIUS_M * math.asin(min(1.0, math.sqrt(a)))


def coarsen(value: Optional[float]) -> Optional[float]:
    """Two decimal places — about a kilometre.

    Everything the roster stores about where a member is goes through here.
    Precise enough to pick the five nearest; far too coarse to follow somebody
    home. Storing anything finer would make this the most invasive thing in the
    app, to buy an accuracy the ranking does not need.
    """
    return None if value is None else round(value, 2)


def _within_quiet_hours(profile: ResponderProfile, now: datetime) -> bool:
    """Is this member's phone supposed to stay silent right now?

    Hours wrap midnight — 22 to 6 is the common case and the naive comparison
    gets it exactly backwards.
    """
    start, end = profile.quiet_from_hour, profile.quiet_to_hour
    if start is None or end is None or start == end:
        return False
    hour = now.astimezone(timezone.utc).hour
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def eligible_responders(
    db: Session,
    incident: SosIncident,
    *,
    wave: Wave,
    now: Optional[datetime] = None,
) -> list[tuple[User, Optional[int]]]:
    """The members this wave should tell, nearest first.

    Excludes: the member who raised it, anyone already told in an earlier wave,
    anyone not opted in, anyone inside their own quiet hours, and anyone whose
    own `max_distance_m` is shorter than this incident is far. That last one
    matters — a member who agreed to be called for things within a kilometre
    has not agreed to wave 3.

    An incident with no location cannot be ranked. Rather than silently
    ordering by nothing, it goes straight to the widest ring: "we do not know
    where they are" is a reason to ask more people, not fewer.
    """
    now = now or datetime.now(timezone.utc)

    already = {
        r.user_id for r in db.query(SosResponder)
        .filter(SosResponder.incident_id == incident.id).all()
    }

    profiles = (
        db.query(ResponderProfile, User)
        .join(User, User.id == ResponderProfile.user_id)
        .filter(
            ResponderProfile.organization_id == incident.organization_id,
            ResponderProfile.is_available.is_(True),
            User.id != incident.raised_by_user_id,
        )
        .all()
    )

    scored: list[tuple[float, User, Optional[int]]] = []
    for profile, user in profiles:
        if user.id in already:
            continue
        if _within_quiet_hours(profile, now):
            continue

        if not incident.has_location or profile.coarse_lat is None:
            # Unrankable. Included only once the ring is wide enough that
            # distance has stopped being the question.
            if wave.number < len(WAVES):
                continue
            scored.append((float("inf"), user, None))
            continue

        metres = haversine_m(
            float(incident.latitude), float(incident.longitude),
            profile.coarse_lat, profile.coarse_lng,
        )
        if metres > wave.radius_m:
            continue
        if metres > (profile.max_distance_m or 0):
            continue
        scored.append((metres, user, int(metres)))

    scored.sort(key=lambda row: row[0])
    return [(user, distance) for _, user, distance in scored[:wave.max_responders]]


def record(
    db: Session,
    incident: SosIncident,
    *,
    author: SosAuthor,
    event_type: SosEventType,
    user_id: Optional[UUID] = None,
    detail: Optional[str] = None,
) -> SosEvent:
    """Add one authored row to the timeline. Never flushes on its own."""
    event = SosEvent(
        organization_id=incident.organization_id,
        incident_id=incident.id,
        author=author.value,
        author_user_id=user_id,
        event_type=event_type.value,
        detail=detail,
    )
    db.add(event)
    return event


def dispatch_wave(
    db: Session,
    incident: SosIncident,
    *,
    wave_number: int,
    now: Optional[datetime] = None,
) -> list[SosResponder]:
    """Tell this wave's members, and record that we did.

    Returns the rows created. Sending the actual pushes is the caller's job —
    this function owns *who*, and the router owns *how*, so a failed FCM call
    can never lose the record of who was supposed to have been told.
    """
    now = now or datetime.now(timezone.utc)
    wave = WAVES[wave_number - 1]

    chosen = eligible_responders(db, incident, wave=wave, now=now)

    rows: list[SosResponder] = []
    for user, distance in chosen:
        row = SosResponder(
            organization_id=incident.organization_id,
            incident_id=incident.id,
            user_id=user.id,
            wave=wave_number,
            distance_m=distance,
            notified_at=now,
        )
        db.add(row)
        rows.append(row)

    incident.wave = wave_number
    incident.radius_m = wave.radius_m
    incident.alerted_count = (incident.alerted_count or 0) + len(rows)
    # Only advance the status while nobody has answered. A wave that goes out
    # after somebody already said they are coming must not overwrite the one
    # piece of good news on the member's screen.
    if incident.status != SosStatus.ACKNOWLEDGED.value:
        incident.status = wave.status

    record(
        db, incident,
        author=SosAuthor.SYSTEM,
        event_type=SosEventType.WAVE_SENT,
        detail=f"wave {wave_number} · {wave.radius_m} m · {len(rows)} members",
    )
    return rows


def next_wave_due_at(incident: SosIncident) -> Optional[datetime]:
    """When silence should widen the ring, or None if it should not.

    None when somebody has acknowledged, when the incident is over, when there
    are no further waves — and, importantly, when the incident was throttled.
    A member who has raised four SOSes in an hour still gets wave 1; they do
    not get to escalate to the whole district on a timer.
    """
    if incident.status in (SosStatus.ACKNOWLEDGED.value, SosStatus.STOOD_DOWN.value):
        return None
    if incident.is_throttled:
        return None
    if not incident.wave or incident.wave >= len(WAVES):
        return None

    quiet = WAVES[incident.wave - 1].quiet_seconds
    if quiet is None:
        return None

    last = (
        db_last_wave_at(incident)
        or incident.created_at
    )
    if last is None:
        return None
    if last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)
    return last + timedelta(seconds=quiet)


def db_last_wave_at(incident: SosIncident) -> Optional[datetime]:
    """When the most recent wave went out, read off the timeline."""
    sent = [e for e in (incident.events or [])
            if e.event_type == SosEventType.WAVE_SENT.value]
    if not sent:
        return None
    return max(e.created_at for e in sent if e.created_at is not None)


def over_rate_limit(db: Session, user_id: UUID, now: Optional[datetime] = None) -> bool:
    """Has this member raised too many, too fast?

    Answering yes never blocks the SOS. It contains it: wave 1 only, no
    escalation, and a flag an organiser can see. The cost of being wrong in one
    direction is a spam cannon; in the other it is a person who needed help and
    was told no.
    """
    now = now or datetime.now(timezone.utc)
    hour_ago = now - timedelta(hours=1)
    day_ago = now - timedelta(days=1)

    recent = (
        db.query(SosIncident)
        .filter(SosIncident.raised_by_user_id == user_id,
                SosIncident.created_at >= day_ago)
        .all()
    )
    in_day = len(recent)
    in_hour = sum(
        1 for i in recent
        if i.created_at and (
            i.created_at if i.created_at.tzinfo else i.created_at.replace(tzinfo=timezone.utc)
        ) >= hour_ago
    )
    return in_hour >= RATE_LIMIT_PER_HOUR or in_day >= RATE_LIMIT_PER_DAY


def display_name(db: Session, user_id: Optional[UUID]) -> str:
    """A member's name for an alert, falling back to something usable.

    "A member needs help" is worse than a name but far better than a UUID or a
    blank, and this runs on the path where nothing may raise.
    """
    if user_id is None:
        return "A member"
    profile = (db.query(UserProfile)
                 .filter(UserProfile.user_id == user_id).first())
    if profile:
        return profile.full_name_en or profile.full_name_ta or "A member"
    return "A member"
