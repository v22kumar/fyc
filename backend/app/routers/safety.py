"""SOS: raise it, answer it, stand it down.

Replaces `POST /notifications/sos-alert`, which pushed to every member of the
organisation, stored nothing, and told the member "Alert sent to members" after
merely *queueing* a background task.

Two rules run through everything here.

**Never refuse.** No endpoint on the raising path returns an error a frightened
person has to read and act on. Rate limiting contains the blast radius rather
than blocking; a missing location degrades the alert rather than rejecting it;
a push that fails still leaves the row that says who should have been told.

**Never assert what nobody said.** The server writes timeline rows for things
it did itself — a wave went out, contact messages were sent. Whether help is
coming, and whether somebody is safe, are written only by the people those
facts belong to.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker, get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.safety import (
    ResponderProfile, SafetyContact, SosAuthor, SosEvent, SosEventType,
    SosIncident, SosKind, SosResponder, SosStatus,
)
from app.models.user import User, UserProfile
from app.schemas.safety import (
    ResponderAlertOut, ResponderSettingsIn, ResponderSettingsOut,
    SafetyContactIn, SafetyContactOut, SafetyContactPatch, SosEventOut,
    SosIncidentOut, SosKindIn, SosLocationIn, SosRaiseIn, SosResponderOut,
    SosSummaryOut, StandDownIn,
)
from app.services.sos_dispatch import (
    WAVES, coarsen, dispatch_wave, display_name, over_rate_limit, record,
)

router = APIRouter(prefix="/safety", tags=["Safety"])

require_organiser = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ── Reading an incident back ─────────────────────────────────────────────────

def _names(db: Session, user_ids: set[UUID]) -> dict[UUID, str]:
    if not user_ids:
        return {}
    rows = (db.query(UserProfile.user_id, UserProfile.full_name_en,
                     UserProfile.full_name_ta)
              .filter(UserProfile.user_id.in_(user_ids)).all())
    return {uid: (en or ta or "A member") for uid, en, ta in rows}


def _phones(db: Session, user_ids: set[UUID]) -> dict[UUID, Optional[str]]:
    if not user_ids:
        return {}
    return {
        uid: phone for uid, phone in
        db.query(User.id, User.phone_number).filter(User.id.in_(user_ids)).all()
    }


def _out(db: Session, incident: SosIncident) -> SosIncidentOut:
    responders = sorted(
        incident.responders or [],
        # Coming first, then told-and-silent, then declined. Inside each group
        # your own people lead — they were told because they are yours, and
        # seeing your wife's name above a stranger two kilometres away is what
        # the list is for — then nearest.
        key=lambda r: (
            0 if r.acknowledged_at else (2 if r.declined_at else 1),
            0 if (r.wave or 1) == 0 else 1,
            r.distance_m if r.distance_m is not None else 10 ** 9,
        ),
    )
    events = sorted(incident.events or [],
                    key=lambda e: e.created_at or datetime.min.replace(tzinfo=timezone.utc))

    ids = {r.user_id for r in responders}
    ids |= {e.author_user_id for e in events if e.author_user_id}
    if incident.raised_by_user_id:
        ids.add(incident.raised_by_user_id)
    names = _names(db, ids)

    # A responder's number is handed out only once they have said they are
    # coming. Before that it is a phone number given away for an event they
    # have not agreed to take part in.
    coming = {r.user_id for r in responders if r.acknowledged_at}
    phones = _phones(db, coming)

    return SosIncidentOut(
        id=incident.id,
        status=incident.status,
        kind=incident.kind,
        raised_by_user_id=incident.raised_by_user_id,
        raised_by_name=names.get(incident.raised_by_user_id, "A member"),
        latitude=incident.latitude,
        longitude=incident.longitude,
        accuracy_m=incident.accuracy_m,
        located_at=incident.located_at,
        place_name=incident.place_name,
        wave=incident.wave or 0,
        radius_m=incident.radius_m,
        alerted_count=incident.alerted_count or 0,
        contacts_notified=incident.contacts_notified or 0,
        acknowledged_count=len(coming),
        is_throttled=bool(incident.is_throttled),
        is_open=incident.is_open,
        stood_down_at=incident.stood_down_at,
        stood_down_reason=incident.stood_down_reason,
        created_at=incident.created_at,
        responders=[
            SosResponderOut(
                user_id=r.user_id,
                name=names.get(r.user_id, "A member"),
                wave=r.wave,
                distance_m=r.distance_m,
                notified_at=r.notified_at,
                acknowledged_at=r.acknowledged_at,
                arrived_at=r.arrived_at,
                declined_at=r.declined_at,
                phone=phones.get(r.user_id) if r.acknowledged_at else None,
            )
            for r in responders
        ],
        events=[
            SosEventOut(
                id=e.id, author=e.author,
                author_name=names.get(e.author_user_id),
                event_type=e.event_type, detail=e.detail,
                created_at=e.created_at,
            )
            for e in events
        ],
    )


def _summary(incident: SosIncident, name: str) -> SosSummaryOut:
    return SosSummaryOut(
        id=incident.id,
        status=incident.status,
        kind=incident.kind,
        raised_by_user_id=incident.raised_by_user_id,
        raised_by_name=name,
        place_name=incident.place_name,
        alerted_count=incident.alerted_count or 0,
        acknowledged_count=sum(
            1 for r in (incident.responders or []) if r.acknowledged_at),
        is_open=incident.is_open,
        is_throttled=bool(incident.is_throttled),
        created_at=incident.created_at,
        stood_down_at=incident.stood_down_at,
    )


def _get(db: Session, incident_id: UUID, user: User, tenant_id: UUID) -> SosIncident:
    incident = db.get(SosIncident, incident_id)
    if incident is None or incident.organization_id != tenant_id:
        raise HTTPException(status_code=404, detail="No such SOS")
    return incident


def _may_see(db: Session, incident: SosIncident, user: User) -> bool:
    """The member who raised it, anybody who was told, and organisers.

    Nobody else. An SOS is not club news.
    """
    if incident.raised_by_user_id == user.id:
        return True
    if getattr(user, "role", "") in ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"):
        return True
    return any(r.user_id == user.id for r in (incident.responders or []))


# ── Push ─────────────────────────────────────────────────────────────────────

def _contact_members(db: Session, incident: SosIncident) -> list[SosResponder]:
    """Your people, told because they are yours — not because they are near.

    A trusted contact who also uses the app should not be reduced to an SMS.
    If your wife is a member, her phone should ring like an alarm, and if she
    happens to be close she should be able to say she is coming like anybody
    else. So she becomes a responder at **wave 0**: told first, ranked by
    nothing, and never subject to the radius that governs the waves.

    Matching is on the phone number the contact was saved with. Nothing is
    guessed: no match, no push, and the SMS still goes.
    """
    contacts = (db.query(SafetyContact)
                  .filter(SafetyContact.user_id == incident.raised_by_user_id,
                          SafetyContact.notify_push.is_(True))
                  .all())
    numbers = {c.phone for c in contacts if c.phone}
    if not numbers:
        return []

    members = (db.query(User)
                 .filter(User.organization_id == incident.organization_id,
                         User.phone_number.in_(numbers),
                         User.id != incident.raised_by_user_id)
                 .all())

    # Queried rather than read off `incident.responders`: wave 1's rows were
    # added to this session moments ago and the relationship does not see them
    # until a flush. Reading it here handed a duplicate row to anybody who was
    # both your emergency contact and your nearest neighbour, and the unique
    # constraint caught it — which is what the constraint is for.
    db.flush()
    already = {
        r.user_id for r in db.query(SosResponder)
        .filter(SosResponder.incident_id == incident.id).all()
    }
    now = _now()
    rows: list[SosResponder] = []
    for member in members:
        if member.id in already:
            continue
        row = SosResponder(
            organization_id=incident.organization_id,
            incident_id=incident.id,
            user_id=member.id,
            wave=0,
            # Deliberately null. They were not chosen for being close, and a
            # distance here would imply they were.
            distance_m=None,
            notified_at=now,
        )
        db.add(row)
        rows.append(row)

    if rows:
        incident.alerted_count = (incident.alerted_count or 0) + len(rows)
    return rows


def _notify_contacts(db: Session, incident: SosIncident) -> int:
    """Message the member's trusted contacts from the server.

    This is the rung of the degradation ladder that matters most: the phone may
    already be gone. The contacts used to live only in `SharedPreferences`, so
    a taken or smashed handset took the only copy of them with it and the
    people who would actually come never heard anything.
    """
    contacts = (db.query(SafetyContact)
                  .filter(SafetyContact.user_id == incident.raised_by_user_id,
                          SafetyContact.notify_sms.is_(True))
                  .order_by(SafetyContact.position.asc()).all())
    if not contacts:
        return 0

    name = display_name(db, incident.raised_by_user_id)
    maps = (f"https://maps.google.com/?q={incident.latitude},{incident.longitude}"
            if incident.has_location else None)

    sent = 0
    try:
        from app.services.sms_service import send_sms, sos_text

        text = sos_text(name, maps, incident.place_name)
        for c in contacts:
            try:
                if send_sms(c.phone, text):
                    sent += 1
            except Exception:
                continue
    except Exception:
        # No SMS provider wired up in this deployment. The device-side SMS
        # path still runs; this is the belt, not the braces.
        return 0
    return sent


# ── Raising ──────────────────────────────────────────────────────────────────

@router.post("/sos", response_model=SosIncidentOut,
             status_code=status.HTTP_201_CREATED)
def raise_sos(
    payload: SosRaiseIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Press the button.

    Wave 1 is dispatched inside the request, not in the background, so the
    incident that comes back already names the people who were told. The member
    is looking at that screen right now and "we will get around to it" is not
    an answer.
    """
    if payload.idempotency_key:
        existing = (db.query(SosIncident)
                      .filter(SosIncident.raised_by_user_id == current_user.id,
                              SosIncident.idempotency_key == payload.idempotency_key)
                      .first())
        if existing is not None:
            return _out(db, existing)

    now = _now()
    throttled = over_rate_limit(db, current_user.id, now)

    kind = payload.kind if payload.kind in {k.value for k in SosKind} else None
    incident = SosIncident(
        organization_id=tenant_id,
        raised_by_user_id=current_user.id,
        status=SosStatus.RAISED.value,
        kind=kind,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy_m=payload.accuracy_m,
        located_at=now if payload.latitude is not None else None,
        place_name=payload.place_name,
        is_throttled=throttled,
        idempotency_key=payload.idempotency_key,
    )
    db.add(incident)
    db.flush()

    record(db, incident, author=SosAuthor.MEMBER, user_id=current_user.id,
           event_type=SosEventType.RAISED,
           detail=None if incident.has_location else "location unknown")

    rows = dispatch_wave(db, incident, wave_number=1, now=now)
    # Your people first in the list, because they were told first and for a
    # different reason.
    rows = _contact_members(db, incident) + rows
    dispatched = [(r.user_id, r.distance_m) for r in rows]

    sent = _notify_contacts(db, incident)
    if sent:
        incident.contacts_notified = sent
        record(db, incident, author=SosAuthor.SYSTEM,
               event_type=SosEventType.CONTACTS_NOTIFIED,
               detail=f"{sent} trusted contacts messaged")

    db.commit()
    db.refresh(incident)

    name = display_name(db, current_user.id)
    background_tasks.add_task(
        _push_incident_wave, tenant_id, incident.id, dispatched, name,
        incident.place_name)
    return _out(db, incident)


