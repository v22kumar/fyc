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


# ── Is this even our district? ───────────────────────────────────────────────


def _report(db, club, member, *, lat, lng, place):
    from app.models.issue import IssueStatus, PublicIssue

    issue = PublicIssue(
        id=uuid.uuid4(), organization_id=club.id,
        reported_by_user_id=member.id, category="STREET_LIGHT",
        description_en="A light is out", description_ta="விளக்கு எரியவில்லை",
        latitude=lat, longitude=lng, location_name=place,
        status=IssueStatus.NEW,
    )
    db.add(issue)
    db.commit()
    return issue


def test_a_complaint_from_outside_the_district_gets_no_ladder(
    client, db, club, member, auth
):
    """The bug this exists to stop.

    A member in Bengaluru photographing a pothole outside their office was
    handed an Assistant Engineer in Nagercoil — addressed, plausible, and six
    hundred kilometres from the pothole.
    """
    _give_phone(db, club, "ULB_ELECTRICAL", "9443130460")
    issue = _report(db, club, member, lat=12.9716, lng=77.5946,
                    place="Indiranagar, Bengaluru")

    body = client.get("/api/v1/civic/ladder",
                      params={"category": "STREET_LIGHT",
                              "complaint_id": str(issue.id)},
                      headers=auth).json()

    assert body["covered"] is False
    assert body["rungs"] == [], "no office here speaks for Bengaluru"
    assert body["outside_place"] == "Indiranagar, Bengaluru", (
        "the member should be able to see which place we read, in case their "
        "GPS was wrong"
    )


def test_a_complaint_from_inside_the_district_still_gets_the_ladder(
    client, db, club, member, auth
):
    _give_phone(db, club, "ULB_ELECTRICAL", "9443130460")
    issue = _report(db, club, member, lat=8.1833, lng=77.4119, place="Nagercoil")

    body = client.get("/api/v1/civic/ladder",
                      params={"category": "STREET_LIGHT",
                              "complaint_id": str(issue.id)},
                      headers=auth).json()

    assert body["covered"] is True
    assert body["rungs"], "Nagercoil is exactly what this directory is for"


def test_a_ladder_asked_for_without_a_complaint_is_still_answered(
    client, db, club, auth
):
    """Coverage is only knowable when there is a report with coordinates.

    Browsing the directory with no complaint in hand must not be treated as
    being outside the district — unknown is not elsewhere.
    """
    body = client.get("/api/v1/civic/ladder",
                      params={"category": "STREET_LIGHT"}, headers=auth).json()
    assert body["covered"] is True
    assert body["rungs"]


def test_somebody_elses_complaint_does_not_steer_the_ladder(
    client, db, club, member, auth
):
    """The complaint is a hint, and hints from strangers are ignored.

    Passing an arbitrary id must not read another member's coordinates back —
    the ladder falls back to the caller's own area instead.
    """
    other = User(
        id=uuid.uuid4(), organization_id=club.id, phone_number="+919000000099",
        email="other@example.invalid", password_hash="x", role="USER",
        is_verified=True,
    )
    db.add(other)
    db.commit()
    issue = _report(db, club, other, lat=12.9716, lng=77.5946, place="Bengaluru")

    body = client.get("/api/v1/civic/ladder",
                      params={"category": "STREET_LIGHT",
                              "complaint_id": str(issue.id)},
                      headers=auth).json()

    assert body["covered"] is True
    assert body["outside_place"] is None


def test_a_report_with_no_gps_fix_still_gets_the_ladder(
    client, db, club, member, auth
):
    """(0, 0) is not the Gulf of Guinea, it is "the phone would not say".

    `public_issues.latitude` is NOT NULL, so the report screen sends zeroes
    when location permission was refused. Reading that literally would tell a
    member standing in Vadasery that their own town is out of area.
    """
    _give_phone(db, club, "ULB_ELECTRICAL", "9443130460")
    issue = _report(db, club, member, lat=0, lng=0, place=None)

    body = client.get("/api/v1/civic/ladder",
                      params={"category": "STREET_LIGHT",
                              "complaint_id": str(issue.id)},
                      headers=auth).json()

    assert body["covered"] is True
    assert body["rungs"]
