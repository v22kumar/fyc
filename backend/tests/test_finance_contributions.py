"""Recording money, and the three different things that look like doing it twice.

Duplicate protection usually ends up either useless or infuriating because all
three get treated as one problem. They are not:

  1. the request arrived twice — not a duplicate at all
  2. the same transaction reference — always an error
  3. same person, same amount, minutes apart — only a human knows

Each gets a different answer, and each is pinned here.
"""
from datetime import date

from tests.conftest_finance import (appoint, auth, make_campaign, make_org,
                                    make_user, record)


def _setup(db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    treasurer = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, treasurer, by=admin)
    return org, admin, campaign, treasurer


# ── Recording ───────────────────────────────────────────────────────────────

def test_a_contribution_from_somebody_who_is_not_a_member(client, db):
    """Half the village is not in the app, and their money still counts."""
    org, admin, campaign, arun = _setup(db)
    r = record(client, campaign, auth(arun),
               contributor_name="Ravi", contributor_phone="+91 94879 84964",
               amount=3500, method="UPI", reference_no="UTR123456")
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["contributor_user_id"] is None
    assert body["contributor_name"] == "Ravi"
    assert body["amount_display"] == "₹3,500"
    assert body["status"] == "RECORDED"


def test_a_contribution_from_a_member_keeps_the_name_as_well_as_the_link(client, db):
    """If that account is ever removed, the ledger still reads."""
    org, admin, campaign, arun = _setup(db)
    giver = make_user(db, org, "CLUB_MEMBER", "Meena")

    body = record(client, campaign, auth(arun),
                  contributor_user_id=str(giver.id), contributor_name=None,
                  amount=5000).json()
    assert body["contributor_user_id"] == str(giver.id)
    assert body["contributor_name"] == "Meena"


def test_cash_never_needs_a_transaction_id(client, db):
    """Demanding one for a note handed across a table is how a treasurer stops
    using the app."""
    org, admin, campaign, arun = _setup(db)
    r = record(client, campaign, auth(arun), method="CASH", reference_no=None)
    assert r.status_code == 201
    assert r.json()["reference_no"] is None


def test_a_contribution_needs_somebody_to_be_from(client, db):
    org, admin, campaign, arun = _setup(db)
    r = record(client, campaign, auth(arun), contributor_name="   ")
    assert r.status_code == 422


def test_an_extra_zero_is_refused(client, db):
    org, admin, campaign, arun = _setup(db)
    r = record(client, campaign, auth(arun), amount=99_00_00_000)
    assert r.status_code == 422


def test_a_closed_collection_does_not_take_money(client, db):
    org, admin, campaign, arun = _setup(db)
    client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                 json={"status": "CLOSED"}, headers=auth(admin))
    r = record(client, campaign, auth(arun))
    assert r.status_code == 400
    assert "closed" in r.json()["detail"].lower()


# ── Layer 1: the request arrived twice ──────────────────────────────────────

def test_the_same_client_id_twice_is_one_payment_and_no_complaint(client, db):
    """A double tap, a retry and an offline entry replayed after it landed all
    look identical from the server. All three mean one payment."""
    org, admin, campaign, arun = _setup(db)
    first = record(client, campaign, auth(arun), amount=1000,
                   client_contribution_id="phone-abc-1")
    second = record(client, campaign, auth(arun), amount=1000,
                    client_contribution_id="phone-abc-1")

    assert first.status_code == 201
    assert second.status_code == 201, "a retry is not an error"
    assert first.json()["id"] == second.json()["id"]

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["payments"] == 1
    assert summary["collected_paise"] == 100000


def test_two_treasurers_may_use_the_same_client_id(client, db):
    """The id is unique per phone, not globally. Two devices can both call
    their first entry 'entry-1' without one of them being swallowed."""
    org, admin, campaign, arun = _setup(db)
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, suresh, by=admin)

    a = record(client, campaign, auth(arun), contributor_name="Ravi",
               client_contribution_id="entry-1")
    b = record(client, campaign, auth(suresh), contributor_name="Meena",
               client_contribution_id="entry-1")
    assert a.status_code == b.status_code == 201
    assert a.json()["id"] != b.json()["id"]


