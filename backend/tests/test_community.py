import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"com-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_admin(db, org_id, phone):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="நிர்வாகன்", full_name_en="Admin"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


def _register(client, org_id, phone, role="VOLUNTEER"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id), "phone_number": phone,
        "role": role, "full_name_ta": "பயனர்", "full_name_en": "User"
    })
    return res.json()["access_token"]


def _profile_payload(**overrides):
    payload = {
        "category": "carpenter",
        "business_name_en": "Good Carpentry",
        "business_name_ta": "நல்ல தச்சர்",
        "description_en": "Quality woodwork",
        "description_ta": "தரமான மர வேலை",
        "contact_phone": "9876543210",
        "service_area": "Nagercoil",
        "years_experience": 5,
    }
    payload.update(overrides)
    return payload


# ── Register ──────────────────────────────────────────────────────────────────

def test_register_community_profile(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444451", role="VOLUNTEER")

    res = client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["category"] == "carpenter"
    assert data["business_name_en"] == "Good Carpentry"
    assert data["is_verified"] is False


def test_register_profile_duplicate_rejected(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444452", role="VOLUNTEER")

    client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    # Second registration for same user should fail
    res = client.post(
        "/api/v1/community/register",
        json=_profile_payload(category="electrician"),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 400


def test_register_profile_unauthenticated_denied(client, db):
    org = _make_org(db)
    res = client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


# ── List / Search ─────────────────────────────────────────────────────────────

def test_list_community_profiles_public(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444453", role="VOLUNTEER")
    client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )

    res = client.get("/api/v1/community", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) >= 1


def test_search_by_category(client, db):
    org = _make_org(db)
    t1 = _register(client, org.id, "+919444444454", role="VOLUNTEER")
    t2 = _register(client, org.id, "+919444444455", role="VOLUNTEER")

    client.post(
        "/api/v1/community/register",
        json=_profile_payload(category="carpenter"),
        headers={"Authorization": f"Bearer {t1}", "X-Organization-ID": str(org.id)},
    )
    client.post(
        "/api/v1/community/register",
        json=_profile_payload(category="electrician"),
        headers={"Authorization": f"Bearer {t2}", "X-Organization-ID": str(org.id)},
    )

    res = client.get("/api/v1/community?category=carpenter", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["category"] == "carpenter"


# ── My Profile ────────────────────────────────────────────────────────────────

def test_get_my_profile(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444456", role="VOLUNTEER")

    client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )

    res = client.get(
        "/api/v1/community/me",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert res.json()["category"] == "carpenter"


def test_get_my_profile_not_found(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444457", role="VOLUNTEER")

    res = client.get(
        "/api/v1/community/me",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


def test_update_my_profile(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444458", role="VOLUNTEER")

    client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )

    patch_res = client.patch(
        "/api/v1/community/me",
        json={"years_experience": 10, "is_available": False},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["years_experience"] == 10
    assert patch_res.json()["is_available"] is False


# ── Admin verify / delete ─────────────────────────────────────────────────────

def test_verify_profile_admin(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444459")
    admin_token = _login(client, org.id, "+919444444459")

    user_token = _register(client, org.id, "+919444444460", role="VOLUNTEER")
    create_res = client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {user_token}", "X-Organization-ID": str(org.id)},
    )
    profile_id = create_res.json()["id"]

    verify_res = client.patch(
        f"/api/v1/community/{profile_id}/verify",
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)},
    )
    assert verify_res.status_code == 200
    assert verify_res.json()["is_verified"] is True


def test_delete_profile_admin(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444461")
    admin_token = _login(client, org.id, "+919444444461")

    user_token = _register(client, org.id, "+919444444462", role="VOLUNTEER")
    create_res = client.post(
        "/api/v1/community/register",
        json=_profile_payload(),
        headers={"Authorization": f"Bearer {user_token}", "X-Organization-ID": str(org.id)},
    )
    profile_id = create_res.json()["id"]

    del_res = client.delete(
        f"/api/v1/community/{profile_id}",
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)},
    )
    assert del_res.status_code == 204
