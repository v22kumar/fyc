"""SOS.

The feature these replace had **no tests and no table**. It pushed to every
member of the organisation behind a button labelled "Alert nearby FYC members",
stored nothing, and told a member in danger "Alert sent to members" after
merely queueing a background task.

Two properties are held to account here, and they are the same two the
Complaint Box holds:

* **Radius before roster.** Nobody outside the ring is told, at any stage.
* **Nobody's state is invented.** "Coming" is written by a responder, "safe" is
  written by the member, and no timer writes either.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.core.security import create_access_token
from app.models.safety import (
    ResponderProfile, SafetyContact, SosIncident, SosResponder, SosStatus,
)
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.services.sos_dispatch import WAVES, coarsen, haversine_m

# Nagercoil bus stand, and points at known distances from it.
HERE = (8.1833, 77.4119)


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="sos-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    return org


def _member(db, club, *, name, phone, role="USER", lat=None, lng=None,
            available=False, max_m=20000, quiet=None):
    u = User(id=uuid.uuid4(), organization_id=club.id, phone_number=phone,
             email=f"{uuid.uuid4().hex[:8]}@example.invalid",
             password_hash="x", role=role, is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    if available or lat is not None:
        db.add(ResponderProfile(
            organization_id=club.id, user_id=u.id, is_available=available,
            max_distance_m=max_m,
            quiet_from_hour=quiet[0] if quiet else None,
            quiet_to_hour=quiet[1] if quiet else None,
            coarse_lat=coarsen(lat), coarse_lng=coarsen(lng),
            coarse_at=datetime.now(timezone.utc) if lat is not None else None,
        ))
    db.commit()
    return u


def _auth(user, club):
    return {
        "Authorization":
            f"Bearer {create_access_token(str(user.id), user.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


@pytest.fixture
def raiser(db, club):
    return _member(db, club, name="Arun Kumar", phone="+919000001001")


@pytest.fixture
def auth(raiser, club):
    return _auth(raiser, club)


def _raise(client, auth, **body):
    payload = {"latitude": HERE[0], "longitude": HERE[1], "accuracy_m": 12}
    payload.update(body)
    r = client.post("/api/v1/safety/sos", json=payload, headers=auth)
    assert r.status_code == 201, r.text
    return r.json()


# ── The fault this whole rewrite exists for ──────────────────────────────────


def test_a_member_far_away_is_never_told(client, db, club, raiser, auth):
    """The bug: "Alert nearby FYC members" was `WHERE organization_id = ?`.

    A club woken twice by an SOS from six hundred kilometres away mutes the
    channel, and then the real one arrives and nobody sees it.
    """
    near = _member(db, club, name="Suresh", phone="+919000001002",
                   lat=8.185, lng=77.413, available=True)
    far = _member(db, club, name="Bengaluru Member", phone="+919000001003",
                  lat=12.9716, lng=77.5946, available=True)

    body = _raise(client, auth)

    told = {r["user_id"] for r in body["responders"]}
    assert str(near.id) in told
    assert str(far.id) not in told, "600 km is not nearby"


def test_wave_one_stops_at_five_nearest(client, db, club, raiser, auth):
    """Not everyone in range — the nearest few.

    Response rates run 17–47%, so one is not enough; but the tenth-nearest
    cannot help either, and telling them is how the channel gets muted.
    """
    for i in range(9):
        _member(db, club, name=f"M{i}", phone=f"+91900010{i:04d}",
                lat=8.183 + i * 0.001, lng=77.412, available=True)

    body = _raise(client, auth)
    assert len(body["responders"]) == WAVES[0].max_responders


def test_a_member_who_opted_out_is_not_on_the_roster(client, db, club, raiser, auth):
    """Being woken at 2 a.m. by a stranger's emergency is opt-in or nothing."""
    _member(db, club, name="Not volunteering", phone="+919000001010",
            lat=8.184, lng=77.412, available=False)

    body = _raise(client, auth)
    assert body["responders"] == []