def _push_incident_wave(org_id: UUID, incident_id: UUID,
                        rows: list[tuple[UUID, Optional[int]]],
                        name: str, place: Optional[str]) -> None:
    """Background push with its own session.

    A background task must not use the request's session — it is closed by the
    time this runs.
    """
    from app.core.database import SessionLocal
    from app.services.notification_service import NotificationService

    db = SessionLocal()
    try:
        svc = NotificationService(db)
        where = f" · {place}" if place else ""
        for user_id, distance in rows:
            near = f"{distance} m away" if distance is not None else "nearby"
            near_ta = f"{distance} மீ தொலைவில்" if distance is not None else "அருகில்"
            try:
                svc.send_push_only(
                    user_id=user_id,
                    organization_id=org_id,
                    title_en=f"🆘 {name} needs help",
                    title_ta=f"🆘 {name} உதவி கேட்கிறார்",
                    body_en=f"{near}{where}. Can you go?",
                    body_ta=f"{near_ta}{where}. போக முடியுமா?",
                    notification_type="SOS",
                    data={"type": "SOS", "incident_id": str(incident_id),
                          "route": f"/safety/respond/{incident_id}"},
                    # The siren lives here now, not on the phone of the person
                    # in trouble. `fyc_sos` plays it at alarm volume, which is
                    # what gets through a silenced ringer at 2 a.m.
                    channel_id="fyc_sos",
                )
            except Exception:
                continue
    except Exception:
        pass
    finally:
        db.close()


