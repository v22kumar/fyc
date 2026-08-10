"""One child, listed six times.

A participant list showed "Anshika R · 12 years · Class 8" six times over, and
"Anshith R" twice. The only duplicate guard on registration was `user_id` —
which is NULL for every public registration, because anyone may register anyone
for a public event. Nothing stopped the same form being filed again, and the
club had no way to remove the extra rows afterwards.

Two different problems wear the same face, and they need opposite answers:

* a **double-tap on Submit**, or a retry after a flaky connection, is a finger
  rather than a decision — it must be absorbed silently;
* a **genuine second registration** minutes or days later is a real question,
  and it must be asked out loud rather than filed quietly.
"""
import uuid
from datetime import datetime, timedelta, timezone

from app.core.security import get_password_hash
from app.models.event import Event, EventRegistration
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"ev-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _event(db, org_id):
    e = Event(id=uuid.uuid4(), organization_id=org_id,
              title_en="Drawing Competition", title_ta="ஓவியப் போட்டி",
              description_en="Draw", description_ta="வரை",
              event_start=datetime.now(timezone.utc) + timedelta(days=3),
              event_end=datetime.now(timezone.utc) + timedelta(days=4),
              is_published=True, registration_enabled=True)
    db.add(e)
    db.commit()
    return e


def _h(org_id, token=None):
    h = {"X-Organization-ID": str(org_id)}
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


ANSHIKA = {
    "name": "Anshika R",
    "dob": "2014-03-11T00:00:00",
    "school_college": "Govt High School",
    "class_grade": "Class 8",
    "mobile_number": "9487984964",
}


def _register(client, org_id, event_id, **overrides):
    body = {**ANSHIKA, **overrides}
    return client.post(f"/api/v1/events/{event_id}/register", json=body,
                       headers=_h(org_id))


def test_a_double_tap_does_not_create_a_second_child(client, db):
    """The bug as it actually happened: Submit pressed twice."""
    org = _org(db)
    event = _event(db, org.id)

    first = _register(client, org.id, event.id)
    assert first.status_code == 200, first.text
    second = _register(client, org.id, event.id)

    assert second.status_code == 200, "a finger slip must not become an error"
    assert second.json()["id"] == first.json()["id"], \
        "the same registration comes back, rather than a second one being made"
    assert db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).count() == 1


def test_registering_the_same_child_later_asks_first(client, db):
    """Minutes later is a decision, not a slip — so it is put to the member."""
    org = _org(db)
    event = _event(db, org.id)
    assert _register(client, org.id, event.id).status_code == 200

    # Age the first registration past the double-tap window.
    row = db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).one()
    row.created_at = datetime.now(timezone.utc) - timedelta(hours=2)
    db.commit()

    again = _register(client, org.id, event.id)
    assert again.status_code == 409
    detail = again.json()["detail"]
    assert detail["code"] == "ALREADY_REGISTERED"
    # The app has to name the person, not say "duplicate detected".
    assert detail["existing"]["name"] == "Anshika R"
    assert detail["existing"]["class_grade"] == "Class 8"
    assert detail["existing"]["age"] is not None
    assert db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).count() == 1


def test_saying_yes_goes_through(client, db):
    """Asked and answered. The club may genuinely want two entries."""
    org = _org(db)
    event = _event(db, org.id)
    assert _register(client, org.id, event.id).status_code == 200
    row = db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).one()
    row.created_at = datetime.now(timezone.utc) - timedelta(hours=2)
    db.commit()

    confirmed = _register(client, org.id, event.id, confirm_duplicate=True)
    assert confirmed.status_code == 200
    assert db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).count() == 2


def test_a_different_child_with_the_same_name_is_not_a_duplicate(client, db):
    """This is a village club: two children share a name all the time.

    Blocking the second one would be worse than the duplicate, so a different
    birthday is a different child until something else says otherwise.
    """
    org = _org(db)
    event = _event(db, org.id)
    assert _register(client, org.id, event.id).status_code == 200

    other = _register(client, org.id, event.id,
                      dob="2016-07-02T00:00:00", class_grade="Class 6",
                      mobile_number="9000000123")
    assert other.status_code == 200, "a different age is a different child"
    assert db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).count() == 2


def test_the_same_family_number_catches_a_retyped_birthday(client, db):
    """Second attempt, birthday typed differently, same family phone."""
    org = _org(db)
    event = _event(db, org.id)
    assert _register(client, org.id, event.id).status_code == 200
    row = db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).one()
    row.created_at = datetime.now(timezone.utc) - timedelta(hours=2)
    db.commit()

    again = _register(client, org.id, event.id, dob="2014-03-12T00:00:00")
    assert again.status_code == 409


def test_spacing_and_capitals_do_not_hide_a_duplicate(client, db):
    org = _org(db)
    event = _event(db, org.id)
    assert _register(client, org.id, event.id).status_code == 200
    row = db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).one()
    row.created_at = datetime.now(timezone.utc) - timedelta(hours=2)
    db.commit()

    assert _register(client, org.id, event.id,
                     name="  anshika   r ").status_code == 409


def _organiser(db, org_id, phone="9500000077"):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role="EXECUTIVE_MEMBER",
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="அமைப்பாளர்",
                       full_name_en="Organiser"))
    db.commit()
    return u


def test_an_organiser_can_remove_a_duplicate_that_slipped_through(client, db):
    """The club could see six rows and delete none of them.

    `DELETE /{event_id}/register` cancels *your own* registration by `user_id`,
    which is NULL for every public entry — so the extra rows were permanently
    unremovable and the participant count permanently wrong.
    """
    org = _org(db)
    event = _event(db, org.id)
    _organiser(db, org.id)
    token = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "9500000077",
        "password": "pass"}).json()["access_token"]

    reg_id = _register(client, org.id, event.id).json()["id"]
    r = client.delete(f"/api/v1/events/{event.id}/registrations/{reg_id}",
                      headers=_h(org.id, token))
    assert r.status_code == 200
    assert db.query(EventRegistration).filter(
        EventRegistration.event_id == event.id).count() == 0


def test_removing_a_registration_is_not_a_members_button(client, db):
    org = _org(db)
    event = _event(db, org.id)
    reg_id = _register(client, org.id, event.id).json()["id"]

    r = client.delete(f"/api/v1/events/{event.id}/registrations/{reg_id}",
                      headers=_h(org.id))
    assert r.status_code in (401, 403)