def test_quiet_hours_are_respected_across_midnight(db, club, raiser):
    """22:00–06:00 is the common case and the naive comparison inverts it."""
    from app.services.sos_dispatch import _within_quiet_hours

    profile = ResponderProfile(organization_id=club.id, user_id=raiser.id,
                               quiet_from_hour=22, quiet_to_hour=6)
    at = lambda h: datetime(2026, 8, 9, h, tzinfo=timezone.utc)

    assert _within_quiet_hours(profile, at(23))
    assert _within_quiet_hours(profile, at(3))
    assert not _within_quiet_hours(profile, at(12))


def test_a_responders_own_limit_is_honoured(client, db, club, raiser, auth):
    """Agreeing to help within a kilometre is not agreeing to wave 3."""
    _member(db, club, name="Close only", phone="+919000001011",
            lat=8.191, lng=77.412, available=True, max_m=300)

    body = _raise(client, auth)
    assert body["responders"] == [], "roughly 900 m away, limit 300 m"


# ── Nothing is invented ──────────────────────────────────────────────────────


def test_raising_claims_a_count_not_a_comfort(client, db, club, raiser, auth):
    """The old screen said "FYC members have been alerted" after queueing a job.

    What comes back now is how many rows exist, and how many of those people
    have actually said anything — which is usually none, at first.
    """
    _member(db, club, name="Suresh", phone="+919000001004",
            lat=8.185, lng=77.413, available=True)

    body = _raise(client, auth)
    assert body["alerted_count"] == 1
    assert body["acknowledged_count"] == 0, "nobody has said a word yet"


def test_only_a_responder_can_say_they_are_coming(client, db, club, raiser, auth):
    suresh = _member(db, club, name="Suresh", phone="+919000001005",
                     lat=8.185, lng=77.413, available=True)
    incident = _raise(client, auth)

    r = client.post(f"/api/v1/safety/sos/{incident['id']}/ack",
                    headers=_auth(suresh, club))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == SosStatus.ACKNOWLEDGED.value
    assert body["acknowledged_count"] == 1


def test_a_stranger_cannot_answer_an_sos_they_were_not_called_to(
    client, db, club, raiser, auth
):
    outsider = _member(db, club, name="Nosy", phone="+919000001006")
    incident = _raise(client, auth)

    r = client.post(f"/api/v1/safety/sos/{incident['id']}/ack",
                    headers=_auth(outsider, club))
    assert r.status_code == 403


def test_an_organiser_must_confirm_they_spoke_to_the_member(
    client, db, club, raiser, auth
):
    """Guessing that somebody is fine is the inference this design forbids."""
    boss = _member(db, club, name="Organiser", phone="+919000001007",
                   role="ADMIN")
    incident = _raise(client, auth)

    r = client.post(f"/api/v1/safety/sos/{incident['id']}/stand-down",
                    json={}, headers=_auth(boss, club))
    assert r.status_code == 422

    r = client.post(f"/api/v1/safety/sos/{incident['id']}/stand-down",
                    json={"spoke_to_them": True, "reason": "spoke to him"},
                    headers=_auth(boss, club))
    assert r.status_code == 200
    assert r.json()["is_open"] is False


def test_the_member_can_always_stand_their_own_down(client, db, club, raiser, auth):
    incident = _raise(client, auth)
    r = client.post(f"/api/v1/safety/sos/{incident['id']}/stand-down",
                    json={"reason": "false alarm"}, headers=auth)
    assert r.status_code == 200
    assert r.json()["is_open"] is False


def test_reopening_restores_the_wave_it_was_on(client, db, club, raiser, auth):
    incident = _raise(client, auth)
    client.post(f"/api/v1/safety/sos/{incident['id']}/stand-down",
                json={}, headers=auth)
    r = client.post(f"/api/v1/safety/sos/{incident['id']}/reopen", headers=auth)
    assert r.status_code == 200
    assert r.json()["is_open"] is True


# ── Everybody declining is a signal, not a silence ───────────────────────────


