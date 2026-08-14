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


def test_firebase_verify_phone_success(client, db, monkeypatch):
    """Proving phone via valid Firebase token sets phone and marks verified."""
    from app.services import firebase_phone_auth

    org = _org(db)
    user, token = _user_with_token(client, db, org, phone=None)

    # Mock the cryptographic verification of the Firebase ID token
    mock_payload = {
        "phone_number": "+919876543215",
        "uid": "firebase-uid-12345",
        "iss": "https://securetoken.google.com/fyc-connect-25ab0",
    }
    monkeypatch.setattr(
        firebase_phone_auth,
        "verify_firebase_id_token",
        lambda id_token: mock_payload if id_token == "valid-firebase-token" else (_ for _ in ()).throw(ValueError("bad token")),
    )

    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    res = client.post(
        "/api/v1/auth/firebase/verify-phone",
        json={"id_token": "valid-firebase-token"},
        headers=headers,
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["claimed"] is True
    assert data["phone_number"] == "+919876543215"
    assert data["phone_verified"] is True
    assert data["conflict"] is False

    db.refresh(user)
    assert user.phone_number == "+919876543215"
    assert user.phone_verified_at is not None


def test_firebase_verify_phone_conflict(client, db, monkeypatch):
    """If another member already proved this phone, return conflict=True."""
    from app.services import firebase_phone_auth

    org = _org(db)
    _owner, _ = _user_with_token(client, db, org, phone="+919876543216", is_verified=True)
    claimant, token = _user_with_token(client, db, org, phone=None)

    mock_payload = {
        "phone_number": "+919876543216",
        "uid": "firebase-uid-9999",
    }
    monkeypatch.setattr(
        firebase_phone_auth,
        "verify_firebase_id_token",
        lambda id_token: mock_payload,
    )

    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    res = client.post(
        "/api/v1/auth/firebase/verify-phone",
        json={"id_token": "token-for-owned-phone"},
        headers=headers,
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["claimed"] is False
    assert data["conflict"] is True
    assert "already verified" in data["reason"]

    db.refresh(claimant)
    assert claimant.phone_number is None
