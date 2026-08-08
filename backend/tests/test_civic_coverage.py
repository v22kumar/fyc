"""Whether the club's directory speaks for a place at all.

A member in Bengaluru reporting a pothole was routed to an Assistant Engineer
in Nagercoil, six hundred kilometres away, who would have had no idea what he
was being written to about. The system had no concept of being outside its own
area: an unknown location fell back to a guessed default, and the guess was
always Kanniyakumari.
"""
import uuid

import pytest

from app.core.security import create_access_token
from app.models.tenant import Organization
from app.models.user import User
from app.services.jurisdiction import is_covered
from seeds.civic_directory import seed


class TestCoverage:
    def test_nagercoil_is_covered(self):
        assert is_covered(8.1833, 77.4119)

    def test_bengaluru_is_not(self):
        assert not is_covered(12.9716, 77.5946)

    def test_chennai_is_not(self):
        # Same state, still not this club's district.
        assert not is_covered(13.0827, 80.2707)

    def test_an_unknown_location_is_not_assumed_to_be_local(self):
        # This is the whole bug: absence of a location used to mean
        # Kanniyakumari.
        assert not is_covered(None, None)

    def test_rubbish_coordinates_do_not_crash(self):
        assert not is_covered("north", "west")


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="cov-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


@pytest.fixture
def member(db, club):
    u = User(id=uuid.uuid4(), organization_id=club.id,
             phone_number="+919000000081", email="m@example.invalid",
             password_hash="x", role="USER", is_verified=True)
    db.add(u)
    db.commit()
    return u


def _h(u, club):
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


def test_a_complaint_from_outside_the_district_gets_no_offices(
    client, db, club, member
):
    r = client.get(
        "/api/v1/civic/ladder?category=STREET_LIGHT"
        "&latitude=12.9716&longitude=77.5946",
        headers=_h(member, club))
    body = r.json()
    assert body["covered"] is False
    assert body["rungs"] == [], (
        "an office six hundred kilometres from the problem is worse than no "
        "office"
    )


def test_a_complaint_from_inside_the_district_still_routes(
    client, db, club, member
):
    body = client.get(
        "/api/v1/civic/ladder?category=STREET_LIGHT"
        "&latitude=8.1833&longitude=77.4119",
        headers=_h(member, club)).json()
    assert body["covered"] is True
    assert body["rungs"], "Nagercoil must still reach Nagercoil"


def test_no_coordinates_behaves_as_before(client, db, club, member):
    # Older callers pass no location at all. They keep the previous behaviour
    # rather than silently losing their ladder.
    body = client.get("/api/v1/civic/ladder?category=STREET_LIGHT",
                      headers=_h(member, club)).json()
    assert body["covered"] is True
    assert body["rungs"]
