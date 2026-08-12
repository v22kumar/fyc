"""Who may touch the club's money.

These are the tests this module exists for. Cricket answers the equivalent
question with the same four-line comparison copy-pasted at four call sites, and
it works — the risk is the fifth copy, written in a hurry, that forgets. So the
access rule lives in one function and every one of its edges is asserted here,
over HTTP, against a real database.

The club's decisions, restated as tests:

  * executives verify — that is a role, not an appointment
  * a treasurer is appointed to one campaign, and records only
  * a signed-in member with no job sees nothing at all
"""
import uuid

from tests.conftest_finance import (appoint, auth, make_campaign, make_org,
                                    make_user, record)


# ── Nobody by default ───────────────────────────────────────────────────────

def test_an_ordinary_member_cannot_see_a_collection(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    outsider = make_user(db, org, "CLUB_MEMBER", "Nobody")

    r = client.get(f"/api/v1/finance/campaigns/{campaign.id}", headers=auth(outsider))
    assert r.status_code == 403, r.text


def test_an_ordinary_member_cannot_record_money(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    outsider = make_user(db, org, "CLUB_MEMBER", "Nobody")

    assert record(client, campaign, auth(outsider)).status_code == 403


def test_an_ordinary_member_sees_an_empty_list_not_an_error(client, db):
    """Having no job is a normal state, not a failure."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    make_campaign(db, org, admin)
    outsider = make_user(db, org, "CLUB_MEMBER", "Nobody")

    r = client.get("/api/v1/finance/campaigns", headers=auth(outsider))
    assert r.status_code == 200
    assert r.json() == []


def test_signing_in_is_required_at_all(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    r = client.get(f"/api/v1/finance/campaigns/{campaign.id}")
    assert r.status_code in (401, 403)


# ── The treasurer ───────────────────────────────────────────────────────────

def test_an_appointed_treasurer_can_record(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    treasurer = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, treasurer, by=admin)

    r = record(client, campaign, auth(treasurer), amount=3500)
    assert r.status_code == 201, r.text
    assert r.json()["amount_display"] == "₹3,500"


def test_a_treasurer_cannot_verify_their_own_claim(client, db):
    """The whole point of the distinction between recorded and verified."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    treasurer = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, treasurer, by=admin)

    cid = record(client, campaign, auth(treasurer)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/verify", headers=auth(treasurer))
    assert r.status_code == 403


def test_a_treasurer_sees_their_own_collection_not_the_clubs(client, db):
    """A contributor list is a list of who has money and their phone numbers."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000)
    record(client, campaign, auth(suresh), contributor_name="Meena", amount=2000)

    mine = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions",
                      headers=auth(arun)).json()
    assert [c["contributor_name"] for c in mine] == ["Ravi"]

    everything = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions",
                            headers=auth(admin)).json()
    assert {c["contributor_name"] for c in everything} == {"Ravi", "Meena"}


def test_a_treasurer_cannot_open_another_treasurers_row_by_id(client, db):
    """Filtering the list is not enough if the detail endpoint is open."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    theirs = record(client, campaign, auth(suresh), contributor_name="Meena").json()["id"]
    r = client.get(f"/api/v1/finance/contributions/{theirs}", headers=auth(arun))
    assert r.status_code == 404


def test_a_treasurer_cannot_edit_another_treasurers_row(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    theirs = record(client, campaign, auth(suresh)).json()["id"]
    r = client.patch(f"/api/v1/finance/contributions/{theirs}",
                     json={"amount": 99999}, headers=auth(arun))
    assert r.status_code == 403


def test_a_treasurer_cannot_appoint_another_treasurer(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    friend = make_user(db, org, "CLUB_MEMBER", "Friend")

    r = client.post(f"/api/v1/finance/campaigns/{campaign.id}/assignments",
                    json={"user_id": str(friend.id)}, headers=auth(arun))
    assert r.status_code == 403


def test_a_treasurer_cannot_change_the_target(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)

    r = client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                     json={"target_amount": 1}, headers=auth(arun))
    assert r.status_code == 403


def test_a_treasurer_cannot_export_the_ledger(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)

    r = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions.csv",
                   headers=auth(arun))
    assert r.status_code == 403


def test_revoking_a_treasurer_stops_them_recording_but_keeps_what_they_took(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    record(client, campaign, auth(arun), amount=1000)

    r = client.delete(
        f"/api/v1/finance/campaigns/{campaign.id}/assignments/{arun.id}",
        headers=auth(admin))
    assert r.status_code == 200

    assert record(client, campaign, auth(arun)).status_code == 403

    # The money is the club's either way.
    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["collected_paise"] == 100000


# ── The executive ───────────────────────────────────────────────────────────

def test_an_executive_verifies_without_being_appointed(client, db):
    """The club's decision: verification follows the role, not the appointment."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    cid = record(client, campaign, auth(arun)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/verify",
                    headers=auth(exec_member))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "VERIFIED"
    assert body["verified_by_name"] == "Kumar"
    assert body["self_verified"] is False


def test_an_executive_can_record_without_being_appointed(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    assert record(client, campaign, auth(exec_member)).status_code == 201


def test_an_executive_cannot_archive_a_collection(client, db):
    """Archiving is the one that looks irreversible, so it stays with an admin."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    r = client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                     json={"status": "ARCHIVED"}, headers=auth(exec_member))
    assert r.status_code == 403

    ok = client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                      json={"status": "ARCHIVED"}, headers=auth(admin))
    assert ok.status_code == 200


def test_verifying_your_own_entry_is_allowed_but_marked(client, db):
    """A club of five cannot always find two pairs of eyes. Visible, not banned."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)

    cid = record(client, campaign, auth(admin)).json()["id"]
    body = client.post(f"/api/v1/finance/contributions/{cid}/verify",
                       headers=auth(admin)).json()
    assert body["status"] == "VERIFIED"
    assert body["self_verified"] is True

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["self_verified_count"] == 1


# ── Another club's money ────────────────────────────────────────────────────

def test_a_campaign_from_another_club_is_indistinguishable_from_one_that_never_existed(
        client, db):
    """404, never 403 — otherwise the endpoint answers 'does this id exist?'"""
    ours = make_org(db, "ours")
    theirs = make_org(db, "theirs")
    their_admin = make_user(db, theirs, "ADMIN", "Their Admin")
    their_campaign = make_campaign(db, theirs, their_admin)
    our_admin = make_user(db, ours, "SUPER_ADMIN", "Our Admin")

    r = client.get(f"/api/v1/finance/campaigns/{their_campaign.id}",
                   headers=auth(our_admin))
    assert r.status_code == 404

    unknown = client.get(f"/api/v1/finance/campaigns/{uuid.uuid4()}",
                         headers=auth(our_admin))
    assert unknown.status_code == r.status_code


def test_another_clubs_contribution_cannot_be_verified(client, db):
    ours = make_org(db, "ours2")
    theirs = make_org(db, "theirs2")
    their_admin = make_user(db, theirs, "ADMIN", "Their Admin")
    their_campaign = make_campaign(db, theirs, their_admin)
    cid = record(client, their_campaign, auth(their_admin)).json()["id"]

    our_admin = make_user(db, ours, "SUPER_ADMIN", "Our Admin")
    r = client.post(f"/api/v1/finance/contributions/{cid}/verify",
                    headers=auth(our_admin))
    assert r.status_code == 404