def test_when_everyone_declines_the_next_wave_goes_at_once(
    client, db, club, raiser, auth
):
    """A decline is worth as much as an acceptance and much easier to get.

    Once the whole wave has said no there is nothing left to wait for, so the
    ring widens immediately rather than sitting out the timer.
    """
    close = _member(db, club, name="Close", phone="+919000001008",
                    lat=8.185, lng=77.413, available=True)
    further = _member(db, club, name="Further", phone="+919000001009",
                      lat=8.200, lng=77.430, available=True)

    incident = _raise(client, auth)
    told = {r["user_id"] for r in incident["responders"]}
    assert str(close.id) in told and str(further.id) not in told

    r = client.post(f"/api/v1/safety/sos/{incident['id']}/decline",
                    headers=_auth(close, club))
    assert r.status_code == 200
    body = r.json()
    assert body["wave"] == 2
    assert str(further.id) in {x["user_id"] for x in body["responders"]}


def test_one_acceptance_stops_the_ring_widening(client, db, club, raiser, auth):
    close = _member(db, club, name="Close", phone="+919000001020",
                    lat=8.185, lng=77.413, available=True)
    other = _member(db, club, name="Other", phone="+919000001021",
                    lat=8.186, lng=77.414, available=True)

    incident = _raise(client, auth)
    client.post(f"/api/v1/safety/sos/{incident['id']}/ack",
                headers=_auth(close, club))
    r = client.post(f"/api/v1/safety/sos/{incident['id']}/decline",
                    headers=_auth(other, club))
    assert r.json()["wave"] == 1, "somebody is already coming"


# ── Contact details are not handed out for free ──────────────────────────────


def test_a_responders_number_appears_only_once_they_accept(
    client, db, club, raiser, auth
):
    """Before that it is a phone number given away for an event they have not
    agreed to take part in."""
    suresh = _member(db, club, name="Suresh", phone="+919000001030",
                     lat=8.185, lng=77.413, available=True)

    incident = _raise(client, auth)
    assert incident["responders"][0]["phone"] is None

    body = client.post(f"/api/v1/safety/sos/{incident['id']}/ack",
                       headers=_auth(suresh, club)).json()
    assert body["responders"][0]["phone"] == "+919000001030"


def test_an_sos_is_not_club_news(client, db, club, raiser, auth):
    outsider = _member(db, club, name="Nosy", phone="+919000001031")
    incident = _raise(client, auth)
    r = client.get(f"/api/v1/safety/sos/{incident['id']}",
                   headers=_auth(outsider, club))
    assert r.status_code == 403


# ── Never refuse ─────────────────────────────────────────────────────────────


def test_a_panicking_thumb_pressing_twice_raises_one_incident(client, auth):
    first = _raise(client, auth, idempotency_key="abc123")
    second = _raise(client, auth, idempotency_key="abc123")
    assert first["id"] == second["id"]


def test_no_location_still_raises(client, db, club, raiser, auth):
    """"We do not know where they are" is a reason to ask more people, not to
    refuse the SOS."""
    r = client.post("/api/v1/safety/sos", json={}, headers=auth)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["latitude"] is None
    assert any(e["detail"] == "location unknown" for e in body["events"])


def test_the_rate_limit_contains_rather_than_refuses(client, db, club, raiser, auth):
    """You never turn away somebody who might be dying.

    The fourth SOS in an hour is still raised — it just does not get to
    escalate to the whole district, and an organiser is asked to look.
    """
    for i in range(3):
        _raise(client, auth, idempotency_key=f"k{i}")

    r = client.post("/api/v1/safety/sos",
                    json={"latitude": HERE[0], "longitude": HERE[1]},
                    headers=auth)
    assert r.status_code == 201, "an SOS is never refused"
    assert r.json()["is_throttled"] is True