def test_one_payment_written_down_by_two_treasurers_is_caught(client, db):
    """The duplicate that actually happens at an event.

    Ravi pays once; Arun writes it in his phone and Suresh writes it in his.
    Neither of them has done anything wrong and neither can see the other's
    list, so nothing but the server is in a position to notice. It asks rather
    than refuses — the same two people can legitimately both collect ₹1,000
    from two different Ravis — and the answer names who already has it.
    """
    org, admin, campaign, arun = _setup(db)
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, suresh, by=admin)

    record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000)
    r = record(client, campaign, auth(suresh), contributor_name="Ravi", amount=1000)

    assert r.status_code == 409
    body = r.json()["detail"]
    assert body["kind"] == "similar"
    assert body["can_confirm"] is True
    assert body["candidates"][0]["recorded_by_name"] == "Arun"


# ── Layer 2: the same reference ─────────────────────────────────────────────

def test_the_same_utr_twice_is_refused_and_says_which_row_has_it(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000,
           method="UPI", reference_no="UTR12345")

    r = record(client, campaign, auth(arun), contributor_name="Meena", amount=2000,
               method="UPI", reference_no="UTR12345")
    assert r.status_code == 409
    body = r.json()["detail"]
    assert body["kind"] == "reference"
    assert body["can_confirm"] is False, "a repeated UTR is never legitimate"
    assert "Ravi" in body["candidates"][0]["contributor_name"]


def test_a_reference_is_the_same_however_it_was_typed(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), method="UPI", reference_no="utr 12345")
    r = record(client, campaign, auth(arun), contributor_name="Meena",
               method="UPI", reference_no="UTR12345")
    assert r.status_code == 409


def test_a_cancelled_reference_stops_blocking_the_entry_that_replaces_it(client, db):
    org, admin, campaign, arun = _setup(db)
    wrong = record(client, campaign, auth(arun), method="UPI",
                   reference_no="UTR999").json()["id"]
    client.post(f"/api/v1/finance/contributions/{wrong}/reject",
                json={"reason": "Typed the wrong UTR"}, headers=auth(admin))

    r = record(client, campaign, auth(arun), contributor_name="Ravi",
               method="UPI", reference_no="UTR999")
    assert r.status_code == 201, "the correct entry must be able to reuse it"


# ── Layer 3: same person, same amount, minutes apart ────────────────────────

def test_a_likely_repeat_is_asked_about_rather_than_blocked(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000)

    r = record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000)
    assert r.status_code == 409
    body = r.json()["detail"]
    assert body["kind"] == "similar"
    assert body["can_confirm"] is True
    assert "same payment" in body["detail"].lower()


def test_confirming_records_it_because_two_neighbours_can_both_give_500(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi", amount=500)
    r = record(client, campaign, auth(arun), contributor_name="Ravi", amount=500,
               confirm_duplicate=True)
    assert r.status_code == 201

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["payments"] == 2
    assert summary["contributors"] == 1, "still one Ravi"


def test_a_different_amount_from_the_same_person_is_not_suspicious(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000)
    r = record(client, campaign, auth(arun), contributor_name="Ravi", amount=2000)
    assert r.status_code == 201


def test_one_person_reached_by_two_spellings_of_their_number_is_one_contributor(client, db):
    """+91 94879 84964 and 9487984964 are the same person."""
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi",
           contributor_phone="+91 94879 84964", amount=1000)
    record(client, campaign, auth(arun), contributor_name="Ravi Kumar",
           contributor_phone="9487984964", amount=2000)

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["payments"] == 2
    assert summary["contributors"] == 1


# ── Correcting ──────────────────────────────────────────────────────────────

