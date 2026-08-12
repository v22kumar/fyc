"""The numbers on the dashboard, and the campaign they belong to.

Every figure here is derived from the rows on read. There is no running-total
column anywhere in this module — the same call the club already made for
cricket standings, for the same reason: a stored total is a second source of
truth that goes wrong quietly, and here the thing going quietly wrong is how
much money the club thinks it has.
"""
from datetime import date

from app.models.audit import AuditLog
from app.models.event import Event
from tests.conftest_finance import (appoint, auth, make_campaign, make_org,
                                    make_user, record)


# ── Creating one, once a year ───────────────────────────────────────────────

def test_an_admin_creates_the_collection_and_the_event_it_funds(client, db):
    """The anniversary needs an Event and does not have one.

    Making the admin go to another screen, create it, come back and link it is
    three chances to end up with a collection attached to nothing.
    """
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")

    r = client.post("/api/v1/finance/campaigns", headers=auth(admin), json={
        "title_en": "FYC Anniversary Celebration 2026",
        "title_ta": "எஃப்ஒய்சி ஆண்டு விழா 2026",
        "purpose": "ANNIVERSARY",
        "suggested_amount": 3500,
        "starts_on": "2026-08-01",
        "ends_on": "2026-08-20",
        "create_event": True,
    })
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["event_id"] is not None
    assert body["suggested_display"] == "₹3,500"
    assert body["target_amount_paise"] is None, "no target until somebody sets one"

    event = db.query(Event).filter(Event.id == body["event_id"]).first()
    assert event is not None
    assert event.title_en == "FYC Anniversary Celebration 2026"
    assert event.event_kind == "CELEBRATION"


def test_next_year_is_another_row_not_another_deployment(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    for year in (2026, 2027):
        r = client.post("/api/v1/finance/campaigns", headers=auth(admin), json={
            "title_en": f"FYC Anniversary Celebration {year}",
            "purpose": "ANNIVERSARY", "suggested_amount": 3500,
        })
        assert r.status_code == 201
    assert len(client.get("/api/v1/finance/campaigns", headers=auth(admin)).json()) == 2


def test_a_tamil_title_is_worth_having_and_not_worth_blocking_a_collection_over(
        client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    r = client.post("/api/v1/finance/campaigns", headers=auth(admin),
                    json={"title_en": "Independence Day 2026"})
    assert r.status_code == 201
    assert r.json()["title_ta"] == "Independence Day 2026"


def test_an_ordinary_member_cannot_create_a_collection(client, db):
    org = make_org(db)
    member = make_user(db, org, "CLUB_MEMBER", "Nobody")
    r = client.post("/api/v1/finance/campaigns", headers=auth(member),
                    json={"title_en": "My Own Fundraiser"})
    assert r.status_code == 403


# ── The target, set and reset at will ───────────────────────────────────────

def test_no_target_reports_no_percentage_rather_than_a_misleading_one(client, db):
    """Zero would make the dashboard claim 100% collected on the first rupee."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin, target_amount_paise=None)
    record(client, campaign, auth(admin), amount=1000)

    s = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                   headers=auth(admin)).json()
    assert s["target_paise"] is None
    assert s["collection_percent"] is None
    assert s["remaining_paise"] is None
    assert s["collected_paise"] == 100000


def test_an_admin_can_set_the_target_later_and_change_it_again(client, db):
    """A club that raises its sights halfway through should not need a developer."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)

    url = f"/api/v1/finance/campaigns/{campaign.id}"
    assert client.patch(url, json={"target_amount": 100000},
                        headers=auth(admin)).json()["target_display"] == "₹1,00,000"
    assert client.patch(url, json={"target_amount": 150000},
                        headers=auth(admin)).json()["target_display"] == "₹1,50,000"


def test_a_target_can_be_removed_again(client, db):
    """Without an explicit clear, a target once set could never be unset."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin, target_amount_paise=10000000)

    r = client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                     json={"clear_target": True}, headers=auth(admin))
    assert r.json()["target_amount_paise"] is None


def test_the_suggested_amount_lives_on_the_campaign_not_in_the_app(client, db):
    """₹3,500 a head is this year's plan, not a constant to re-release for."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin, suggested_amount_paise=350000)

    s = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                   headers=auth(admin)).json()
    assert s["suggested_amount_paise"] == 350000

    client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                 json={"suggested_amount": 5000}, headers=auth(admin))
    s2 = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                    headers=auth(admin)).json()
    assert s2["suggested_amount_paise"] == 500000


