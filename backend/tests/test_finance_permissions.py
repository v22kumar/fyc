"""Who may touch the club's money.

These are the tests this module exists for. Cricket answers the equivalent
question with the same four-line comparison copy-pasted at four call sites, and
it works — the risk is the fifth copy, written in a hurry, that forgets. So the
access rule lives in one function and every one of its edges is asserted here,
over HTTP, against a real database.

The club's decisions, restated as tests:

  * the treasurer verifies, because the treasurer holds the money
  * their own entry is the record the moment they write it
  * an executive may record, and it waits for the treasurer
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


def test_what_a_treasurer_records_is_the_record_not_a_claim(client, db):
    """They hold the money. There is nobody better placed to confirm it."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    treasurer = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, treasurer, by=admin)

    body = record(client, campaign, auth(treasurer)).json()
    assert body["status"] == "VERIFIED"
    assert body["verified_by_name"] == "Arun"
    # Not flagged: this is the design, not somebody skipping a check.
    assert body["self_verified"] is False


def test_an_executives_entry_waits_for_the_treasurer(client, db):
    """An executive handing money over has made a claim on somebody's cash box."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    treasurer = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, treasurer, by=admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    claim = record(client, campaign, auth(exec_member), contributor_name="Ravi").json()
    assert claim["status"] == "RECORDED"

    # And the treasurer can see it, because they are being asked about it.
    waiting = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions",
                         headers=auth(treasurer)).json()
    assert any(c["id"] == claim["id"] for c in waiting)

    done = client.post(f"/api/v1/finance/contributions/{claim['id']}/verify",
                       headers=auth(treasurer))
    assert done.status_code == 200
    assert done.json()["verified_by_name"] == "Arun"


def test_an_executive_cannot_confirm_their_own_claim(client, db):
    """That would put the claim and the confirmation in the same hands."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    appoint(db, campaign, make_user(db, org, "CLUB_MEMBER", "Arun"), by=admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    cid = record(client, campaign, auth(exec_member)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/verify",
                    headers=auth(exec_member))
    assert r.status_code == 403


def test_a_treasurer_can_still_correct_their_own_verified_entry(client, db):
    """They counted it. A system that will not let them fix a typo gets a
    second list kept on paper, which is worse than the typo."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    treasurer = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, treasurer, by=admin)

    cid = record(client, campaign, auth(treasurer), amount=1000).json()["id"]
    r = client.patch(f"/api/v1/finance/contributions/{cid}",
                     json={"amount": 1500}, headers=auth(treasurer))
    assert r.status_code == 200
    assert r.json()["amount_display"] == "₹1,500"


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


def test_a_treasurer_cannot_edit_a_row_they_cannot_read(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    # Verified on entry, so it never enters Arun's confirm queue and he has no
    # business reading it.
    theirs = record(client, campaign, auth(suresh)).json()["id"]
    r = client.patch(f"/api/v1/finance/contributions/{theirs}",
                     json={"amount": 99999}, headers=auth(arun))
    assert r.status_code == 404, (
        "a 403 here would confirm the id exists, which is exactly what the 404 "
        "on an unknown id refuses to answer")


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

def test_an_admin_can_confirm_when_the_treasurer_is_unreachable(client, db):
    """A break-glass, so an absent treasurer is not money that can never be
    confirmed — and it is marked, not silent."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    cid = record(client, campaign, auth(exec_member)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/verify", headers=auth(admin))
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "VERIFIED"
    assert r.json()["self_verified"] is True, "an override must be visible"

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["override_verified_count"] == 1


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


def test_a_treasurer_never_sees_the_whole_contributor_list(client, db):
    """Confirming what is waiting on them is not the same as browsing the club's
    list of who has money."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    record(client, campaign, auth(arun), contributor_name="Ravi")
    record(client, campaign, auth(suresh), contributor_name="Meena")

    seen = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions",
                      headers=auth(arun)).json()
    assert [c["contributor_name"] for c in seen] == ["Ravi"]


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


# ── Withdrawing money ───────────────────────────────────────────────────────
#
# Rejecting and cancelling are guarded inside a shared helper rather than at the
# endpoint, which is the shape that goes untested: reading the router shows no
# guard on the route itself. These say who may take money back out.

def test_an_ordinary_member_cannot_reject_a_contribution(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    outsider = make_user(db, org, "CLUB_MEMBER", "Nobody")

    cid = record(client, campaign, auth(arun)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/reject",
                    json={"reason": "I say so"}, headers=auth(outsider))
    assert r.status_code in (403, 404), "somebody with no job cannot undo money"


def test_an_executive_cannot_withdraw_what_a_treasurer_confirmed(client, db):
    """Verification moved to the treasurer, and so did its inverse. An
    executive who could not confirm money must not be able to erase it."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    cid = record(client, campaign, auth(arun)).json()["id"]
    for action in ("reject", "cancel"):
        r = client.post(f"/api/v1/finance/contributions/{cid}/{action}",
                        json={"reason": "changed my mind"}, headers=auth(exec_member))
        assert r.status_code == 403, f"{action} must need the money-holder"


def test_the_treasurer_can_say_it_never_reached_them(client, db):
    """The other half of the confirm queue: an executive's claim that did not
    arrive is refused by the person it was claimed against."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")

    cid = record(client, campaign, auth(exec_member)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/reject",
                    json={"reason": "Never reached me"}, headers=auth(arun))
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "REJECTED"
    assert r.json()["resolution_reason"] == "Never reached me"

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["collected_paise"] == 0, "refused money is not collected money"
    assert summary["withdrawn_paise"] == 100000


def test_another_clubs_contribution_cannot_be_rejected(client, db):
    ours = make_org(db, "ours-r")
    theirs = make_org(db, "theirs-r")
    their_admin = make_user(db, theirs, "ADMIN", "Their Admin")
    their_campaign = make_campaign(db, theirs, their_admin)
    cid = record(client, their_campaign, auth(their_admin)).json()["id"]

    our_admin = make_user(db, ours, "SUPER_ADMIN", "Our Admin")
    r = client.post(f"/api/v1/finance/contributions/{cid}/reject",
                    json={"reason": "not mine to touch"}, headers=auth(our_admin))
    assert r.status_code == 404
