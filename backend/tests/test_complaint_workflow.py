"""A complaint from a photograph to an officer, and up the ladder when nobody
replies.

The system this replaces could do exactly one of these steps: it emailed one
address once. These tests walk the whole journey — reviewed, sent, waited on,
escalated — and hold the two rules the design turns on: a person always presses
send, and the club reads it first.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.models.civic import Authority, Department, IssueEscalation
from app.models.geography import GeographicNode, GeoLevel
from app.models.civic import LocalBodyType
from app.models.issue import IssueStatus, PublicIssue
from app.models.tenant import Organization
from app.models.user import User
from app.services import complaint_workflow as workflow
from app.services.issue_lifecycle import IllegalTransition, can, check
from seeds.civic_directory import seed


@pytest.fixture
def club(db):
    org = Organization(
        id=uuid.uuid4(), slug="wf-club", name_en="Friends Youth Club", name_ta="கழகம்"
    )
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


@pytest.fixture
def reviewer(db, club):
    u = User(
        id=uuid.uuid4(), organization_id=club.id, phone_number="+919000000001",
        email="reviewer@example.invalid", password_hash="x", role="EXECUTIVE_MEMBER",
        is_verified=True,
    )
    db.add(u)
    db.commit()
    return u


@pytest.fixture
def town(db):
    n = GeographicNode(
        id=uuid.uuid4(), level=GeoLevel.VILLAGE, name_en="Nagercoil", name_ta="நாகர்கோவில்",
        local_body_type=LocalBodyType.CORPORATION.value,
    )
    db.add(n)
    db.commit()
    return n


def _issue(db, club, reporter, town, category="GARBAGE"):
    i = PublicIssue(
        organization_id=club.id, reported_by_user_id=reporter.id, category=category,
        description_ta="குப்பை", description_en="Rubbish piled at the corner",
        latitude=8.178, longitude=77.434, geography_id=town.id,
        status=IssueStatus.NEW,
    )
    db.add(i)
    db.commit()
    return i


def _fill_in(db, club, code, designation, email):
    """What the club does by hand: record an office's address, with a source."""
    dept = db.query(Department).filter(
        Department.organization_id == club.id, Department.code == code
    ).one()
    a = db.query(Authority).filter(
        Authority.department_id == dept.id, Authority.designation_en == designation
    ).first()
    a.email = email
    a.source_url = "https://kanniyakumari.nic.in/"
    a.verified_at = datetime.now(timezone.utc)
    db.commit()
    return a


@pytest.fixture
def sent_mail(monkeypatch):
    """Capture outgoing mail instead of sending it."""
    outbox = []

    def fake_send(to, subject, body, body_html=None, cc=None, reply_to=None):
        outbox.append({"to": to, "subject": subject, "body": body, "cc": list(cc or [])})
        return True

    monkeypatch.setattr(workflow.mailer, "send_email", fake_send)
    return outbox


# ── The gate ─────────────────────────────────────────────────────────────────

def test_a_report_cannot_be_sent_before_a_human_reads_it(db, club, reviewer, town, sent_mail):
    issue = _issue(db, club, reviewer, town)

    with pytest.raises(workflow.NotReady):
        workflow.dispatch(db, issue, reviewer, club_name="FYC")

    assert sent_mail == []
    assert issue.status == IssueStatus.NEW


def test_approving_records_who_and_does_not_send(db, club, reviewer, town, sent_mail):
    issue = _issue(db, club, reviewer, town)

    workflow.approve(db, issue, reviewer, "looks genuine")
    db.commit()

    assert issue.status == IssueStatus.ASSIGNED
    assert issue.reviewed_by_user_id == reviewer.id
    assert issue.reviewed_at is not None
    # Approving opens the door and stops, so the letter can be read first.
    assert sent_mail == []


def test_rejecting_without_a_reason_is_refused(db, club, reviewer, town):
    """A rejection with no reason teaches the reporter only that reporting is
    pointless, and they are the club's supply of reports."""
    issue = _issue(db, club, reviewer, town)

    with pytest.raises(workflow.NotReady):
        workflow.reject(db, issue, reviewer, "   ")

    assert issue.status == IssueStatus.NEW