# ── The nine numbers ────────────────────────────────────────────────────────

def test_the_dashboard_an_admin_opens_the_app_to_see(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin, target_amount_paise=10000000)  # ₹1,00,000
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)

    # Arun is the treasurer, so what he records is verified as he records it.
    record(client, campaign, auth(arun), contributor_name="Ravi", amount=55000)
    # Kumar is an executive: his entry is a claim until Arun confirms it.
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")
    record(client, campaign, auth(exec_member), contributor_name="Meena", amount=7500)

    s = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                   headers=auth(admin)).json()

    assert s["collected_paise"] == 6250000        # ₹62,500
    assert s["verified_paise"] == 5500000         # ₹55,000
    assert s["pending_paise"] == 750000           # ₹7,500
    assert s["remaining_paise"] == 3750000        # ₹37,500
    assert s["collection_percent"] == 62.5
    assert s["contributors"] == 2
    assert s["payments"] == 2
    assert s["active_treasurers"] == 1
    # Formatted once, on the server, so the app cannot disagree about grouping.
    assert s["display"]["collected"] == "₹62,500"
    assert s["display"]["target"] == "₹1,00,000"


def test_collection_never_reports_more_remaining_than_zero_once_passed(client, db):
    """A club that beats its target reports 0 remaining, not a negative."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin, target_amount_paise=100000)
    record(client, campaign, auth(admin), amount=2000)

    s = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                   headers=auth(admin)).json()
    assert s["remaining_paise"] == 0
    assert s["collection_percent"] == 200.0


def test_a_treasurer_gets_their_own_four_numbers(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    record(client, campaign, auth(arun), contributor_name="Ravi", amount=15000)
    # Kumar hands Arun ₹3,500 he collected; it waits for Arun to confirm it.
    exec_member = make_user(db, org, "EXECUTIVE_MEMBER", "Kumar")
    pending = record(client, campaign, auth(exec_member),
                     contributor_name="Meena", amount=3500).json()["id"]
    record(client, campaign, auth(suresh), contributor_name="Kavi", amount=99000)

    mine = client.get(f"/api/v1/finance/campaigns/{campaign.id}/my-summary",
                      headers=auth(arun)).json()
    assert mine["recorded_paise"] == 1500000
    assert mine["verified_paise"] == 1500000
    assert mine["pending_paise"] == 0
    assert mine["contributors"] == 1
    assert mine["display"]["recorded"] == "₹15,000"

    # Once Arun confirms Kumar's ₹3,500, it counts toward the campaign — but
    # it is still Kumar's entry, not Arun's collection.
    client.post(f"/api/v1/finance/contributions/{pending}/verify", headers=auth(arun))
    after = client.get(f"/api/v1/finance/campaigns/{campaign.id}/my-summary",
                       headers=auth(arun)).json()
    assert after["recorded_paise"] == 1500000


def test_a_treasurers_summary_carries_the_campaign_total_and_their_own(client, db):
    """The two numbers they actually compare, in one request."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)
    record(client, campaign, auth(arun), amount=1000)

    s = client.get(f"/api/v1/finance/campaigns/{campaign.id}/summary",
                   headers=auth(arun)).json()
    assert s["collected_paise"] == 100000
    assert s["mine"]["recorded_paise"] == 100000


# ── Breakdowns ──────────────────────────────────────────────────────────────