@router.post("/sos/{incident_id}/location", response_model=SosIncidentOut)
def update_location(
    incident_id: UUID,
    payload: SosLocationIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """A fresher fix while it is still live.

    Only the member who raised it. A responder reporting where they think
    somebody is would be exactly the kind of inference this design refuses.
    """
    incident = _get(db, incident_id, current_user, tenant_id)
    if incident.raised_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="This is not your SOS")

    incident.latitude = payload.latitude
    incident.longitude = payload.longitude
    incident.accuracy_m = payload.accuracy_m
    incident.located_at = _now()
    if payload.place_name:
        incident.place_name = payload.place_name
    record(db, incident, author=SosAuthor.MEMBER, user_id=current_user.id,
           event_type=SosEventType.LOCATION_UPDATED, detail=payload.place_name)
    db.commit()
    db.refresh(incident)
    return _out(db, incident)


@router.post("/sos/{incident_id}/kind", response_model=SosIncidentOut)
def set_kind(
    incident_id: UUID,
    payload: SosKindIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Say what it is, after the alert has already gone.

    Never before. Nobody picks from a menu while they are in trouble, and a
    responder learns far more from "300 m away, Vadasery bus stand" than from
    a category.
    """
    incident = _get(db, incident_id, current_user, tenant_id)
    if incident.raised_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="This is not your SOS")
    if payload.kind not in {k.value for k in SosKind}:
        raise HTTPException(status_code=422, detail="Unknown kind")

    incident.kind = payload.kind
    record(db, incident, author=SosAuthor.MEMBER, user_id=current_user.id,
           event_type=SosEventType.KIND_SET, detail=payload.kind)
    db.commit()
    db.refresh(incident)
    return _out(db, incident)


@router.post("/sos/{incident_id}/stand-down", response_model=SosIncidentOut)
def stand_down(
    incident_id: UUID,
    payload: StandDownIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """"I'm safe."

    Only the member, or an organiser who confirms they have spoken to them. No
    timer ever ends an incident: one that runs out is one nobody answered,
    which is a fact worth showing, not a state worth inventing.
    """
    incident = _get(db, incident_id, current_user, tenant_id)
    is_mine = incident.raised_by_user_id == current_user.id
    is_organiser = getattr(current_user, "role", "") in (
        "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")

    if not is_mine and not is_organiser:
        raise HTTPException(status_code=403, detail="This is not your SOS")
    if not is_mine and not payload.spoke_to_them:
        raise HTTPException(
            status_code=422,
            detail="Confirm you have spoken to them before standing this down.",
        )

    incident.status = SosStatus.STOOD_DOWN.value
    incident.stood_down_at = _now()
    incident.stood_down_by_user_id = current_user.id
    incident.stood_down_reason = payload.reason
    record(db, incident,
           author=SosAuthor.MEMBER if is_mine else SosAuthor.FYC,
           user_id=current_user.id,
           event_type=SosEventType.STOOD_DOWN, detail=payload.reason)
    db.commit()
    db.refresh(incident)
    return _out(db, incident)


@router.post("/sos/{incident_id}/reopen", response_model=SosIncidentOut)
def reopen(
    incident_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Pressed "I'm safe" too early, or it got worse again."""
    incident = _get(db, incident_id, current_user, tenant_id)
    if incident.raised_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="This is not your SOS")

    coming = any(r.acknowledged_at for r in (incident.responders or []))
    incident.status = (SosStatus.ACKNOWLEDGED.value if coming
                       else WAVES[max(0, (incident.wave or 1) - 1)].status)
    incident.stood_down_at = None
    incident.stood_down_by_user_id = None
    incident.stood_down_reason = None
    record(db, incident, author=SosAuthor.MEMBER, user_id=current_user.id,
           event_type=SosEventType.REOPENED)
    db.commit()
    db.refresh(incident)
    return _out(db, incident)