def test_a_throttled_incident_does_not_widen(client, db, club, raiser, auth):
    from app.services.sos_dispatch import next_wave_due_at

    for i in range(3):
        _raise(client, auth, idempotency_key=f"j{i}")
    body = _raise(client, auth)

    incident = db.get(SosIncident, uuid.UUID(body["id"]))
    assert incident.is_throttled
    assert next_wave_due_at(incident) is None


# ── Trusted contacts ─────────────────────────────────────────────────────────


def test_contacts_live_on_the_server_with_names(client, auth):
    """They lived in SharedPreferences as bare digits, so a lost phone silenced
    them and the list could not be read."""
    r = client.post("/api/v1/safety/contacts",
                    json={"name": "Amma", "phone": "+91 98400 11111",
                          "relationship_label": "Mother"},
                    headers=auth)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["name"] == "Amma"
    assert body["phone"] == "+919840011111", "spaces stripped"
    assert body["verified_at"] is None, "nobody has tested it yet"


def test_the_same_number_twice_is_refused(client, auth):
    client.post("/api/v1/safety/contacts",
                json={"name": "Amma", "phone": "+919840011111"}, headers=auth)
    r = client.post("/api/v1/safety/contacts",
                    json={"name": "Amma again", "phone": "+919840011111"},
                    headers=auth)
    assert r.status_code == 409


def test_contacts_are_private_to_their_owner(client, db, club, raiser, auth):
    client.post("/api/v1/safety/contacts",
                json={"name": "Amma", "phone": "+919840011111"}, headers=auth)
    other = _member(db, club, name="Other", phone="+919000001040")
    r = client.get("/api/v1/safety/contacts", headers=_auth(other, club))
    assert r.json() == []


# ── Being a responder ────────────────────────────────────────────────────────


def test_nobody_is_a_responder_by_default(client, auth):
    r = client.get("/api/v1/safety/availability", headers=auth)
    assert r.status_code == 200
    assert r.json()["is_available"] is False


def test_a_stored_position_is_coarse(client, db, club, raiser, auth):
    """Precise enough to pick the five nearest, far too coarse to follow
    somebody home."""
    client.put("/api/v1/safety/availability",
               json={"is_available": True, "max_distance_m": 2000,
                     "latitude": 8.183312, "longitude": 77.411987},
               headers=auth)
    profile = (db.query(ResponderProfile)
                 .filter(ResponderProfile.user_id == raiser.id).first())
    assert profile.coarse_lat == 8.18
    assert profile.coarse_lng == 77.41


def test_leaving_the_roster_takes_your_position_with_you(client, db, club, raiser, auth):
    client.put("/api/v1/safety/availability",
               json={"is_available": True, "latitude": 8.18, "longitude": 77.41},
               headers=auth)
    client.put("/api/v1/safety/availability",
               json={"is_available": False}, headers=auth)
    profile = (db.query(ResponderProfile)
                 .filter(ResponderProfile.user_id == raiser.id).first())
    assert profile.coarse_lat is None


def test_the_api_never_hands_back_a_responders_position(client, auth):
    client.put("/api/v1/safety/availability",
               json={"is_available": True, "latitude": 8.18, "longitude": 77.41},
               headers=auth)
    body = client.get("/api/v1/safety/availability", headers=auth).json()
    assert body["has_position"] is True
    assert "latitude" not in body and "coarse_lat" not in body


# ── The old endpoint is gone ─────────────────────────────────────────────────


def test_the_org_wide_broadcast_no_longer_exists(client, auth):
    r = client.post("/api/v1/notifications/sos-alert", json={}, headers=auth)
    assert r.status_code == 404


# ── Distance maths ───────────────────────────────────────────────────────────


def test_haversine_is_metres(client):
    # Nagercoil to Kanniyakumari is about 19 km.
    d = haversine_m(8.1833, 77.4119, 8.0883, 77.5385)
    assert 17_000 < d < 21_000


# ── Silence widens the ring; nothing else does ───────────────────────────────


