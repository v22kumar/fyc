"""An event could not say what kind of gathering it was.

The club runs competitions, blood camps, weddings, funerals, temple festivals,
AGMs and coaching camps. Every one of them was stored, listed and announced
identically, because the only classification an Event carried was
`registration_type` — which describes how people *sign up*, not what the thing
*is*.

So an organiser creating a wedding was given the same four boxes as one
creating a cricket tournament, and a member scrolling the events list could not
tell a blood camp from a drawing competition without reading the description.
"""
import uuid
from datetime import datetime, timedelta, timezone

from app.core.security import get_password_hash
from app.models.event import Event
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"ek-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _organiser(db, org_id, phone="9770000001"):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role="EXECUTIVE_MEMBER",
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="அமைப்பாளர்",
                       full_name_en="Organiser"))
    db.commit()
    return u


def _headers(client, org_id, phone="9770000001"):
    token = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org_id), "username": phone,
        "password": "pass"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}",
            "X-Organization-ID": str(org_id)}


def _payload(**over):
    start = datetime.now(timezone.utc) + timedelta(days=7)
    return {
        "title_en": "Wedding of Anitha & Suresh", "title_ta": "திருமணம்",
        "description_en": "All members welcome", "description_ta": "வரவேற்பு",
        "event_start": start.isoformat(),
        "event_end": (start + timedelta(hours=6)).isoformat(),
        **over,
    }


def test_a_wedding_is_not_a_competition(client, db):
    """The distinction the model could not previously express at all."""
    org = _org(db)
    _organiser(db, org.id)
    H = _headers(client, org.id)

    r = client.post("/api/v1/events", headers=H, json=_payload(
        event_kind="CELEBRATION", venue="Kumari Thirumana Mandapam"))
    assert r.status_code in (200, 201), r.text
    body = r.json()
    assert body["event_kind"] == "CELEBRATION"
    assert body["venue"] == "Kumari Thirumana Mandapam"


def test_every_kind_the_club_actually_runs_round_trips(client, db):
    org = _org(db)
    _organiser(db, org.id, "9770000002")
    H = _headers(client, org.id, "9770000002")

    for kind in ("COMPETITION", "SERVICE", "CELEBRATION", "CULTURAL",
                 "MEETING", "TRAINING", "OTHER"):
        r = client.post("/api/v1/events", headers=H,
                        json=_payload(event_kind=kind, title_en=f"{kind} day"))
        assert r.status_code in (200, 201), f"{kind}: {r.text}"
        assert r.json()["event_kind"] == kind


def test_a_kind_nobody_thought_of_is_accepted(client, db):
    """A village club will invent one, and a database migration is the wrong
    price for that. The vocabulary is a convention the UI offers, not a cage."""
    org = _org(db)
    _organiser(db, org.id, "9770000003")
    H = _headers(client, org.id, "9770000003")

    r = client.post("/api/v1/events", headers=H,
                    json=_payload(event_kind="temple_festival"))
    assert r.status_code in (200, 201)
    assert r.json()["event_kind"] == "TEMPLE_FESTIVAL", "normalised, not refused"


def test_an_event_created_without_a_kind_still_works(client, db):
    """Every event that already exists has no kind, and must not break."""
    org = _org(db)
    _organiser(db, org.id, "9770000004")
    H = _headers(client, org.id, "9770000004")

    r = client.post("/api/v1/events", headers=H, json=_payload())
    assert r.status_code in (200, 201)
    assert r.json()["event_kind"] == "OTHER", "the honest default"


def test_the_kind_survives_to_the_list_a_member_reads(client, db):
    org = _org(db)
    _organiser(db, org.id, "9770000005")
    H = _headers(client, org.id, "9770000005")
    client.post("/api/v1/events", headers=H, json=_payload(
        event_kind="SERVICE", title_en="Blood camp", is_published=True))

    listing = client.get("/api/v1/events", headers=H).json()
    camp = [e for e in listing if e["title_en"] == "Blood camp"]
    assert camp and camp[0]["event_kind"] == "SERVICE", \
        "a member must be able to tell a blood camp from a drawing competition"


def test_an_older_event_row_reads_back_without_a_kind(client, db):
    """Rows written before the column existed must not 500 the list."""
    org = _org(db)
    _organiser(db, org.id, "9770000006")
    start = datetime.now(timezone.utc) + timedelta(days=2)
    old_id = uuid.uuid4()
    db.add(Event(id=old_id, organization_id=org.id,
                 title_en="Old event", title_ta="பழைய",
                 description_en="x", description_ta="x",
                 event_start=start, event_end=start + timedelta(hours=2),
                 is_published=True))
    db.commit()
    # A row written before the column existed holds NULL: the reconcile adds
    # the column nullable and never backfills. The ORM default would hide that,
    # so it is forced here — this is the state every existing event is in.
    db.query(Event).filter(Event.id == old_id).update({Event.event_kind: None})
    db.commit()

    H = _headers(client, org.id, "9770000006")
    listing = client.get("/api/v1/events", headers=H).json()
    old = [e for e in listing if e["title_en"] == "Old event"]
    assert old and old[0]["event_kind"] is None
