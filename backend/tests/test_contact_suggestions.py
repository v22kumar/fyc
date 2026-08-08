"""Members filling the gaps in the directory.

Half the offices have no contact, and the missing ones are the local desks —
ward councillor, panchayat president, section office — blank precisely because
no district web page lists them. The people who have those numbers are the
members standing in front of those offices.

The gate is the point. A wrong number here does not inconvenience one person:
it sends every future complaint about that street to a stranger, over the
club's name, and nobody finds out for weeks.
"""
import uuid

import pytest

from app.core.security import create_access_token
from app.models.civic import Authority, ContactSuggestion, Department
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from seeds.civic_directory import seed


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="sugg-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


def _user(db, club, role, phone):
    u = User(id=uuid.uuid4(), organization_id=club.id, phone_number=phone,
             email=f"{phone}@example.invalid", password_hash="x", role=role,
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="Arun Kumar",
                       full_name_ta="அருண்"))
    db.commit()
    return u


def _headers(u, club):
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


@pytest.fixture
def member(db, club):
    return _user(db, club, "USER", "+919000000041")


@pytest.fixture
def organiser(db, club):
    return _user(db, club, "EXECUTIVE_MEMBER", "+919000000042")


@pytest.fixture
def blank_office(db, club):
    """An office the directory has no contact for — the normal case."""
    dept = (db.query(Department)
              .filter(Department.organization_id == club.id,
                      Department.code == "ULB_ELECTRICAL").first())
    a = (db.query(Authority)
           .filter(Authority.organization_id == club.id,
                   Authority.department_id == dept.id)
           .order_by(Authority.rung.asc()).first())
    assert not (a.phone or "").strip()
    return a


def _url(a):
    return f"/api/v1/civic/authorities/{a.id}/suggest-contact"


def test_a_member_can_offer_a_number(client, db, club, member, blank_office):
    r = client.post(_url(blank_office),
                    json={"phone": "9443132365",
                          "how_they_know": "On the board outside his office"},
                    headers=_headers(member, club))
    assert r.status_code == 201, r.text
    assert r.json()["status"] == "PENDING"


def test_it_does_not_reach_the_directory_until_somebody_approves(
    client, db, club, member, blank_office
):
    """The whole reason this is a queue and not a form."""
    client.post(_url(blank_office), json={"phone": "9443132365"},
                headers=_headers(member, club))
    db.refresh(blank_office)
    assert not (blank_office.phone or "").strip()


def test_an_organiser_accepting_it_fills_the_office(
    client, db, club, member, organiser, blank_office
):
    sid = client.post(_url(blank_office), json={"phone": "9443132365"},
                      headers=_headers(member, club)).json()["id"]

    r = client.post(f"/api/v1/civic/contact-suggestions/{sid}/review",
                    json={"accept": True}, headers=_headers(organiser, club))
    assert r.status_code == 200, r.text
    db.refresh(blank_office)
    assert blank_office.phone == "9443132365"
    assert blank_office.source_url, (
        "an entry nobody can trace is one nobody can check when it stops working"
    )


def test_a_member_cannot_approve_their_own_suggestion(
    client, db, club, member, blank_office
):
    sid = client.post(_url(blank_office), json={"phone": "9443132365"},
                      headers=_headers(member, club)).json()["id"]
    r = client.post(f"/api/v1/civic/contact-suggestions/{sid}/review",
                    json={"accept": True}, headers=_headers(member, club))
    assert r.status_code == 403
    db.refresh(blank_office)
    assert not (blank_office.phone or "").strip()


def test_rejecting_leaves_the_office_alone_and_records_why(
    client, db, club, member, organiser, blank_office
):
    sid = client.post(_url(blank_office), json={"phone": "9443132365"},
                      headers=_headers(member, club)).json()["id"]
    r = client.post(f"/api/v1/civic/contact-suggestions/{sid}/review",
                    json={"accept": False, "note": "That is the old number"},
                    headers=_headers(organiser, club))
    assert r.json()["status"] == "REJECTED"
    db.refresh(blank_office)
    assert not (blank_office.phone or "").strip()


def test_an_empty_suggestion_is_refused(client, db, club, member, blank_office):
    r = client.post(_url(blank_office), json={"how_they_know": "I just know"},
                    headers=_headers(member, club))
    assert r.status_code == 422


def test_reviewing_twice_is_refused(
    client, db, club, member, organiser, blank_office
):
    sid = client.post(_url(blank_office), json={"phone": "9443132365"},
                      headers=_headers(member, club)).json()["id"]
    hdrs = _headers(organiser, club)
    client.post(f"/api/v1/civic/contact-suggestions/{sid}/review",
                json={"accept": True}, headers=hdrs)
    r = client.post(f"/api/v1/civic/contact-suggestions/{sid}/review",
                    json={"accept": False}, headers=hdrs)
    assert r.status_code == 409


def test_only_organisers_see_the_queue(client, db, club, member, organiser):
    assert client.get("/api/v1/civic/contact-suggestions",
                      headers=_headers(member, club)).status_code == 403
    assert client.get("/api/v1/civic/contact-suggestions",
                      headers=_headers(organiser, club)).status_code == 200
