import uuid
import pytest
from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.services.account_claims import mark_phone_verified


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"cl-{uuid.uuid4().hex[:6]}",
                       name_ta="கிளப்", name_en="Club")
    db.add(org)
    db.commit()
    return org


def _user_with_token(client, db, org, phone=None, email=None, is_verified=True):
    u = User(
        organization_id=org.id,
        phone_number=phone,
        email=email or f"user-{uuid.uuid4().hex[:6]}@example.com",
        role="PUBLIC_CITIZEN",
        is_verified=is_verified,
        password_hash=get_password_hash("pass1234"),
    )
    if phone and is_verified:
        mark_phone_verified(db, u)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="Test User", full_name_ta="டெஸ்ட்"))
    db.commit()

    login = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id),
        "username": u.email,
        "password": "pass1234",
    })
    token = login.json()["access_token"]
    return u, token


def test_claim_phone_attaches_unverified_and_triggers_otp(client, db, monkeypatch):
    """Claiming an available number attaches it as unverified and mints OTP."""
    from app.routers import auth as auth_router

    org = _org(db)
    user, token = _user_with_token(client, db, org, phone=None)

    monkeypatch.setattr(auth_router, "deliver_otp", lambda *a, **k: {"sms": True})

    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    res = client.post("/api/v1/auth/google/claim-phone",
                      json={"phone_number": "9876543210"},
                      headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["claimed"] is True
    assert data["phone_number"] == "+919876543210"
    assert data["phone_verified"] is False
    assert data["otp_sent"] is True
    assert data["otp_verification_id"] is not None

    db.refresh(user)
    assert user.phone_number == "+919876543210"
    assert user.phone_verified_at is None


def test_claim_phone_conflict_does_not_abort_session(client, db):
    """When a number is already verified by another member, return 200 conflict=True."""
    org = _org(db)
    _owner, _ = _user_with_token(client, db, org, phone="+919876543211", is_verified=True)
    claimant, token = _user_with_token(client, db, org, phone=None)

    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    res = client.post("/api/v1/auth/google/claim-phone",
                      json={"phone_number": "+919876543211"},
                      headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["claimed"] is False
    assert data["conflict"] is True
    assert "already attached" in data["reason"]

    db.refresh(claimant)
    assert claimant.phone_number is None


def test_verify_claimed_phone_marks_verified(client, db, monkeypatch):
    """Answering the OTP code on the claimed phone marks the phone verified."""
    from app.routers import auth as auth_router

    org = _org(db)
    user, token = _user_with_token(client, db, org, phone=None)

    sent_code = {}
    monkeypatch.setattr(auth_router, "deliver_otp",
                        lambda phone, otp, email=None: (sent_code.update(code=otp), {"sms": True})[1])

    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    claim_res = client.post("/api/v1/auth/google/claim-phone",
                            json={"phone_number": "+919876543212"},
                            headers=headers)
    vid = claim_res.json()["otp_verification_id"]

    verify_res = client.post("/api/v1/auth/google/claim-phone/verify",
                             json={"verification_id": vid, "otp_code": sent_code["code"]},
                             headers=headers)
    assert verify_res.status_code == 200, verify_res.text
    data = verify_res.json()
    assert data["claimed"] is True
    assert data["phone_verified"] is True

    db.refresh(user)
    assert user.phone_number == "+919876543212"
    assert user.phone_verified_at is not None
