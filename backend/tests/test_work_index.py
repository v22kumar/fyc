"""The local work index.

What these hold to account is the set of decisions that make this a directory
rather than a marketplace: nothing is a rating, nothing needs approval to
appear, and the report rule has to protect people without waiting for an
organiser to be awake.
"""
import uuid

import pytest

from app.core.security import create_access_token
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.models.work import Listing, ListingReport, ReportStatus, WorkRecord


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="work-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    return org


def _user(db, club, role="USER", phone="+919000000051", name="Murugan A."):
    u = User(id=uuid.uuid4(), organization_id=club.id, phone_number=phone,
             email=f"{phone}@example.invalid", password_hash="x", role=role,
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.commit()
    return u


def _h(u, club):
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


@pytest.fixture
def carpenter(db, club):
    return _user(db, club)


@pytest.fixture
def neighbour(db, club):
    return _user(db, club, phone="+919000000052", name="Selvi R.")


@pytest.fixture
def organiser(db, club):
    return _user(db, club, role="EXECUTIVE_MEMBER", phone="+919000000053",
                 name="Organiser")


def _list(client, u, club, **kw):
    body = {"display_name": "Murugan A.", "category": "CARPENTRY",
            "about": "interlock brick work, doors", "area": "Vadasery",
            "phone": "9443132365"}
    body.update(kw)
    return client.post("/api/v1/work/listings", json=body, headers=_h(u, club))


# ── Appearing, without asking permission ─────────────────────────────────────

def test_anybody_can_list_without_approval(client, db, club, carpenter):
    r = _list(client, carpenter, club)
    assert r.status_code == 201, r.text
    # No approval flag, no pending state — it is live.
    assert client.get("/api/v1/work/listings?category=CARPENTRY",
                      headers=_h(carpenter, club)).json()


def test_free_text_finds_what_a_category_never_could(
    client, db, club, carpenter
):
    """"interlock brick" is never going to be a category and is exactly what
    somebody types."""
    _list(client, carpenter, club)
    found = client.get("/api/v1/work/listings?q=interlock",
                       headers=_h(carpenter, club)).json()
    assert len(found) == 1


def test_empty_categories_are_not_offered(client, db, club, carpenter):
    """A tile reading "Plumbing 0" advertises that the app does not work."""
    _list(client, carpenter, club)
    codes = {c["code"] for c in
             client.get("/api/v1/work/categories", headers=_h(carpenter, club)).json()}
    assert codes == {"CARPENTRY"}
    assert "PLUMBING" not in codes


# ── Trust is facts, never a score ────────────────────────────────────────────

def test_a_new_listing_says_it_is_new(client, db, club, carpenter):
    body = _list(client, carpenter, club).json()
    assert body["trust"]["is_new"] is True
    assert body["trust"]["jobs_confirmed"] == 0
    assert "rating" not in body["trust"]


def test_an_unconfirmed_job_is_not_counted(
    client, db, club, carpenter, neighbour
):
    """A self-reported total is the same claim as before, wearing a number."""
    lid = _list(client, carpenter, club).json()["id"]
    # The owner records their own job: nobody has vouched for it.
    client.post(f"/api/v1/work/listings/{lid}/records",
                json={"what": "Fitted a door"}, headers=_h(carpenter, club))

    got = client.get(f"/api/v1/work/listings/{lid}", headers=_h(neighbour, club))
    assert got.json()["trust"]["jobs_confirmed"] == 0


def test_a_job_the_client_records_counts_immediately(
    client, db, club, carpenter, neighbour
):
    lid = _list(client, carpenter, club).json()["id"]
    client.post(f"/api/v1/work/listings/{lid}/records",
                json={"what": "Fitted a door"}, headers=_h(neighbour, club))

    got = client.get(f"/api/v1/work/listings/{lid}", headers=_h(neighbour, club))
    assert got.json()["trust"]["jobs_confirmed"] == 1
    assert got.json()["trust"]["is_new"] is False


def test_only_the_client_can_confirm(client, db, club, carpenter, neighbour):
    """The value of the record is that somebody other than the person it
    flatters put their name to it."""
    lid = _list(client, carpenter, club).json()["id"]
    rid = client.post(f"/api/v1/work/listings/{lid}/records",
                      json={"what": "Fitted a door",
                            "client_user_id": str(neighbour.id)},
                      headers=_h(carpenter, club)).json()["id"]

    assert client.post(f"/api/v1/work/records/{rid}/confirm",
                       headers=_h(carpenter, club)).status_code == 403
    assert client.post(f"/api/v1/work/records/{rid}/confirm",
                       headers=_h(neighbour, club)).status_code == 200


# ── The report rule, which is the whole safety mechanism ─────────────────────

def test_one_upheld_report_does_not_hide_a_listing(
    client, db, club, carpenter, neighbour, organiser
):
    """An angry customer must not be able to remove a competitor."""
    lid = _list(client, carpenter, club).json()["id"]
    client.post(f"/api/v1/work/listings/{lid}/report",
                json={"reason": "TOOK_MONEY"}, headers=_h(neighbour, club))
    rid = client.get("/api/v1/work/reports", headers=_h(organiser, club)).json()[0]["id"]
    client.post(f"/api/v1/work/reports/{rid}/review",
                json={"uphold": True}, headers=_h(organiser, club))

    assert client.get(f"/api/v1/work/listings/{lid}",
                      headers=_h(neighbour, club)).status_code == 200


def test_two_upheld_reports_hide_it_without_anybody_deciding_to(
    client, db, club, carpenter, neighbour, organiser
):
    """A rule that waits for somebody to be free does not work at 9pm on a
    Sunday, which is when it matters."""
    lid = _list(client, carpenter, club).json()["id"]
    third = _user(db, club, phone="+919000000054", name="Ravi")

    for who in (neighbour, third):
        client.post(f"/api/v1/work/listings/{lid}/report",
                    json={"reason": "TOOK_MONEY"}, headers=_h(who, club))
    for rep in client.get("/api/v1/work/reports", headers=_h(organiser, club)).json():
        client.post(f"/api/v1/work/reports/{rep['id']}/review",
                    json={"uphold": True}, headers=_h(organiser, club))

    assert client.get(f"/api/v1/work/listings/{lid}",
                      headers=_h(neighbour, club)).status_code == 404
    assert client.get("/api/v1/work/listings?category=CARPENTRY",
                      headers=_h(neighbour, club)).json() == []


def test_dismissed_reports_never_hide_anything(
    client, db, club, carpenter, neighbour, organiser
):
    lid = _list(client, carpenter, club).json()["id"]
    third = _user(db, club, phone="+919000000055", name="Ravi")
    for who in (neighbour, third):
        client.post(f"/api/v1/work/listings/{lid}/report",
                    json={"reason": "OTHER"}, headers=_h(who, club))
    for rep in client.get("/api/v1/work/reports", headers=_h(organiser, club)).json():
        client.post(f"/api/v1/work/reports/{rep['id']}/review",
                    json={"uphold": False}, headers=_h(organiser, club))

    assert client.get(f"/api/v1/work/listings/{lid}",
                      headers=_h(neighbour, club)).status_code == 200


def test_a_member_cannot_review_reports(client, db, club, carpenter, neighbour):
    lid = _list(client, carpenter, club).json()["id"]
    client.post(f"/api/v1/work/listings/{lid}/report",
                json={"reason": "OTHER"}, headers=_h(neighbour, club))
    assert client.get("/api/v1/work/reports",
                      headers=_h(neighbour, club)).status_code == 403


# ── What a searcher sees first ───────────────────────────────────────────────

def test_proven_work_comes_above_a_newer_listing(
    client, db, club, carpenter, neighbour
):
    """Ordering by recency alone puts the least proven option at the top.

    A listing created five minutes ago outranking somebody with nine confirmed
    jobs is the opposite of what the trust line exists to communicate.
    """
    proven = _list(client, carpenter, club, display_name="Murugan A.").json()["id"]
    client.post(f"/api/v1/work/listings/{proven}/records",
                json={"what": "Fitted a door"}, headers=_h(neighbour, club))

    # Created afterwards, so recency alone would put it first.
    newcomer = _user(db, club, phone="+919000000061", name="Newcomer")
    _list(client, newcomer, club, display_name="Brand New")

    names = [r["display_name"] for r in
             client.get("/api/v1/work/listings?category=CARPENTRY",
                        headers=_h(neighbour, club)).json()]
    assert names == ["Murugan A.", "Brand New"]


def test_a_new_listing_is_still_on_the_same_screen(
    client, db, club, carpenter, neighbour
):
    """The other trap.

    Sorting purely by confirmed jobs means nobody new is seen, so nobody new is
    hired, so nobody new accumulates jobs — and the index never bootstraps.
    Grouping rather than ranking keeps them visible.
    """
    proven = _list(client, carpenter, club, display_name="Murugan A.").json()["id"]
    client.post(f"/api/v1/work/listings/{proven}/records",
                json={"what": "Fitted a door"}, headers=_h(neighbour, club))
    newcomer = _user(db, club, phone="+919000000062", name="Newcomer")
    _list(client, newcomer, club, display_name="Brand New")

    rows = client.get("/api/v1/work/listings?category=CARPENTRY",
                      headers=_h(neighbour, club)).json()
    assert any(r["display_name"] == "Brand New" for r in rows)


# ── The owner's side ─────────────────────────────────────────────────────────

def test_views_are_counted_so_the_owner_sees_something_happened(
    client, db, club, carpenter, neighbour
):
    """Somebody who listed once and heard nothing decides it did not work."""
    lid = _list(client, carpenter, club).json()["id"]
    client.post(f"/api/v1/work/listings/{lid}/view", headers=_h(neighbour, club))
    client.post(f"/api/v1/work/listings/{lid}/view", headers=_h(neighbour, club))

    mine = client.get("/api/v1/work/my", headers=_h(carpenter, club)).json()
    assert mine[0]["view_count"] == 2


def test_somebody_else_cannot_edit_my_listing(
    client, db, club, carpenter, neighbour
):
    lid = _list(client, carpenter, club).json()["id"]
    r = client.patch(f"/api/v1/work/listings/{lid}",
                     json={"display_name": "Not me", "category": "CARPENTRY",
                           "phone": "9000000000"},
                     headers=_h(neighbour, club))
    assert r.status_code == 404


def test_an_unknown_category_is_refused(client, db, club, carpenter):
    assert _list(client, carpenter, club,
                 category="REACT_DEVELOPER").status_code == 422