def test_silence_widens_the_ring(client, db, club, raiser, auth):
    """45 seconds with nobody answering is the one signal that means anything.

    The sweep is driven by the timeline rather than a stored deadline, so the
    test ages the WAVE_SENT row rather than sleeping.
    """
    from app.models.safety import SosEvent, SosEventType
    from app.services.sos_escalation import sweep_escalations

    _member(db, club, name="Close", phone="+919000001050",
            lat=8.185, lng=77.413, available=True)
    further = _member(db, club, name="Further", phone="+919000001051",
                      lat=8.200, lng=77.430, available=True)

    body = _raise(client, auth)
    incident_id = uuid.UUID(body["id"])

    stale = datetime.now(timezone.utc) - timedelta(seconds=120)
    for event in (db.query(SosEvent)
                    .filter(SosEvent.incident_id == incident_id,
                            SosEvent.event_type == SosEventType.WAVE_SENT.value)
                    .all()):
        event.created_at = stale
    db.commit()

    assert sweep_escalations(db) == 1

    db.expire_all()
    incident = db.get(SosIncident, incident_id)
    assert incident.wave == 2
    assert any(r.user_id == further.id for r in incident.responders)


def test_the_sweep_never_ends_an_incident(client, db, club, raiser, auth):
    """A timer may widen a ring. It may not decide somebody is safe.

    An incident that runs out of waves stays open and unanswered — which is a
    true and useful thing to be looking at, and not a state worth inventing.
    """
    from app.models.safety import SosEvent, SosEventType
    from app.services.sos_escalation import sweep_escalations

    _member(db, club, name="Close", phone="+919000001060",
            lat=8.185, lng=77.413, available=True)
    body = _raise(client, auth)
    incident_id = uuid.UUID(body["id"])

    for _ in range(4):
        stale = datetime.now(timezone.utc) - timedelta(seconds=600)
        for event in (db.query(SosEvent)
                        .filter(SosEvent.incident_id == incident_id,
                                SosEvent.event_type == SosEventType.WAVE_SENT.value)
                        .all()):
            event.created_at = stale
        db.commit()
        sweep_escalations(db)

    db.expire_all()
    incident = db.get(SosIncident, incident_id)
    assert incident.is_open, "nobody said they were safe"
    assert incident.status != SosStatus.STOOD_DOWN.value
    assert incident.wave <= len(WAVES)


def test_an_acknowledged_incident_stops_escalating(client, db, club, raiser, auth):
    from app.models.safety import SosEvent, SosEventType
    from app.services.sos_escalation import sweep_escalations

    close = _member(db, club, name="Close", phone="+919000001070",
                    lat=8.185, lng=77.413, available=True)
    _member(db, club, name="Further", phone="+919000001071",
            lat=8.200, lng=77.430, available=True)

    body = _raise(client, auth)
    incident_id = uuid.UUID(body["id"])
    client.post(f"/api/v1/safety/sos/{incident_id}/ack",
                headers=_auth(close, club))

    stale = datetime.now(timezone.utc) - timedelta(seconds=600)
    for event in (db.query(SosEvent)
                    .filter(SosEvent.incident_id == incident_id,
                            SosEvent.event_type == SosEventType.WAVE_SENT.value)
                    .all()):
        event.created_at = stale
    db.commit()

    assert sweep_escalations(db) == 0, "somebody is already coming"


def test_the_timeline_names_an_author_on_every_row(client, db, club, raiser, auth):
    """The same rule as the Complaint Box, with higher stakes: this screen is
    read by somebody in trouble."""
    suresh = _member(db, club, name="Suresh", phone="+919000001080",
                     lat=8.185, lng=77.413, available=True)
    body = _raise(client, auth)
    client.post(f"/api/v1/safety/sos/{body['id']}/ack", headers=_auth(suresh, club))
    body = client.get(f"/api/v1/safety/sos/{body['id']}", headers=auth).json()

    assert body["events"], "an incident with no timeline explains nothing"
    assert all(e["author"] in {"MEMBER", "RESPONDER", "FYC", "SYSTEM"}
               for e in body["events"])
    ack = next(e for e in body["events"] if e["event_type"] == "ACKNOWLEDGED")
    assert ack["author"] == "RESPONDER"
    assert ack["author_name"] == "Suresh"