def test_treasurer_wise_collection(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    suresh = make_user(db, org, "CLUB_MEMBER", "Suresh")
    appoint(db, campaign, arun, by=admin)
    appoint(db, campaign, suresh, by=admin)

    record(client, campaign, auth(arun), contributor_name="Ravi", amount=24500)
    record(client, campaign, auth(suresh), contributor_name="Meena", amount=16000)

    rows = client.get(f"/api/v1/finance/campaigns/{campaign.id}/breakdown?by=treasurer",
                      headers=auth(admin)).json()["rows"]
    assert [r["name"] for r in rows] == ["Arun", "Suresh"], "ranked by amount"
    assert rows[0]["amount_display"] == "₹24,500"


def test_payment_method_breakdown(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    record(client, campaign, auth(admin), contributor_name="A", amount=42000,
           method="UPI", reference_no="U1")
    record(client, campaign, auth(admin), contributor_name="B", amount=8000,
           method="CASH")

    rows = client.get(f"/api/v1/finance/campaigns/{campaign.id}/breakdown?by=method",
                      headers=auth(admin)).json()["rows"]
    assert rows[0]["method"] == "UPI"
    assert rows[0]["amount_display"] == "₹42,000"


def test_daily_collection_reads_oldest_first(client, db):
    """It is the shape of the push, not a ranking."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    record(client, campaign, auth(admin), contributor_name="A", amount=1000,
           paid_on=str(date(2026, 8, 10)))
    record(client, campaign, auth(admin), contributor_name="B", amount=2000,
           paid_on=str(date(2026, 8, 1)))

    rows = client.get(f"/api/v1/finance/campaigns/{campaign.id}/breakdown?by=day",
                      headers=auth(admin)).json()["rows"]
    assert [r["day"] for r in rows] == ["2026-08-01", "2026-08-10"]


# ── Export ──────────────────────────────────────────────────────────────────

def test_the_export_is_a_spreadsheet_that_can_add_itself_up(client, db):
    """Plain rupees, not '₹3,500' — a currency symbol makes the column text."""
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    record(client, campaign, auth(admin), contributor_name="Ravi", amount=3500,
           method="UPI", reference_no="UTR9")

    r = client.get(f"/api/v1/finance/campaigns/{campaign.id}/contributions.csv",
                   headers=auth(admin))
    assert r.status_code == 200
    assert "text/csv" in r.headers["content-type"]
    assert "Ravi" in r.text
    assert "3500.00" in r.text
    assert "₹" not in r.text


# ── Audit ───────────────────────────────────────────────────────────────────

def test_every_change_to_money_is_written_to_the_audit_log_the_club_already_has(
        client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    arun = make_user(db, org, "CLUB_MEMBER", "Arun")
    appoint(db, campaign, arun, by=admin)

    cid = record(client, campaign, auth(arun), amount=1000).json()["id"]
    client.patch(f"/api/v1/finance/contributions/{cid}", json={"amount": 1500},
                 headers=auth(arun))

    logs = (db.query(AuditLog)
              .filter(AuditLog.target_table == "contributions")
              .order_by(AuditLog.created_at.asc()).all())
    actions = [entry.action_type for entry in logs]
    # RECEIVED, not RECORDED: a treasurer's entry arrives already confirmed, so
    # there is no separate verification to log.
    assert actions == ["CONTRIBUTION_RECEIVED", "CONTRIBUTION_UPDATED"]

    edit = logs[1]
    assert edit.old_values["amount_paise"] == 100000
    assert edit.new_values["amount_paise"] == 150000
    assert str(edit.user_id) == str(arun.id)


def test_changing_the_target_is_recorded_against_the_campaign(client, db):
    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    client.patch(f"/api/v1/finance/campaigns/{campaign.id}",
                 json={"target_amount": 100000}, headers=auth(admin))

    entry = (db.query(AuditLog)
               .filter(AuditLog.action_type == "FINANCE_CAMPAIGN_UPDATED").first())
    assert entry is not None
    assert entry.new_values["target_paise"] == 10000000


# ── The backstop ────────────────────────────────────────────────────────────

def test_the_reference_index_is_valid_ddl_and_actually_enforces(client, db):
    """The router checks first; this is what makes it true under a race.

    Two concurrent requests both pass a check-then-insert. Only the database
    can settle it. And the startup block that creates this index swallows
    failures into a log warning — so a syntax error there is indistinguishable
    from working, right up until two identical UTRs turn up in the ledger.
    """
    from sqlalchemy import text
    from sqlalchemy.exc import IntegrityError

    from app.models.finance import REFERENCE_UNIQUE_INDEX_DDL

    db.execute(text(REFERENCE_UNIQUE_INDEX_DDL))
    db.commit()

    org = make_org(db)
    admin = make_user(db, org, "ADMIN", "Admin")
    campaign = make_campaign(db, org, admin)
    record(client, campaign, auth(admin), contributor_name="Ravi", amount=1000,
           method="UPI", reference_no="UTR777")

    # Straight past the router's check, the way a racing second request would.
    from app.models.finance import Contribution
    db.add(Contribution(
        campaign_id=campaign.id, organization_id=org.id,
        contributor_name="Ravi", contributor_key="n:ravi",
        amount_paise=100000, method="UPI", reference_no="UTR777",
        paid_on=date(2026, 8, 12), status="RECORDED",
        recorded_by_user_id=admin.id))
    try:
        db.commit()
        raise AssertionError("the database let a duplicate reference through")
    except IntegrityError:
        db.rollback()
