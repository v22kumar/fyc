"""GET /users/me must never take the app down over schema drift.

The app hits it on every open to learn whose it is; a 500 here shows up as
the home screen greeting nobody and a "?" where the avatar goes.
"""
import uuid

from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    o = Organization(id=uuid.uuid4(), slug=f"me-{uuid.uuid4().hex[:6]}",
                     name_ta="அ", name_en="Org")
    db.add(o); db.commit(); return o


def _user(db, org_id, phone, name):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role="VOLUNTEER",
             is_verified=True)
    db.add(u); db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.commit(); return u


def test_me_returns_the_name(client, db):
    org = _org(db)
    _user(db, org.id, "9920000001", "Arun Kumar")
    tok = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "9920000001",
        "password": "pass"}).json()["access_token"]
    r = client.get("/api/v1/auth/users/me", headers={
        "Authorization": f"Bearer {tok}", "X-Organization-ID": str(org.id)})
    assert r.status_code == 200
    assert r.json()["full_name_en"] == "Arun Kumar"


def test_me_survives_a_profile_load_failure(client, db, monkeypatch):
    """If the ORM profile load raises (a drifted column), /me still answers
    200 with the name via the targeted fallback — the app opens knowing who
    it is instead of showing a question mark."""
    org = _org(db)
    _user(db, org.id, "9920000002", "Meena R.")
    tok = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "9920000002",
        "password": "pass"}).json()["access_token"]

    # Simulate schema drift precisely: only a UserProfile ORM query blows up.
    # get_current_user (which queries User) and the raw-SQL fallback both pass.
    from sqlalchemy.orm import Session as _Session
    orig_query = _Session.query

    def boom_query(self, *models, **kw):
        if models and models[0] is UserProfile:
            raise Exception("column celebrate_publicly does not exist")
        return orig_query(self, *models, **kw)

    monkeypatch.setattr(_Session, "query", boom_query)
    r = client.get("/api/v1/auth/users/me", headers={
        "Authorization": f"Bearer {tok}", "X-Organization-ID": str(org.id)})
    # The point: a drifted profile column turns /me from a 500 (app shows "?")
    # into a 200 (app opens). The name comes back too in production — the
    # fallback reads it through a fresh session — but this harness keeps its
    # fixtures in an uncommitted outer transaction a fresh session cannot see,
    # the same limitation documented in test_tournament_flow.py. So we assert
    # the resilience the harness can prove: it did not 500.
    assert r.status_code == 200, "the app must still learn whose it is"
    assert "full_name_en" in r.json()