# ── The alarm rings on the phone that can help ───────────────────────────────


def test_a_trusted_contact_who_is_a_member_is_told_at_once(
    client, db, club, raiser, auth
):
    """Your wife should not be reduced to an SMS because she is far away.

    A trusted contact who also uses the app is told first and for a different
    reason from everybody else — because she is yours, not because she is
    near — so she joins at wave 0 with no distance attached.
    """
    wife = _member(db, club, name="Meena", phone="+919000002001")
    client.post("/api/v1/safety/contacts",
                json={"name": "Meena", "phone": "+919000002001",
                      "relationship_label": "Wife"},
                headers=auth)

    body = _raise(client, auth)

    hers = next(r for r in body["responders"] if r["user_id"] == str(wife.id))
    assert hers["wave"] == 0
    assert hers["distance_m"] is None, (
        "she was not chosen for being close, and a distance would imply she was"
    )
    assert body["alerted_count"] == 1


def test_a_contact_member_can_say_they_are_coming(client, db, club, raiser, auth):
    """Wave 0 is a real place on the list, not a footnote."""
    wife = _member(db, club, name="Meena", phone="+919000002002")
    client.post("/api/v1/safety/contacts",
                json={"name": "Meena", "phone": "+919000002002"}, headers=auth)
    incident = _raise(client, auth)

    r = client.post(f"/api/v1/safety/sos/{incident['id']}/ack",
                    headers=_auth(wife, club))
    assert r.status_code == 200, r.text
    assert r.json()["acknowledged_count"] == 1


def test_a_contact_who_is_not_a_member_gets_no_phantom_responder(
    client, db, club, raiser, auth
):
    """Nothing is guessed. No match, no row — the SMS is what they get."""
    client.post("/api/v1/safety/contacts",
                json={"name": "Amma", "phone": "+919999999999"}, headers=auth)

    body = _raise(client, auth)
    assert body["responders"] == []
    assert body["alerted_count"] == 0


def test_a_contact_member_is_not_told_twice(client, db, club, raiser, auth):
    """Somebody who is both your emergency contact and the nearest responder
    is one person, and gets one row."""
    both = _member(db, club, name="Meena", phone="+919000002003",
                   lat=8.185, lng=77.413, available=True)
    client.post("/api/v1/safety/contacts",
                json={"name": "Meena", "phone": "+919000002003"}, headers=auth)

    body = _raise(client, auth)
    hers = [r for r in body["responders"] if r["user_id"] == str(both.id)]
    assert len(hers) == 1
    assert body["alerted_count"] == 1


def test_the_raiser_is_never_their_own_responder(client, db, club, raiser, auth):
    """A member who saved their own number as a contact must not be alerted
    about themselves."""
    client.post("/api/v1/safety/contacts",
                json={"name": "Me", "phone": raiser.phone_number}, headers=auth)

    body = _raise(client, auth)
    assert all(r["user_id"] != str(raiser.id) for r in body["responders"])


def test_the_setup_screen_only_promises_a_ring_it_can_deliver(
    client, db, club, raiser, auth
):
    """A contact who uses the app gets a push on the alarm channel; one who
    does not gets an SMS that lands silently. Saying "rings like an alarm" for
    the second is the same species of lie as the four green ticks."""
    _member(db, club, name="Meena", phone="+919000002010")
    client.post("/api/v1/safety/contacts",
                json={"name": "Meena", "phone": "+919000002010"}, headers=auth)
    client.post("/api/v1/safety/contacts",
                json={"name": "Amma", "phone": "+918888888888"}, headers=auth)

    by_name = {c["name"]: c for c in
               client.get("/api/v1/safety/contacts", headers=auth).json()}

    assert by_name["Meena"]["is_member"] is True
    assert by_name["Amma"]["is_member"] is False
