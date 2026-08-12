"""Signing in with Google without depending on how the build was signed.

The native plugin authenticates with the pair (package name, signing
certificate), and Play re-signs uploaded bundles with its own key — so the Play
copy and the sideloaded copy present different certificates and either can be
missing from the console. When one is, Google answers DEVELOPER_ERROR (code 10)
and there is nothing the app can do about it.

These tests pin the road round that: ordinary web OAuth in the browser, with the
answer parked server-side under a secret single-use handle.
"""
import uuid

import pytest

from app.core.config import settings
from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.routers import auth as auth_router
from app.services import google_browser_auth


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"g-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _member(db, org, email):
    u = User(organization_id=org.id, email=email, phone_number="+919888812345",
             password_hash=get_password_hash("x"), role="MEMBER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="Test Member", full_name_ta="சோதனை"))
    db.commit()
    return u


@pytest.fixture
def configured(monkeypatch):
    """The settings an admin supplies once, in the console and in Fly."""
    monkeypatch.setattr(settings, "GOOGLE_WEB_CLIENT_ID", "web-client.apps.googleusercontent.com")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "shh")
    monkeypatch.setattr(settings, "GOOGLE_OAUTH_REDIRECT_URI",
                        "https://api.fycconnect.com/api/v1/auth/google/browser/callback")


# ── When it is not set up, it says so instead of failing later ──────────────

def test_unconfigured_reports_exactly_which_settings_are_missing(client, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_WEB_CLIENT_ID", "")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "")
    body = client.get("/api/v1/auth/google/browser/available").json()
    assert body["available"] is False
    assert "GOOGLE_WEB_CLIENT_ID" in body["missing"]
    assert "GOOGLE_CLIENT_SECRET" in body["missing"]


def test_starting_an_unconfigured_flow_is_refused_not_half_begun(client, db, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_SECRET", "")
    org = _org(db)
    r = client.post("/api/v1/auth/google/browser/start",
                    json={"organization_id": str(org.id)})
    assert r.status_code == 503


def test_available_when_configured(client, configured):
    body = client.get("/api/v1/auth/google/browser/available").json()
    assert body["available"] is True
    assert body["missing"] == []


# ── Starting ────────────────────────────────────────────────────────────────

def test_start_hands_back_a_url_google_will_accept(client, db, configured):
    org = _org(db)
    r = client.post("/api/v1/auth/google/browser/start",
                    json={"organization_id": str(org.id)})
    assert r.status_code == 200, r.text
    body = r.json()
    url = body["authorization_url"]
    assert url.startswith("https://accounts.google.com/o/oauth2/v2/auth?")
    assert "web-client.apps.googleusercontent.com" in url
    assert "response_type=code" in url
    # The handle is the state: that binding is what stops somebody else's
    # callback from landing in this member's session.
    assert f"state={body['session_id']}" in url


def test_start_refuses_an_organization_that_does_not_exist(client, configured):
    r = client.post("/api/v1/auth/google/browser/start",
                    json={"organization_id": str(uuid.uuid4())})
    assert r.status_code == 404


def test_result_is_pending_until_the_browser_comes_back(client, db, configured):
    org = _org(db)
    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]
    body = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert body["status"] == "pending"


# ── The callback ────────────────────────────────────────────────────────────

def test_a_callback_carrying_a_state_we_never_issued_goes_nowhere(client, configured):
    r = client.get("/api/v1/auth/google/browser/callback?code=abc&state=not-ours")
    assert r.status_code == 200
    assert "expired" in r.text.lower()


def test_a_member_who_cancels_at_google_is_told_nothing_changed(client, db, configured):
    org = _org(db)
    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]
    r = client.get(f"/api/v1/auth/google/browser/callback?error=access_denied&state={sid}")
    assert r.status_code == 200
    assert "cancelled" in r.text.lower()

    body = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert body["status"] == "failed"
    assert "access_denied" in body["error"]


def test_google_refusing_the_exchange_reaches_the_member_as_a_sentence(
        client, db, configured, monkeypatch):
    org = _org(db)
    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]

    async def refuse(code):
        raise ValueError("Google refused the sign-in (redirect_uri_mismatch).")
    monkeypatch.setattr(google_browser_auth, "exchange_code_for_id_token", refuse)

    client.get(f"/api/v1/auth/google/browser/callback?code=abc&state={sid}")
    body = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert body["status"] == "failed"
    # The one mistake that is invisible until it happens, named.
    assert "redirect_uri_mismatch" in body["error"]


# ── The whole way through ───────────────────────────────────────────────────

def _google_says(monkeypatch, email, name="Test Member"):
    async def exchange(code):
        return "an-id-token"
    monkeypatch.setattr(google_browser_auth, "exchange_code_for_id_token", exchange)
    monkeypatch.setattr(auth_router, "_verify_google_id_token",
                        lambda tok: {"email": email, "sub": "google-sub-1", "name": name})


def test_an_existing_member_signs_in_end_to_end(client, db, configured, monkeypatch):
    org = _org(db)
    _member(db, org, "member@example.com")
    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]

    _google_says(monkeypatch, "member@example.com")
    page = client.get(f"/api/v1/auth/google/browser/callback?code=abc&state={sid}")
    assert page.status_code == 200
    assert "signed in" in page.text.lower()

    body = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert body["status"] == "ready"
    assert body["result"]["access_token"]
    assert body["result"]["refresh_token"]


def test_the_handle_is_spent_once_and_then_worthless(client, db, configured, monkeypatch):
    org = _org(db)
    _member(db, org, "member@example.com")
    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]
    _google_says(monkeypatch, "member@example.com")
    client.get(f"/api/v1/auth/google/browser/callback?code=abc&state={sid}")

    first = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert first["status"] == "ready"

    # A handle guarding a finished session must stop being useful the moment
    # it is used, because it is the only credential in front of that session.
    second = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert second["status"] == "expired"


def test_a_brand_new_google_account_is_sent_to_registration_not_half_created(
        client, db, configured, monkeypatch):
    org = _org(db)
    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]

    _google_says(monkeypatch, "stranger@example.com", name="A Stranger")
    client.get(f"/api/v1/auth/google/browser/callback?code=abc&state={sid}")

    body = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert body["status"] == "ready"
    # Same rule as the native road: collect the phone number and date of birth
    # before an account exists, rather than creating an empty one.
    assert body["result"]["needs_registration"] is True
    assert body["result"]["email"] == "stranger@example.com"
    assert db.query(User).filter(User.email == "stranger@example.com").first() is None


def test_a_blocked_member_is_still_blocked_on_this_road(client, db, configured, monkeypatch):
    org = _org(db)
    u = _member(db, org, "blocked@example.com")
    u.is_blocked = True
    db.commit()

    sid = client.post("/api/v1/auth/google/browser/start",
                      json={"organization_id": str(org.id)}).json()["session_id"]
    _google_says(monkeypatch, "blocked@example.com")
    client.get(f"/api/v1/auth/google/browser/callback?code=abc&state={sid}")

    body = client.get(f"/api/v1/auth/google/browser/result?session_id={sid}").json()
    assert body["status"] == "failed"
    assert "blocked" in body["error"].lower()


def test_an_unknown_handle_reads_as_expired_rather_than_pending_forever(client, configured):
    body = client.get(
        "/api/v1/auth/google/browser/result?session_id=never-issued").json()
    assert body["status"] == "expired"
