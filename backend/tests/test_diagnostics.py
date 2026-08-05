"""
Client error reporting.

The club cannot test on a phone, so the fallback is hearing about failures the
moment a member hits one. These tests hold the endpoint to the properties that
make that dependable: it accepts reports from people who are not signed in,
groups repeats, and never makes a bad situation worse by failing loudly.
"""
import uuid

from app.core.security import create_access_token, get_password_hash
from app.models.client_error import ClientError
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}",
                       name_ta="x", name_en="x")
    db.add(org)
    db.commit()
    return org


def _user(db, org, phone, role="USER"):
    u = User(organization_id=org.id, phone_number=phone,
             password_hash=get_password_hash("x"), role=role, is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="P", full_name_ta="P"))
    db.commit()
    return u


def _auth(u, org):
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(org.id))}",
        "X-Organization-ID": str(org.id),
    }


def _anon(org):
    return {"X-Organization-ID": str(org.id)}


def _err(**kw):
    base = {"message": "Bad state: something broke", "platform": "android"}
    base.update(kw)
    return base


# ── Accepting reports ─────────────────────────────────────────────────────────

def test_an_error_is_stored(client, db):
    org = _org(db)
    r = client.post("/api/v1/diagnostics/errors",
                    json={"errors": [_err(stack="#0 main\n#1 run")]},
                    headers=_anon(org))
    assert r.status_code == 202, r.text
    row = db.query(ClientError).first()
    assert row.message.startswith("Bad state")
    assert row.platform == "android"
    assert row.occurrences == 1


def test_a_signed_out_member_can_still_report(client, db):
    """A crash during sign-in is exactly the kind we most want to hear about, so
    requiring a token would hide the most important reports."""
    org = _org(db)
    r = client.post("/api/v1/diagnostics/errors",
                    json={"errors": [_err(context="/login")]},
                    headers=_anon(org))
    assert r.status_code == 202
    assert db.query(ClientError).first().user_id is None


def test_a_signed_in_report_records_who_hit_it(client, db):
    org = _org(db)
    u = _user(db, org, "9300000001")
    client.post("/api/v1/diagnostics/errors", json={"errors": [_err()]},
                headers=_auth(u, org))
    assert db.query(ClientError).first().user_id == u.id


def test_repeats_are_folded_into_one_row_with_a_count(client, db):
    """A crash loop must not bury every other error."""
    org = _org(db)
    for _ in range(5):
        client.post("/api/v1/diagnostics/errors",
                    json={"errors": [_err(stack="#0 same place")]},
                    headers=_anon(org))
    rows = db.query(ClientError).all()
    assert len(rows) == 1
    assert rows[0].occurrences == 5


def test_different_failures_stay_separate(client, db):
    org = _org(db)
    client.post("/api/v1/diagnostics/errors",
                json={"errors": [_err(message="A failed", stack="#0 a")]},
                headers=_anon(org))
    client.post("/api/v1/diagnostics/errors",
                json={"errors": [_err(message="B failed", stack="#0 b")]},
                headers=_anon(org))
    assert db.query(ClientError).count() == 2


def test_the_same_message_from_different_platforms_is_not_merged(client, db):
    """An Android-only crash and a web-only crash are different bugs."""
    org = _org(db)
    client.post("/api/v1/diagnostics/errors",
                json={"errors": [_err(platform="android")]}, headers=_anon(org))
    client.post("/api/v1/diagnostics/errors",
                json={"errors": [_err(platform="web")]}, headers=_anon(org))
    assert db.query(ClientError).count() == 2


def test_a_batch_is_accepted_in_one_call(client, db):
    org = _org(db)
    r = client.post("/api/v1/diagnostics/errors", json={"errors": [
        _err(message="one", stack="#0 x"),
        _err(message="two", stack="#0 y"),
    ]}, headers=_anon(org))
    assert r.json()["accepted"] == 2
    assert db.query(ClientError).count() == 2


# ── Never make things worse ───────────────────────────────────────────────────

def test_an_empty_report_is_shrugged_off(client, db):
    org = _org(db)
    r = client.post("/api/v1/diagnostics/errors", json={"errors": []},
                    headers=_anon(org))
    assert r.status_code == 202
    assert db.query(ClientError).count() == 0


def test_a_blank_message_is_ignored_rather_than_stored(client, db):
    org = _org(db)
    r = client.post("/api/v1/diagnostics/errors",
                    json={"errors": [{"message": "   ", "platform": "web"}]},
                    headers=_anon(org))
    assert r.status_code == 202
    assert db.query(ClientError).count() == 0


def test_enormous_payloads_are_truncated_not_rejected(client, db):
    """An error report should never be the thing that fails."""
    org = _org(db)
    r = client.post("/api/v1/diagnostics/errors", json={"errors": [
        _err(message="x" * 3000, stack="y" * 9000),
    ]}, headers=_anon(org))
    assert r.status_code == 202
    row = db.query(ClientError).first()
    assert len(row.message) <= 2000
    assert len(row.stack) <= 6000


# ── Reading them back ─────────────────────────────────────────────────────────

def test_an_organizer_can_read_recent_errors(client, db):
    org = _org(db)
    admin = _user(db, org, "9300000002", role="ADMIN")
    client.post("/api/v1/diagnostics/errors", json={"errors": [_err()]},
                headers=_anon(org))

    r = client.get("/api/v1/diagnostics/errors", headers=_auth(admin, org))
    assert r.status_code == 200, r.text
    assert len(r.json()) == 1
    assert r.json()[0]["platform"] == "android"


def test_a_member_cannot_read_other_peoples_errors(client, db):
    org = _org(db)
    member = _user(db, org, "9300000003")
    r = client.get("/api/v1/diagnostics/errors", headers=_auth(member, org))
    assert r.status_code in (401, 403)


def test_the_summary_counts_distinct_failures_per_platform(client, db):
    org = _org(db)
    admin = _user(db, org, "9300000004", role="ADMIN")
    for _ in range(3):
        client.post("/api/v1/diagnostics/errors",
                    json={"errors": [_err(platform="web", stack="#0 same")]},
                    headers=_anon(org))
    client.post("/api/v1/diagnostics/errors",
                json={"errors": [_err(platform="android", stack="#0 other")]},
                headers=_anon(org))

    body = client.get("/api/v1/diagnostics/errors/summary",
                      headers=_auth(admin, org)).json()
    by = {p["platform"]: p for p in body["platforms"]}
    assert by["web"]["distinct"] == 1 and by["web"]["total"] == 3
    assert by["android"]["distinct"] == 1


def test_errors_do_not_leak_across_organisations(client, db):
    org_a, org_b = _org(db), _org(db)
    admin_b = _user(db, org_b, "9300000005", role="ADMIN")
    client.post("/api/v1/diagnostics/errors", json={"errors": [_err()]},
                headers=_anon(org_a))
    assert client.get("/api/v1/diagnostics/errors",
                      headers=_auth(admin_b, org_b)).json() == []
