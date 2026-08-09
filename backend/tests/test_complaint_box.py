"""The Complaint Box.

What these hold to account is one idea: **the server never says something
nobody said.** In Lane A the member sends from their own mail, so nothing here
can observe whether the letter went or whether anyone replied. Every statement
carries its author, and a status the app invented is the bug these exist to
prevent — because it would be wrong on screen in front of somebody standing at
a government counter.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.core.security import create_access_token
from app.models.civic import Authority, Department
from app.models.issue import (
    ComplaintAuthor, ComplaintEvent, ComplaintEventType, IssueStatus, PublicIssue,
)
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from seeds.civic_directory import seed


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="cb-club", name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


@pytest.fixture
def member(db, club):
    u = User(id=uuid.uuid4(), organization_id=club.id, phone_number="+919000000031",
             email="m@example.invalid", password_hash="x", role="USER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="Arun Kumar", full_name_ta="அருண்"))
    db.commit()
    return u


@pytest.fixture
def auth(member, club):
    return {
        "Authorization": f"Bearer {create_access_token(str(member.id), member.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }


@pytest.fixture
def complaint(db, club, member):
    issue = PublicIssue(
        id=uuid.uuid4(), organization_id=club.id, reported_by_user_id=member.id,
        category="STREET_LIGHT",
        description_en="The street light opposite the bus stand has been dead for weeks.",
        description_ta="பேருந்து நிலைய விளக்கு பல வாரங்களாக எரியவில்லை.",
        latitude=8.1833, longitude=77.4119, location_name="Vadasery bus stand",
        status=IssueStatus.NEW, lane="SELF", severity="ROUTINE",
    )
    db.add(issue)
    db.commit()
    return issue


def _url(c, suffix=""):
    return f"/api/v1/civic/complaints/{c.id}{suffix}"


# ── Nothing is asserted that nobody said ─────────────────────────────────────

def test_a_fresh_complaint_claims_nothing(client, db, complaint, auth):
    body = client.get(_url(complaint), headers=auth).json()
    assert body["events"] == []
    assert body["waiting_days"] is None, (
        "a report nobody has acted on is not waiting for a reply, and saying so "
        "would start an escalation clock against nothing"
    )
    assert body["is_closed"] is False


def test_every_event_names_who_said_it(client, db, complaint, auth):
    client.post(_url(complaint, "/calls"), json={"outcome": "PROMISED",
                "authority_label": "Assistant Engineer, Corporation"}, headers=auth)
    body = client.get(_url(complaint), headers=auth).json()
    assert body["events"][0]["author"] == ComplaintAuthor.MEMBER.value
    assert body["events"][0]["author_name"] == "Arun Kumar"


def test_the_app_never_marks_a_letter_sent_by_itself(client, db, complaint, auth):
    """Drafting is not sending. The draft goes to another application and this
    one genuinely does not know what happened next."""
    client.post(_url(complaint, "/draft"), json={"use_ai": False}, headers=auth)
    body = client.get(_url(complaint), headers=auth).json()
    types = [e["event_type"] for e in body["events"]]
    assert ComplaintEventType.DRAFTED.value in types
    assert ComplaintEventType.SENT.value not in types


# ── Waiting is a real state with a real name ─────────────────────────────────

def test_waiting_is_counted_from_the_last_thing_that_left(client, db, complaint, auth):
    client.post(_url(complaint, "/sent"), json={}, headers=auth)
    ev = (db.query(ComplaintEvent)
            .filter(ComplaintEvent.issue_id == complaint.id).first())
    ev.created_at = datetime.now(timezone.utc) - timedelta(days=12)
    db.commit()

    body = client.get(_url(complaint), headers=auth).json()
    assert body["waiting_days"] == 12


# ── Ending it ────────────────────────────────────────────────────────────────

def test_a_member_can_close_it_whatever_we_know(client, db, complaint, auth):
    """Somebody who fixed it by walking into the office must be able to say so."""
    body = client.post(_url(complaint, "/close"),
                       json={"resolved": True, "reason": "Fixed after I visited"},
                       headers=auth).json()
    assert body["is_closed"] is True
    assert body["closed_reason"] == "Fixed after I visited"


def test_giving_up_is_a_legitimate_ending(client, db, complaint, auth):
    body = client.post(_url(complaint, "/close"),
                       json={"resolved": False, "reason": "I gave up"},
                       headers=auth).json()
    assert body["is_closed"] is True
    assert body["status"] == IssueStatus.CLOSED.value


def test_a_closed_complaint_stops_accepting_events(client, db, complaint, auth):
    """Not pedantry: an ended complaint that keeps accepting events keeps
    nudging somebody who has already said they are done."""
    client.post(_url(complaint, "/close"), json={"resolved": True}, headers=auth)
    r = client.post(_url(complaint, "/calls"), json={"outcome": "REACHED"}, headers=auth)
    assert r.status_code == 409


def test_reopening_takes_one_call(client, db, complaint, auth):
    client.post(_url(complaint, "/close"), json={"resolved": True}, headers=auth)
    body = client.post(_url(complaint, "/reopen"), headers=auth).json()
    assert body["is_closed"] is False
    assert client.post(_url(complaint, "/calls"), json={"outcome": "REACHED"},
                       headers=auth).status_code == 200


# ── The letter ───────────────────────────────────────────────────────────────

def test_the_letter_carries_a_map_link_not_coordinates(client, db, complaint, auth):
    body = client.post(_url(complaint, "/draft"), json={"use_ai": False},
                       headers=auth).json()
    assert "google.com/maps" in body["body"]
    assert "GPS 8.1833" not in body["body"]


def test_the_letter_is_the_members_and_does_not_sign_off_as_the_club(
    client, db, complaint, auth
):
    body = client.post(_url(complaint, "/draft"), json={"use_ai": False},
                       headers=auth).json()
    assert "Arun Kumar" in body["body"]
    assert "FYC Connect" not in body["body"], (
        "in Lane A the club did not write this and did not send it"
    )


def test_a_logged_call_becomes_the_opening_of_the_letter(client, db, complaint, auth):
    """The sentence that makes a letter land with a supervisor, bought with one
    tap after a phone call."""
    client.post(_url(complaint, "/calls"),
                json={"outcome": "PROMISED",
                      "authority_label": "Assistant Engineer, Corporation"},
                headers=auth)
    body = client.post(_url(complaint, "/draft"), json={"use_ai": False},
                       headers=auth).json()
    assert "Assistant Engineer" in body["body"]
    assert "no action since" in body["body"]


def test_the_letter_still_works_when_the_model_is_unavailable(
    client, db, complaint, auth
):
    """The reason the skeleton is code: a model that is down must not stop
    somebody complaining about a broken drain."""
    body = client.post(_url(complaint, "/draft"), json={"use_ai": True},
                       headers=auth).json()
    assert body["subject"]
    assert complaint.description_en[:20] in body["body"] or body["ai_written"]


# ── The blind copy ───────────────────────────────────────────────────────────

def test_turning_the_copy_off_means_no_copy(client, db, complaint, auth):
    body = client.post(_url(complaint, "/draft"),
                       json={"use_ai": False, "bcc_club": False}, headers=auth).json()
    assert body["bcc"] == []


# ── Whose complaint it is ────────────────────────────────────────────────────

def test_somebody_elses_complaint_is_not_readable(client, db, club, complaint):
    other = User(id=uuid.uuid4(), organization_id=club.id,
                 phone_number="+919000000032", email="o@example.invalid",
                 password_hash="x", role="USER", is_verified=True)
    db.add(other)
    db.commit()
    headers = {
        "Authorization": f"Bearer {create_access_token(str(other.id), other.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }
    assert client.get(_url(complaint), headers=headers).status_code == 403


def test_handing_it_to_the_club_changes_lane(client, db, complaint, auth):
    body = client.post(_url(complaint, "/handover"), headers=auth).json()
    assert body["lane"] == "VIA_CLUB"


# ── The list a member actually opens ─────────────────────────────────────────

def test_my_complaints_says_how_long_each_has_been_waiting(
    client, db, complaint, auth
):
    """The old tracking screen showed a status column the server maintained by
    guessing. This shows what somebody said, and how long since anything left."""
    client.post(_url(complaint, "/sent"), json={}, headers=auth)
    ev = (db.query(ComplaintEvent)
            .filter(ComplaintEvent.issue_id == complaint.id).first())
    ev.created_at = datetime.now(timezone.utc) - timedelta(days=9)
    db.commit()

    rows = client.get("/api/v1/civic/complaints", headers=auth).json()
    assert len(rows) == 1
    assert rows[0]["waiting_days"] == 9
    assert rows[0]["last_event"] == "SENT"


def test_a_report_nobody_has_acted_on_is_not_waiting(client, db, complaint, auth):
    # Not the same as nothing being known — and starting a clock against a
    # complaint that was never sent would nag somebody for no reason.
    rows = client.get("/api/v1/civic/complaints", headers=auth).json()
    assert rows[0]["waiting_days"] is None


def test_open_complaints_come_before_closed_ones(
    client, db, club, member, complaint, auth
):
    """A list that hides closed ones looks like work disappeared; a list that
    mixes them in is mostly dead rows. So they sort last."""
    still_open = PublicIssue(
        id=uuid.uuid4(), organization_id=club.id, reported_by_user_id=member.id,
        category="WATER", description_en="Still broken",
        description_ta="இன்னும் சரியாகவில்லை",
        latitude=8.18, longitude=77.41, status=IssueStatus.NEW, lane="SELF",
    )
    db.add(still_open)
    db.commit()

    # Close the one the fixture made, leaving the other open.
    client.post(_url(complaint, "/close"), json={"resolved": True}, headers=auth)

    rows = client.get("/api/v1/civic/complaints", headers=auth).json()
    assert len(rows) == 2
    assert rows[0]["is_closed"] is False
    assert rows[-1]["is_closed"] is True


def test_somebody_elses_complaints_are_not_listed(client, db, club, complaint):
    other = User(id=uuid.uuid4(), organization_id=club.id,
                 phone_number="+919000000091", email="x@example.invalid",
                 password_hash="x", role="USER", is_verified=True)
    db.add(other)
    db.commit()
    headers = {
        "Authorization": f"Bearer {create_access_token(str(other.id), other.role, str(club.id))}",
        "X-Organization-ID": str(club.id),
    }
    assert client.get("/api/v1/civic/complaints", headers=headers).json() == []


def test_the_complaint_screen_can_show_what_the_complaint_was_about(
    client, db, complaint, auth
):
    """A ladder of officers with no reminder of which problem this is.

    That is what the detail screen was for anybody carrying more than one
    complaint. The state now carries the member's own words and photograph.
    """
    body = client.get(_url(complaint), headers=auth).json()

    assert body["category"], "the screen has to be able to name and icon itself"
    assert body["description"], "their own words, not a status"
    assert "photo_url" in body and "place_name" in body