def test_a_treasurer_can_fix_their_own_unverified_entry(client, db):
    org, admin, campaign, arun = _setup(db)
    cid = record(client, campaign, auth(arun), amount=1000).json()["id"]

    r = client.patch(f"/api/v1/finance/contributions/{cid}",
                     json={"amount": 1500, "notes": "Counted again"},
                     headers=auth(arun))
    assert r.status_code == 200
    assert r.json()["amount_display"] == "₹1,500"


def test_once_verified_a_treasurer_can_no_longer_change_it(client, db):
    """It stopped being their claim and became the club's record."""
    org, admin, campaign, arun = _setup(db)
    cid = record(client, campaign, auth(arun)).json()["id"]
    client.post(f"/api/v1/finance/contributions/{cid}/verify", headers=auth(admin))

    r = client.patch(f"/api/v1/finance/contributions/{cid}",
                     json={"amount": 9999}, headers=auth(arun))
    assert r.status_code == 403
    assert "verified" in r.json()["detail"].lower()


def test_correcting_a_name_moves_the_contributor_count_with_it(client, db):
    """The identity key is derived, so it has to move when the identity does."""
    org, admin, campaign, arun = _setup(db)
    a = record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000).json()["id"]
    record(client, campaign, auth(arun), contributor_name="Meena", amount=1000)

    before = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                        headers=auth(admin)).json()["contributors"]
    assert before == 2

    client.patch(f"/api/v1/finance/contributions/{a}",
                 json={"contributor_name": "Meena"}, headers=auth(arun))

    after = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                       headers=auth(admin)).json()["contributors"]
    assert after == 1


# ── Withdrawing ─────────────────────────────────────────────────────────────

def test_nothing_is_ever_deleted_only_resolved_with_a_reason(client, db):
    org, admin, campaign, arun = _setup(db)
    cid = record(client, campaign, auth(arun), amount=1000).json()["id"]

    r = client.post(f"/api/v1/finance/contributions/{cid}/cancel",
                    json={"reason": "Returned to the family"}, headers=auth(admin))
    assert r.status_code == 200
    assert r.json()["status"] == "CANCELLED"
    assert r.json()["resolution_reason"] == "Returned to the family"

    # The row is still there and still readable.
    assert client.get(f"/api/v1/finance/contributions/{cid}",
                      headers=auth(admin)).status_code == 200


def test_withdrawing_without_a_reason_is_refused(client, db):
    """A hole in the total that nobody can explain is what an audit trail is for."""
    org, admin, campaign, arun = _setup(db)
    cid = record(client, campaign, auth(arun)).json()["id"]
    r = client.post(f"/api/v1/finance/contributions/{cid}/cancel",
                    json={"reason": ""}, headers=auth(admin))
    assert r.status_code == 422


def test_withdrawn_money_leaves_the_total(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), amount=1000)
    cid = record(client, campaign, auth(arun), contributor_name="Meena",
                 amount=2000).json()["id"]
    client.post(f"/api/v1/finance/contributions/{cid}/reject",
                json={"reason": "Cheque bounced"}, headers=auth(admin))

    summary = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                         headers=auth(admin)).json()
    assert summary["collected_paise"] == 100000
    assert summary["withdrawn_paise"] == 200000
    assert summary["payments"] == 1


def test_rejection_and_cancellation_stay_different_facts(client, db):
    """'This was never real' and 'this was real and has been undone' are the
    only things that would ever explain the total."""
    org, admin, campaign, arun = _setup(db)
    a = record(client, campaign, auth(arun), amount=1000).json()["id"]
    b = record(client, campaign, auth(arun), contributor_name="Meena",
               amount=2000).json()["id"]

    client.post(f"/api/v1/finance/contributions/{a}/reject",
                json={"reason": "Entered by mistake"}, headers=auth(admin))
    client.post(f"/api/v1/finance/contributions/{b}/cancel",
                json={"reason": "Refunded"}, headers=auth(admin))

    rows = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions",
                      headers=auth(admin)).json()
    assert {r["status"] for r in rows} == {"REJECTED", "CANCELLED"}


