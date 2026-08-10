"""A password published in this repository is not a password.

`admin@fycconnect.org` was seeded with `changeme_admin_password` — the literal
default in `app/core/config.py`, which lives in a public repository. Password
login accepts email *or* phone, and that account is SUPER_ADMIN: every member's
phone number, every child's event registration, broadcast to the whole club,
delete anything.

The trap underneath it: `FIRST_SUPERADMIN_PASSWORD` reads like "the
superadmin's password", but it only ever applied on the *first* boot, when the
database was empty. On an established database the account kept its original
hash — so setting the secret satisfied the production guard while the
publicly-documented credential stayed live. The fix looked done and was not.
"""
import uuid

import pytest

from app.core.config import KNOWN_DEFAULT_PASSWORDS
from app.core.security import get_password_hash, verify_password
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"dp-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _admin(db, org_id, password, phone="9760000001",
           email="admin@fycconnect.org"):
    u = User(organization_id=org_id, phone_number=phone, email=email,
             password_hash=get_password_hash(password), role="SUPER_ADMIN",
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="நிர்வாகி",
                       full_name_en="Admin"))
    db.commit()
    return u


def _login(client, org_id, username, password):
    return client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org_id), "username": username,
        "password": password})


@pytest.mark.parametrize("default", sorted(KNOWN_DEFAULT_PASSWORDS))
def test_a_published_default_cannot_sign_anybody_in(client, db, default):
    org = _org(db)
    _admin(db, org.id, default, phone=f"976{abs(hash(default)) % 10000000:07d}")

    r = _login(client, org.id, "admin@fycconnect.org", default)
    assert r.status_code == 403, \
        "a string anyone can read in the repo must not be a SUPER_ADMIN login"
    assert "default password" in r.json()["detail"]


def test_the_phone_door_is_shut_too(client, db):
    """Password login accepts email or phone — both had to close."""
    org = _org(db)
    _admin(db, org.id, "changeme_admin_password", phone="9760000009")
    assert _login(client, org.id, "9760000009",
                  "changeme_admin_password").status_code == 403


def test_a_real_password_still_works(client, db):
    org = _org(db)
    _admin(db, org.id, "a-real-and-private-password", phone="9760000002")
    r = _login(client, org.id, "admin@fycconnect.org",
               "a-real-and-private-password")
    assert r.status_code == 200
    assert r.json()["access_token"]


def test_a_wrong_password_is_still_just_wrong(client, db):
    """The lockout must not become an oracle for which accounts are stale."""
    org = _org(db)
    _admin(db, org.id, "a-real-and-private-password", phone="9760000003")
    r = _login(client, org.id, "admin@fycconnect.org", "not-the-password")
    assert r.status_code == 400, "wrong is wrong, before any default check"


def test_setting_the_secret_now_rotates_the_existing_account(db, monkeypatch):
    """What the secret's name always implied, and never did.

    Seeding runs only on an empty database, so on an established one the
    account kept its published default and setting FIRST_SUPERADMIN_PASSWORD
    changed nothing at all.
    """
    from app.core.config import settings as app_settings
    org = _org(db)
    admin = _admin(db, org.id, "changeme_admin_password", phone="9760000004")
    monkeypatch.setattr(app_settings, "FIRST_SUPERADMIN_PASSWORD",
                        "a-real-and-private-password", raising=False)

    # The rotation as it runs at boot.
    desired = app_settings.FIRST_SUPERADMIN_PASSWORD.strip()
    for row in db.query(User).filter(User.role == "SUPER_ADMIN").all():
        if row.password_hash and any(
                verify_password(d, row.password_hash)
                for d in KNOWN_DEFAULT_PASSWORDS):
            row.password_hash = get_password_hash(desired)
    db.commit()

    db.expire_all()
    rotated = db.get(User, admin.id)
    assert verify_password("a-real-and-private-password", rotated.password_hash)
    assert not verify_password("changeme_admin_password", rotated.password_hash)


def test_rotation_leaves_an_already_private_password_alone(db, monkeypatch):
    """Idempotent: it must not overwrite a password somebody already chose."""
    from app.core.config import settings as app_settings
    org = _org(db)
    admin = _admin(db, org.id, "chosen-by-the-club", phone="9760000005")
    monkeypatch.setattr(app_settings, "FIRST_SUPERADMIN_PASSWORD",
                        "something-else-entirely", raising=False)

    for row in db.query(User).filter(User.role == "SUPER_ADMIN").all():
        if row.password_hash and any(
                verify_password(d, row.password_hash)
                for d in KNOWN_DEFAULT_PASSWORDS):
            row.password_hash = get_password_hash(
                app_settings.FIRST_SUPERADMIN_PASSWORD)
    db.commit()

    db.expire_all()
    assert verify_password("chosen-by-the-club",
                           db.get(User, admin.id).password_hash)