def test_a_rejection_reason_reaches_the_reporter(db, club, reviewer, town):
    issue = _issue(db, club, reviewer, town)

    workflow.reject(db, issue, reviewer, "Already reported last week — see #41")
    db.commit()

    assert issue.status == IssueStatus.REJECTED
    assert "Already reported" in issue.review_note


# ── The ladder in motion ─────────────────────────────────────────────────────

def test_the_first_letter_goes_to_the_lowest_office_we_can_reach(
    db, club, reviewer, town, sent_mail
):
    _fill_in(db, club, "ULB_HEALTH", "Sanitary Inspector", "si@example.invalid")
    _fill_in(db, club, "COLLECTORATE", "District Collector", "collector@example.invalid")
    issue = _issue(db, club, reviewer, town)
    workflow.approve(db, issue, reviewer)
    db.commit()

    result = workflow.dispatch(db, issue, reviewer, club_name="Friends Youth Club")
    db.commit()

    assert result.sent
    assert sent_mail[0]["to"] == "si@example.invalid"
    assert issue.status == IssueStatus.UNDER_REVIEW
    # And a clock started, without anything being scheduled to fire.
    assert issue.next_action_due_at is not None


def test_escalation_climbs_and_never_repeats_a_rung(
    db, club, reviewer, town, sent_mail
):
    _fill_in(db, club, "ULB_HEALTH", "Sanitary Inspector", "si@example.invalid")
    _fill_in(db, club, "ULB_HEALTH", "City Health Officer", "cho@example.invalid")
    _fill_in(db, club, "COLLECTORATE", "District Collector", "collector@example.invalid")
    issue = _issue(db, club, reviewer, town)
    workflow.approve(db, issue, reviewer)
    db.commit()

    for _ in range(3):
        workflow.dispatch(db, issue, reviewer, club_name="FYC")
        db.commit()

    recipients = [m["to"] for m in sent_mail]
    assert recipients == ["si@example.invalid", "cho@example.invalid", "collector@example.invalid"]
    assert issue.status == IssueStatus.ESCALATED
    positions = [e.position for e in workflow.history(db, issue)]
    assert positions == sorted(set(positions)), "a rung was written twice"


def test_a_ladder_that_runs_out_offers_a_number_to_ring(
    db, club, reviewer, town, sent_mail
):
    """The old code returned needs_manual and logged the recipient as the string
    "not-configured". A citizen should get a phone number instead."""
    issue = _issue(db, club, reviewer, town)
    workflow.approve(db, issue, reviewer)
    db.commit()

    result = workflow.dispatch(db, issue, reviewer, club_name="FYC")
    db.commit()

    assert not result.sent
    assert sent_mail == []
    assert result.fallback_portal or result.fallback_helpline
    # Nothing moved: the complaint is still ours to deal with.
    assert issue.status == IssueStatus.ASSIGNED


def test_the_letter_carries_what_an_officer_needs(db, club, reviewer, town, sent_mail):
    _fill_in(db, club, "ULB_HEALTH", "Sanitary Inspector", "si@example.invalid")
    issue = _issue(db, club, reviewer, town)
    issue.location_name = "Balamore Road, Nagercoil"
    workflow.approve(db, issue, reviewer)
    db.commit()

    workflow.dispatch(db, issue, reviewer, club_name="Friends Youth Club")
    db.commit()

    body = sent_mail[0]["body"]
    assert "Balamore Road" in body
    assert "maps.google.com" in body
    assert str(issue.id) in body, "no reference number to quote on a phone call"
    assert "Friends Youth Club" in body
    assert "Sanitary Inspector" in sent_mail[0]["subject"] or "Sanitary Inspector" in body


def test_a_highway_can_be_pinned_away_from_the_local_body(
    db, club, reviewer, town, sent_mail
):
    """Road class cannot be derived from a coordinate — a reviewer who
    recognises the road switches the route."""
    _fill_in(db, club, "ULB_ENGINEERING", "Assistant Engineer", "ae@example.invalid")
    _fill_in(db, club, "HIGHWAYS", "Divisional Engineer", "de@example.invalid")
    issue = _issue(db, club, reviewer, town, category="ROAD")
    issue.department_code_override = "HIGHWAYS"
    workflow.approve(db, issue, reviewer)
    db.commit()

    workflow.dispatch(db, issue, reviewer, club_name="FYC")
    db.commit()

    assert sent_mail[0]["to"] == "de@example.invalid"


