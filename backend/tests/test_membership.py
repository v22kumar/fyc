import uuid
from datetime import datetime, timedelta, timezone
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"mem-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, role):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role=role, is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="பயனர்", full_name_en="User"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


def _future_date(days=365):
    return (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()


def test_generate_membership_card(client, db):
    org = _make_org(db)
    admin = _make_user(db, org.id, "+919444444441", "ADMIN")
    member = _make_user(db, org.id, "+919444444442", "CLUB_MEMBER")

    admin_token = _login(client, org.id, "+919444444441")
    res = client.post(
        "/api/v1/membership/generate",
        json={"user_id": str(member.id), "expires_at": _future_date()},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    data = res.json()
    assert data["user_id"] == str(member.id)
    assert data["status"] == "ACTIVE"
    assert data["membership_number"].startswith("FYC-")
    assert "FYC:" in data["qr_code_payload"]


def test_generate_card_duplicate(client, db):
    org = _make_org(db)
    admin = _make_user(db, org.id, "+919444444443", "ADMIN")
    member = _make_user(db, org.id, "+919444444444", "CLUB_MEMBER")

    admin_token = _login(client, org.id, "+919444444443")
    headers = {"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}

    client.post("/api/v1/membership/generate",
                json={"user_id": str(member.id), "expires_at": _future_date()}, headers=headers)
    res = client.post("/api/v1/membership/generate",
                      json={"user_id": str(member.id), "expires_at": _future_date()}, headers=headers)
    assert res.status_code == 400


def test_generate_card_cross_org_denied(client, db):
    """Admin cannot issue a card to a user in a different organization."""
    org_a = _make_org(db)
    org_b = Organization(id=uuid.uuid4(), slug=f"mem-org-b-{uuid.uuid4().hex[:6]}",
                         name_ta="நிறுவனம் பி", name_en="Org B")
    db.add(org_b)
    db.commit()

    admin = _make_user(db, org_a.id, "+919444444445", "ADMIN")
    other_member = _make_user(db, org_b.id, "+919444444446", "CLUB_MEMBER")

    admin_token = _login(client, org_a.id, "+919444444445")
    res = client.post(
        "/api/v1/membership/generate",
        json={"user_id": str(other_member.id), "expires_at": _future_date()},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org_a.id)}
    )
    assert res.status_code == 404


def test_non_admin_cannot_generate_card(client, db):
    org = _make_org(db)
    member = _make_user(db, org.id, "+919444444447", "CLUB_MEMBER")
    token = _login(client, org.id, "+919444444447")

    res = client.post(
        "/api/v1/membership/generate",
        json={"user_id": str(member.id), "expires_at": _future_date()},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 403


def test_get_my_card(client, db):
    org = _make_org(db)
    admin = _make_user(db, org.id, "+919444444448", "ADMIN")
    member = _make_user(db, org.id, "+919444444449", "CLUB_MEMBER")

    admin_token = _login(client, org.id, "+919444444448")
    client.post(
        "/api/v1/membership/generate",
        json={"user_id": str(member.id), "expires_at": _future_date()},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}
    )

    member_token = _login(client, org.id, "+919444444449")
    res = client.get(
        "/api/v1/membership/my-card",
        headers={"Authorization": f"Bearer {member_token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 200
    assert res.json()["status"] == "ACTIVE"


def test_get_my_card_not_found(client, db):
    org = _make_org(db)
    member = _make_user(db, org.id, "+919444444450", "CLUB_MEMBER")
    token = _login(client, org.id, "+919444444450")

    res = client.get(
        "/api/v1/membership/my-card",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 404


def test_verify_membership_card(client, db):
    org = _make_org(db)
    admin = _make_user(db, org.id, "+919444444451", "ADMIN")
    member = _make_user(db, org.id, "+919444444452", "CLUB_MEMBER")

    admin_token = _login(client, org.id, "+919444444451")
    generate_res = client.post(
        "/api/v1/membership/generate",
        json={"user_id": str(member.id), "expires_at": _future_date()},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}
    )
    membership_number = generate_res.json()["membership_number"]

    verify_res = client.get(f"/api/v1/membership/verify/{membership_number}")
    assert verify_res.status_code == 200
    assert verify_res.json()["membership_number"] == membership_number


def test_verify_nonexistent_card(client, db):
    res = client.get("/api/v1/membership/verify/FYC-9999-9999")
    assert res.status_code == 404


def test_list_membership_cards_admin(client, db):
    """Admin can list all cards scoped to their organization."""
    org = _make_org(db)
    admin = _make_user(db, org.id, "+919444444460", "ADMIN")
    m1 = _make_user(db, org.id, "+919444444461", "CLUB_MEMBER")
    m2 = _make_user(db, org.id, "+919444444462", "CLUB_MEMBER")

    admin_token = _login(client, org.id, "+919444444460")
    headers = {"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}

    client.post("/api/v1/membership/generate",
                json={"user_id": str(m1.id), "expires_at": _future_date()}, headers=headers)
    client.post("/api/v1/membership/generate",
                json={"user_id": str(m2.id), "expires_at": _future_date()}, headers=headers)

    res = client.get("/api/v1/membership/list", headers=headers)
    assert res.status_code == 200
    numbers = [c["membership_number"] for c in res.json()]
    assert any("FYC-" in n for n in numbers)


def test_list_membership_cards_non_admin_denied(client, db):
    """Non-admin cannot access the membership list."""
    org = _make_org(db)
    member = _make_user(db, org.id, "+919444444463", "CLUB_MEMBER")
    token = _login(client, org.id, "+919444444463")

    res = client.get(
        "/api/v1/membership/list",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 403