def test_verifying_twice_is_not_an_error(client, db):
    org, admin, campaign, arun = _setup(db)
    cid = record(client, campaign, auth(arun)).json()["id"]
    first = client.post(f"/api/v1/finance/contributions/{cid}/verify", headers=auth(admin))
    second = client.post(f"/api/v1/finance/contributions/{cid}/verify", headers=auth(admin))
    assert first.status_code == second.status_code == 200
    assert first.json()["verified_at"] == second.json()["verified_at"]


# ── Filtering ───────────────────────────────────────────────────────────────

def test_the_filters_an_admin_actually_uses(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi", amount=1000,
           method="CASH", paid_on=str(date(2026, 8, 1)))
    record(client, campaign, auth(arun), contributor_name="Meena", amount=5000,
           method="UPI", reference_no="UTR1", paid_on=str(date(2026, 8, 10)))

    base = f"/api/v1/finance/campaigns/{campaign.id}/contributions"
    h = auth(admin)

    assert len(client.get(f"{base}?method=UPI", headers=h).json()) == 1
    assert len(client.get(f"{base}?q=Ravi", headers=h).json()) == 1
    assert len(client.get(f"{base}?q=UTR1", headers=h).json()) == 1
    assert len(client.get(f"{base}?min_amount=2000", headers=h).json()) == 1
    assert len(client.get(f"{base}?from_date=2026-08-05", headers=h).json()) == 1
    assert len(client.get(f"{base}?status=RECORDED", headers=h).json()) == 2

    by_amount = client.get(f"{base}?sort=amount", headers=h).json()
    assert [c["contributor_name"] for c in by_amount] == ["Meena", "Ravi"]


def test_a_reference_left_over_from_the_previous_entry_does_not_stick_to_cash(client, db):
    """The entry screen keeps the method and clears the rest between entries.

    A UTR still sitting in the field when the treasurer switches to cash would
    attach a real reference to a cash row — and then block the UPI entry that
    legitimately carries it, with a message about a payment that never had one.
    """
    org, admin, campaign, arun = _setup(db)
    stuck = record(client, campaign, auth(arun), contributor_name="Ravi",
                   amount=500, method="CASH", reference_no="UTR55555")
    assert stuck.status_code == 201
    assert stuck.json()["reference_no"] is None

    real = record(client, campaign, auth(arun), contributor_name="Meena",
                  amount=1000, method="UPI", reference_no="UTR55555")
    assert real.status_code == 201, "the genuine UPI entry must not be blocked"


# ── Suggestions ─────────────────────────────────────────────────────────────

def test_the_second_time_ravi_gives_three_letters_finishes_the_job(client, db):
    org, admin, campaign, arun = _setup(db)
    record(client, campaign, auth(arun), contributor_name="Ravi Kumar",
           contributor_phone="9487984964", amount=1000)

    hits = client.get(
        f"/api/v1/finance/campaigns/{campaign.id}/contributor-suggestions?q=rav",
        headers=auth(arun)).json()
    assert len(hits) == 1
    assert hits[0]["name"] == "Ravi Kumar"
    # The phone comes back too — that is what makes the second gift count as
    # the same person rather than a second contributor.
    assert hits[0]["phone"] == "9487984964"


def test_suggestions_do_not_leak_another_treasurers_contributors(client, db):
    org, admin, campaign, arun = _setup(db)
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, suresh, by=admin)
    record(client, campaign, auth(suresh), contributor_name="Meena", amount=1000)

    mine = client.get(
        f"/api/v1/finance/campaigns/{campaign.id}/contributor-suggestions",
        headers=auth(arun)).json()
    assert mine == []

    theirs = client.get(
        f"/api/v1/finance/campaigns/{campaign.id}/contributor-suggestions",
        headers=auth(admin)).json()
    assert [c["name"] for c in theirs] == ["Meena"]
