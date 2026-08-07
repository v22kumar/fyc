"""The ladder a member sees before they do anything.

The screen this feeds is the one that turns "I don't know who to call" into
five numbers. Its central property is not that it finds the right officer —
it is that it shows the *whole route*, including the rungs nobody has filled
in yet. A member handed a single number who is ignored by that number has no
visible next step, and stops.
"""
import uuid

import pytest

from app.core.security import create_access_token
from app.models.civic import Authority, Department
from app.models.tenant import Organization
from app.models.user import User
from seeds.civic_directory import seed


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="ladder-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


@pytest.fixture
def member(db, club):
    """An ordinary member. Ringing a public officer is not an admin power."""
    u = User(
        id=uuid.uuid4(), organization_id=club.id, phone_number="+919000000021",
        email="member@example.invalid", password_hash="x", role="USER",
        is_verified=True,
    )
    db.add(u)
    db.commit()
    return u


@pytest.fixture
def auth(member, club):
    return {
        "Authorization": f"Bearer {create_access_token(str(member.id), member.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


def _give_phone(db, club, department_code, phone):
    dept = (db.query(Department)
              .filter(Department.organization_id == club.id,
                      Department.code == department_code)
              .first())
    a = (db.query(Authority)
           .filter(Authority.organization_id == club.id,
                   Authority.department_id == dept.id)
           .order_by(Authority.rung.asc())
           .first())
    a.phone = phone
    db.commit()
    return a


def test_an_ordinary_member_can_see_the_ladder(client, db, club, auth):
    r = client.get("/api/v1/civic/ladder", params={"category": "STREET_LIGHT"},
                   headers=auth)
    assert r.status_code == 200, r.text


def test_the_whole_route_comes_back_not_just_the_reachable_officer(
    client, db, club, auth
):
    """The point of the screen.

    Only one office has a number, but every rung above it is still listed. Hide
    the unreachable ones and the member believes the ladder ends where our data
    happens to end.
    """
    _give_phone(db, club, "ULB_ELECTRICAL", "9443130460")

    body = client.get("/api/v1/civic/ladder",
                      params={"category": "STREET_LIGHT"}, headers=auth).json()

    assert len(body["rungs"]) > 1, "a single-rung ladder is the failure this prevents"
    assert any(r["can_call"] for r in body["rungs"])
    assert any(not r["can_call"] for r in body["rungs"]), (
        "offices with no contact yet must still be shown, marked — a hidden gap "
        "is a gap nobody fills"
    )


def test_the_rungs_climb(client, db, club, auth):
    body = client.get("/api/v1/civic/ladder",
                      params={"category": "WATER"}, headers=auth).json()
    positions = [r["position"] for r in body["rungs"]]
    assert positions == sorted(positions), "nearest office first, then upwards"


def test_each_rung_says_what_it_covers(client, db, club, auth):
    """'Assistant Engineer' means nothing without 'your ward' beside it."""
    body = client.get("/api/v1/civic/ladder",
                      params={"category": "WATER"}, headers=auth).json()
    assert all(r["covers_en"] for r in body["rungs"])


def test_a_reachable_rung_carries_the_number_to_dial(client, db, club, auth):
    _give_phone(db, club, "ULB_WATER", "9443132365")
    body = client.get("/api/v1/civic/ladder",
                      params={"category": "WATER"}, headers=auth).json()
    callable_rungs = [r for r in body["rungs"] if r["can_call"]]
    assert callable_rungs and all(r["phone"] for r in callable_rungs)


def test_an_unknown_category_is_not_an_error(client, db, club, auth):
    """A member who has just photographed a broken drain should not meet a 500
    because the directory has no rule for what they typed."""
    r = client.get("/api/v1/civic/ladder", params={"category": "NOT_A_CATEGORY"},
                   headers=auth)
    assert r.status_code == 200, r.text