# ── The clock ────────────────────────────────────────────────────────────────

def test_the_clock_reports_and_does_not_send(db, club, reviewer, town, sent_mail):
    """The rule the whole design turns on: a machine that mails a District
    Collector unattended will one day mail one about a duplicate puddle."""
    _fill_in(db, club, "ULB_HEALTH", "Sanitary Inspector", "si@example.invalid")
    issue = _issue(db, club, reviewer, town)
    workflow.approve(db, issue, reviewer)
    db.commit()
    workflow.dispatch(db, issue, reviewer, club_name="FYC")
    db.commit()
    before = len(sent_mail)

    issue.next_action_due_at = datetime.now(timezone.utc) - timedelta(days=1)
    db.commit()
    due = workflow.next_due(db, club.id)

    assert [i.id for i in due] == [issue.id]
    assert len(sent_mail) == before, "the clock sent something by itself"


def test_a_complaint_still_in_hand_is_not_reported_as_overdue(db, club, reviewer, town):
    _fill_in(db, club, "ULB_HEALTH", "Sanitary Inspector", "si@example.invalid")
    issue = _issue(db, club, reviewer, town)
    workflow.approve(db, issue, reviewer)
    db.commit()

    assert workflow.next_due(db, club.id) == []


# ── The state machine that was deleted ───────────────────────────────────────

def test_a_resolved_complaint_cannot_quietly_become_new_again():
    assert not can(IssueStatus.RESOLVED, IssueStatus.NEW)
    with pytest.raises(IllegalTransition):
        check(IssueStatus.RESOLVED, IssueStatus.NEW)


def test_a_fix_that_did_not_hold_can_be_reopened():
    """The flexibility the old comment wanted, kept — without letting any state
    become any other."""
    assert can(IssueStatus.RESOLVED, IssueStatus.ASSIGNED)
    assert can(IssueStatus.REJECTED, IssueStatus.ASSIGNED)


def test_staying_put_is_never_an_error():
    assert can(IssueStatus.NEW, IssueStatus.NEW)


def test_a_pinned_department_still_escalates_to_the_district(
    db, club, reviewer, town, sent_mail
):
    """Substituting the department replaces the local body, not the whole
    ladder — a highway complaint must still be able to reach the Collector."""
    _fill_in(db, club, "HIGHWAYS", "Assistant Divisional Engineer", "ade@example.invalid")
    _fill_in(db, club, "HIGHWAYS", "Divisional Engineer", "de@example.invalid")
    _fill_in(db, club, "COLLECTORATE", "District Collector", "collector@example.invalid")
    issue = _issue(db, club, reviewer, town, category="ROAD")
    issue.department_code_override = "HIGHWAYS"
    workflow.approve(db, issue, reviewer)
    db.commit()

    for _ in range(3):
        workflow.dispatch(db, issue, reviewer, club_name="FYC")
        db.commit()

    assert [m["to"] for m in sent_mail] == [
        "ade@example.invalid", "de@example.invalid", "collector@example.invalid",
    ]


def test_pinning_a_department_nobody_has_offices_for_falls_back_safely(
    db, club, reviewer, town, sent_mail
):
    """NHAI has one seeded office and no contact. Pinning to it must not strand
    the complaint with nowhere at all to go."""
    _fill_in(db, club, "ULB_ENGINEERING", "Assistant Engineer", "ae@example.invalid")
    issue = _issue(db, club, reviewer, town, category="ROAD")
    issue.department_code_override = "NO_SUCH_DEPARTMENT"
    workflow.approve(db, issue, reviewer)
    db.commit()

    result = workflow.dispatch(db, issue, reviewer, club_name="FYC")
    db.commit()

    assert result.sent, "an unknown override should fall back to the normal ladder"
    assert sent_mail[0]["to"] == "ae@example.invalid"
