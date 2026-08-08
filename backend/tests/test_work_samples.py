"""The example listings, and the promise attached to them.

Seeding is how an index avoids being empty on day one — somebody who opens a
category and finds nothing concludes the whole app is empty. But India reserves
no fictional telephone range, so any number invented here could be somebody's,
and an index that looked fuller by putting a stranger's phone in front of
members would be worse than an empty one.
"""
import uuid

import pytest

from app.models.tenant import Organization
from app.models.user import User
from app.models.work import Listing
from seeds.work_samples import SAMPLE_PHONE, remove, seed


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="sample-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    return org


@pytest.fixture
def owner(db, club):
    u = User(id=uuid.uuid4(), organization_id=club.id,
             phone_number="+919000000071", email="o@example.invalid",
             password_hash="x", role="USER", is_verified=True)
    db.add(u)
    db.commit()
    return u


def test_seeding_fills_several_categories(db, club, owner):
    """One category with fourteen people in it still looks like an empty app
    the moment somebody taps a different one."""
    assert seed(db, club.id, owner.id) >= 10
    cats = {c for (c,) in db.query(Listing.category).filter(
        Listing.organization_id == club.id)}
    assert len(cats) >= 8


def test_every_sample_is_flagged_as_one(db, club, owner):
    seed(db, club.id, owner.id)
    rows = db.query(Listing).filter(Listing.organization_id == club.id).all()
    assert rows and all(r.is_sample for r in rows)


def test_no_sample_can_reach_a_real_person(db, club, owner):
    """The promise. Any ten-digit number invented here could be somebody's."""
    seed(db, club.id, owner.id)
    for r in db.query(Listing).filter(Listing.organization_id == club.id):
        assert r.phone == SAMPLE_PHONE
        assert set(r.phone) == {"0"}


def test_every_sample_says_it_is_one_in_its_own_words(db, club, owner):
    seed(db, club.id, owner.id)
    for r in db.query(Listing).filter(Listing.organization_id == club.id):
        assert "not a real person" in (r.about or "").lower()


def test_seeding_twice_adds_nothing(db, club, owner):
    first = seed(db, club.id, owner.id)
    assert seed(db, club.id, owner.id) == 0
    assert db.query(Listing).filter(
        Listing.organization_id == club.id).count() == first


def test_samples_can_be_taken_out_again(db, club, owner):
    """The honest version of this feature has no samples in it at all."""
    seed(db, club.id, owner.id)
    assert remove(db, club.id) > 0
    assert db.query(Listing).filter(
        Listing.organization_id == club.id).count() == 0


def test_removing_leaves_real_listings_alone(db, club, owner):
    seed(db, club.id, owner.id)
    db.add(Listing(
        id=uuid.uuid4(), organization_id=club.id, owner_user_id=owner.id,
        kind="PERSON", display_name="A real member", category="CARPENTRY",
        phone="9443132365", is_sample=False,
    ))
    db.commit()

    remove(db, club.id)
    left = db.query(Listing).filter(Listing.organization_id == club.id).all()
    assert [l.display_name for l in left] == ["A real member"]
