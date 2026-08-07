"""The screen the club uses to turn an empty directory into a working one.

Forty offices with no contacts is a chore nobody finishes. The point of these
endpoints is to make it an afternoon: say which four offices unblock the most,
refuse a contact nobody can trace, and warn when one goes stale.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.core.security import create_access_token
from app.models.civic import Authority, Department
from app.models.tenant import Organization
from app.models.user import User
from app.routers.civic import STALE_AFTER
from seeds.civic_directory import seed


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="dir-club", name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


@pytest.fixture
def exec_user(db, club):
    u = User(
        id=uuid.uuid4(), organization_id=club.id, phone_number="+919000000009",
        email="exec@example.invalid", password_hash="x", role="EXECUTIVE_MEMBER",
        is_verified=True,
    )
    db.add(u)
    db.commit()
    return u


@pytest.fixture
def auth(exec_user, club):
    return {
        "Authorization": f"Bearer {create_access_token(str(exec_user.id), exec_user.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


def _office(db, club, code, designation):
    dept = db.query(Department).filter(
        Department.organization_id == club.id, Department.code == code
    ).one()
    return db.query(Authority).filter(
        Authority.department_id == dept.id, Authority.designation_en == designation
    ).first()


def test_the_queue_route_is_not_swallowed_by_the_issue_id_route(client, auth):
    """`/issues/queue` sits behind `/issues/{issue_id}` in the older router, and
    FastAPI matches in declaration order. If the new router is ever included
    after the old one, this returns 422 on parsing "queue" as a UUID."""
    r = client.get("/api/v1/issues/queue", headers=auth)

    assert r.status_code == 200, r.text
    assert set(r.json()) == {"waiting_on_us", "waiting_on_them", "overdue"}


def test_a_fresh_directory_lists_every_office_and_reaches_none(client, auth, club):
    r = client.get("/api/v1/civic/authorities", headers=auth)

    assert r.status_code == 200
    offices = r.json()
    assert offices, "the seed should list the offices to be filled in"
    assert all(not o["is_reachable"] for o in offices)
    assert all(not o["is_verified"] for o in offices)


def test_a_contact_without_a_source_is_refused(client, auth, db, club):
    """This directory decides where complaints about real streets get sent. An
    entry nobody can trace is one nobody can check when it stops working."""
    office = _office(db, club, "COLLECTORATE", "District Collector")

    r = client.patch(
        f"/api/v1/civic/authorities/{office.id}",
        json={"email": "someone@example.invalid"},
        headers=auth,
    )

    assert r.status_code == 400
    assert "source" in r.json()["detail"].lower()
    db.refresh(office)
    assert not office.email


def test_recording_a_contact_stamps_who_and_when(client, auth, db, club, exec_user):
    office = _office(db, club, "COLLECTORATE", "District Collector")

    r = client.patch(
        f"/api/v1/civic/authorities/{office.id}",
        json={
            "email": "collector@example.invalid",
            "source_url": "https://kanniyakumari.nic.in/",
        },
        headers=auth,
    )

    assert r.status_code == 200, r.text
    body = r.json()
    assert body["is_reachable"] and body["is_verified"] and not body["is_stale"]
    db.refresh(office)
    assert office.verified_by_user_id == exec_user.id
    assert office.verified_at is not None


def test_a_year_old_contact_is_flagged_rather_than_quietly_used(client, auth, db, club):
    """Officers transfer. A stale address is a complaint that vanishes."""
    office = _office(db, club, "COLLECTORATE", "District Collector")
    office.email = "old@example.invalid"
    office.source_url = "https://kanniyakumari.nic.in/"
    office.verified_at = datetime.now(timezone.utc) - STALE_AFTER - timedelta(days=1)
    db.commit()

    r = client.get("/api/v1/civic/authorities", headers=auth)
    found = next(o for o in r.json() if o["id"] == str(office.id))

    assert found["is_stale"]
    # Still reachable — flagged, not disabled. Old is not the same as wrong.
    assert found["is_reachable"]


def test_missing_contact_filter_gives_the_club_its_to_do_list(client, auth, db, club):
    office = _office(db, club, "COLLECTORATE", "District Collector")
    office.email = "collector@example.invalid"
    office.source_url = "https://kanniyakumari.nic.in/"
    db.commit()

    missing = client.get(
        "/api/v1/civic/authorities?missing_contact=true", headers=auth
    ).json()
    done = client.get(
        "/api/v1/civic/authorities?missing_contact=false", headers=auth
    ).json()

    assert str(office.id) not in [o["id"] for o in missing]
    assert [o["id"] for o in done] == [str(office.id)]


def test_health_says_which_office_to_fill_in_first(client, auth, db, club):
    """The whole point: not a list of forty, but the handful that buy the most."""
    r = client.get("/api/v1/civic/directory/health", headers=auth)

    assert r.status_code == 200, r.text
    health = r.json()
    assert health["ladders_total"] > 0
    assert health["ladders_blocked"] == health["ladders_total"], (
        "nothing is reachable in a fresh directory"
    )
    assert health["top_gaps"], "an empty directory should still say where to start"
    top = health["top_gaps"][0]
    assert top["would_unblock"] >= 1
    # Ordered by what it buys.
    unblocks = [g["would_unblock"] for g in health["top_gaps"]]
    assert unblocks == sorted(unblocks, reverse=True)


def test_filling_in_one_office_visibly_unblocks_ladders(client, auth, db, club):
    before = client.get("/api/v1/civic/directory/health", headers=auth).json()
    target = before["top_gaps"][0]

    r = client.patch(
        f"/api/v1/civic/authorities/{target['authority_id']}",
        json={"email": "office@example.invalid", "source_url": "https://kanniyakumari.nic.in/"},
        headers=auth,
    )
    assert r.status_code == 200, r.text

    after = client.get("/api/v1/civic/directory/health", headers=auth).json()

    assert after["offices_reachable"] == before["offices_reachable"] + 1
    assert after["ladders_blocked"] < before["ladders_blocked"], (
        "filling in the top gap should unblock something"
    )
    assert after["ladders_blocked"] == before["ladders_blocked"] - target["would_unblock"]