# ── Answering ────────────────────────────────────────────────────────────────

def _my_row(db: Session, incident: SosIncident, user: User) -> SosResponder:
    row = next((r for r in (incident.responders or []) if r.user_id == user.id), None)
    if row is None:
        raise HTTPException(status_code=403, detail="You were not called to this")
    return row


@router.get("/sos/{incident_id}/alert", response_model=ResponderAlertOut)
def responder_view(
    incident_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """What a responder sees when they tap the push."""
    incident = _get(db, incident_id, current_user, tenant_id)
    row = _my_row(db, incident, current_user)

    phone = None
    if row.acknowledged_at and incident.raised_by_user_id:
        phone = (db.query(User.phone_number)
                   .filter(User.id == incident.raised_by_user_id).scalar())

    return ResponderAlertOut(
        incident_id=incident.id,
        raised_by_name=display_name(db, incident.raised_by_user_id),
        distance_m=row.distance_m,
        place_name=incident.place_name,
        latitude=incident.latitude,
        longitude=incident.longitude,
        accuracy_m=incident.accuracy_m,
        raised_at=incident.created_at,
        status=incident.status,
        my_acknowledged_at=row.acknowledged_at,
        my_declined_at=row.declined_at,
        my_arrived_at=row.arrived_at,
        raiser_phone=phone,
    )


@router.post("/sos/{incident_id}/ack", response_model=SosIncidentOut)
def acknowledge(
    incident_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """"I'm coming." The only good news this system can carry."""
    incident = _get(db, incident_id, current_user, tenant_id)
    row = _my_row(db, incident, current_user)
    if not incident.is_open:
        raise HTTPException(status_code=409, detail="This SOS has been stood down")

    row.acknowledged_at = _now()
    row.declined_at = None
    incident.status = SosStatus.ACKNOWLEDGED.value
    record(db, incident, author=SosAuthor.RESPONDER, user_id=current_user.id,
           event_type=SosEventType.ACKNOWLEDGED)
    db.commit()
    db.refresh(incident)
    return _out(db, incident)


@router.post("/sos/{incident_id}/arrived", response_model=SosIncidentOut)
def arrived(
    incident_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    incident = _get(db, incident_id, current_user, tenant_id)
    row = _my_row(db, incident, current_user)
    row.arrived_at = _now()
    if row.acknowledged_at is None:
        row.acknowledged_at = row.arrived_at
    record(db, incident, author=SosAuthor.RESPONDER, user_id=current_user.id,
           event_type=SosEventType.ARRIVED)
    db.commit()
    db.refresh(incident)
    return _out(db, incident)


@router.post("/sos/{incident_id}/decline", response_model=SosIncidentOut)
def decline(
    incident_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """"Can't."

    Worth as much as "I'm coming" and much easier to get. Once everybody in a
    wave has declined there is nothing left to wait for, so the next wave goes
    immediately instead of sitting out the timer — which is the whole reason
    this endpoint exists rather than letting people ignore the push.
    """
    incident = _get(db, incident_id, current_user, tenant_id)
    row = _my_row(db, incident, current_user)
    row.declined_at = _now()
    row.acknowledged_at = None
    record(db, incident, author=SosAuthor.RESPONDER, user_id=current_user.id,
           event_type=SosEventType.DECLINED)

    dispatched: list[tuple[UUID, Optional[int]]] = []
    everyone_declined = all(
        r.declined_at is not None for r in (incident.responders or []))
    nobody_coming = not any(r.acknowledged_at for r in (incident.responders or []))
    if (incident.is_open and everyone_declined and nobody_coming
            and not incident.is_throttled and (incident.wave or 1) < len(WAVES)):
        rows = dispatch_wave(db, incident, wave_number=(incident.wave or 1) + 1)
        dispatched = [(r.user_id, r.distance_m) for r in rows]

    db.commit()
    db.refresh(incident)

    if dispatched:
        background_tasks.add_task(
            _push_incident_wave, tenant_id, incident.id, dispatched,
            display_name(db, incident.raised_by_user_id), incident.place_name)
    return _out(db, incident)


# ── Reading ──────────────────────────────────────────────────────────────────

@router.get("/sos/mine", response_model=list[SosSummaryOut])
def my_incidents(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Every SOS this member has raised — open first, newest first.

    Theirs forever, including who was told and who came. It is their event.
    """
    incidents = (db.query(SosIncident)
                   .filter(SosIncident.organization_id == tenant_id,
                           SosIncident.raised_by_user_id == current_user.id)
                   .order_by(SosIncident.created_at.desc()).all())
    name = display_name(db, current_user.id)
    out = [_summary(i, name) for i in incidents]
    out.sort(key=lambda s: (not s.is_open, -s.created_at.timestamp()))
    return out


@router.get("/sos/live", response_model=list[SosSummaryOut],
            dependencies=[Depends(require_organiser)])
def live_incidents(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """What is happening right now. Organisers only."""
    incidents = (db.query(SosIncident)
                   .filter(SosIncident.organization_id == tenant_id,
                           SosIncident.status != SosStatus.STOOD_DOWN.value)
                   .order_by(SosIncident.created_at.desc()).all())
    names = _names(db, {i.raised_by_user_id for i in incidents if i.raised_by_user_id})
    return [_summary(i, names.get(i.raised_by_user_id, "A member")) for i in incidents]


@router.get("/sos/{incident_id}", response_model=SosIncidentOut)
def read_incident(
    incident_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    incident = _get(db, incident_id, current_user, tenant_id)
    if not _may_see(db, incident, current_user):
        raise HTTPException(status_code=403, detail="Not yours to see")
    return _out(db, incident)


# ── Trusted contacts ─────────────────────────────────────────────────────────

def _with_membership(db: Session, tenant_id: UUID,
                     contacts: list[SafetyContact]) -> list[SafetyContactOut]:
    """Mark the contacts whose phones will actually ring.

    One query for the lot rather than one per contact — this list is read
    every time the setup screen opens.
    """
    numbers = {c.phone for c in contacts if c.phone}
    members: set[str] = set()
    if numbers:
        members = {
            phone for (phone,) in
            db.query(User.phone_number)
            .filter(User.organization_id == tenant_id,
                    User.phone_number.in_(numbers)).all()
            if phone
        }
    out = []
    for c in contacts:
        row = SafetyContactOut.model_validate(c)
        row.is_member = c.phone in members
        out.append(row)
    return out


@router.get("/contacts", response_model=list[SafetyContactOut])
def list_contacts(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    contacts = (db.query(SafetyContact)
                  .filter(SafetyContact.user_id == current_user.id)
                  .order_by(SafetyContact.position.asc()).all())
    return _with_membership(db, tenant_id, contacts)


@router.post("/contacts", response_model=SafetyContactOut,
             status_code=status.HTTP_201_CREATED)
def add_contact(
    payload: SafetyContactIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    existing = (db.query(SafetyContact)
                  .filter(SafetyContact.user_id == current_user.id).all())
    if any(c.phone == payload.phone for c in existing):
        raise HTTPException(status_code=409, detail="That number is already there")

    contact = SafetyContact(
        organization_id=tenant_id,
        user_id=current_user.id,
        name=payload.name.strip(),
        phone=payload.phone,
        relationship_label=payload.relationship_label,
        notify_sms=payload.notify_sms,
        notify_push=payload.notify_push,
        position=len(existing),
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return contact


@router.patch("/contacts/{contact_id}", response_model=SafetyContactOut)
def edit_contact(
    contact_id: UUID,
    payload: SafetyContactPatch,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    contact = db.get(SafetyContact, contact_id)
    if contact is None or contact.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="No such contact")
    for field in ("name", "relationship_label", "notify_sms", "notify_push",
                  "position"):
        value = getattr(payload, field)
        if value is not None:
            setattr(contact, field, value)
    db.commit()
    db.refresh(contact)
    return contact


@router.delete("/contacts/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_contact(
    contact_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    contact = db.get(SafetyContact, contact_id)
    if contact is None or contact.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="No such contact")
    db.delete(contact)
    db.commit()


@router.post("/contacts/{contact_id}/test", response_model=SafetyContactOut)
def test_contact(
    contact_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Send a test message and record that it went.

    Nobody should discover that a number was wrong during the emergency. Until
    this succeeds the setup screen says "not tested yet" rather than showing a
    tick nobody earned.
    """
    contact = db.get(SafetyContact, contact_id)
    if contact is None or contact.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="No such contact")

    name = display_name(db, current_user.id)
    text = (f"{name} has added you as an emergency contact on FYC Connect. "
            f"If they ever press SOS you will get a message like this one "
            f"with their location. This is only a test.")
    try:
        from app.services.sms_service import send_sms

        if send_sms(contact.phone, text):
            contact.verified_at = _now()
            db.commit()
            db.refresh(contact)
    except Exception:
        # No provider configured. Leave `verified_at` null — an untested number
        # must not start looking tested because the attempt failed quietly.
        pass
    return contact


# ── Being a responder ────────────────────────────────────────────────────────

@router.get("/availability", response_model=ResponderSettingsOut)
def read_availability(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    profile = (db.query(ResponderProfile)
                 .filter(ResponderProfile.user_id == current_user.id).first())
    if profile is None:
        # Off by default, and this is where that default lives. Being on the
        # roster means a stranger's emergency can wake you at two in the
        # morning, which is a thing a person opts into or not at all.
        return ResponderSettingsOut(is_available=False, max_distance_m=2000)
    return ResponderSettingsOut(
        is_available=profile.is_available,
        max_distance_m=profile.max_distance_m,
        quiet_from_hour=profile.quiet_from_hour,
        quiet_to_hour=profile.quiet_to_hour,
        has_position=profile.coarse_lat is not None,
    )


@router.put("/availability", response_model=ResponderSettingsOut)
def set_availability(
    payload: ResponderSettingsIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    profile = (db.query(ResponderProfile)
                 .filter(ResponderProfile.user_id == current_user.id).first())
    if profile is None:
        profile = ResponderProfile(
            organization_id=tenant_id, user_id=current_user.id)
        db.add(profile)

    profile.is_available = payload.is_available
    profile.max_distance_m = payload.max_distance_m
    profile.quiet_from_hour = payload.quiet_from_hour
    profile.quiet_to_hour = payload.quiet_to_hour

    if payload.latitude is not None and payload.longitude is not None:
        # Coarsened on the way in, so nothing finer than ~1 km is ever written.
        profile.coarse_lat = coarsen(payload.latitude)
        profile.coarse_lng = coarsen(payload.longitude)
        profile.coarse_at = _now()
    if not payload.is_available:
        # Leaving the roster takes your position with you.
        profile.coarse_lat = None
        profile.coarse_lng = None
        profile.coarse_at = None

    db.commit()
    db.refresh(profile)
    return ResponderSettingsOut(
        is_available=profile.is_available,
        max_distance_m=profile.max_distance_m,
        quiet_from_hour=profile.quiet_from_hour,
        quiet_to_hour=profile.quiet_to_hour,
        has_position=profile.coarse_lat is not None,
    )
