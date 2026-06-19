import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"dir-org-{uuid.uuid4().hex[:6]}",
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


def _contact_payload(**overrides):
    payload = {
        "category": "POLICE",
        "name_ta": "காவல் நிலையம்",
        "name_en": "Police Station",
        "phone_primary": "100",
        "is_active": True,
        "display_order": 1,
    }
    payload.update(overrides)
    return payload


# ── Create ────────────────────────────────────────────────────────────────────

def test_create_contact_admin(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444471")
    token = _login(client, org.id, "+919444444471")

    res = client.post(
        "/api/v1/directory",
        json=_contact_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name_en"] == "Police Station"
    assert data["category"] == "POLICE"
    assert data["phone_primary"] == "100"


def test_create_contact_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444472", role="VOLUNTEER")

    res = client.post(
        "/api/v1/directory",
        json=_contact_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_create_contact_unauthenticated_denied(client, db):
    org = _make_org(db)
    res = client.post(
        "/api/v1/directory",
        json=_contact_payload(),
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


# ── List / Get ────────────────────────────────────────────────────────────────

def test_list_contacts_public(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444473")
    token = _login(client, org.id, "+919444444473")

    client.post("/api/v1/directory", json=_contact_payload(name_en="Police", phone_primary="100"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    client.post("/api/v1/directory", json=_contact_payload(name_en="Fire", category="FIRE", phone_primary="101"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/directory", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_list_contacts_filter_by_category(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444474")
    token = _login(client, org.id, "+919444444474")

    client.post("/api/v1/directory", json=_contact_payload(name_en="Police", phone_primary="100"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    client.post("/api/v1/directory", json=_contact_payload(name_en="Ambulance", category="AMBULANCE", phone_primary="108"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/directory?category=AMBULANCE", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["category"] == "AMBULANCE"


def test_get_contact_not_found(client, db):
    org = _make_org(db)
    res = client.get(
        f"/api/v1/directory/{uuid.uuid4()}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


# ── Update ────────────────────────────────────────────────────────────────────

def test_update_contact(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444475")
    token = _login(client, org.id, "+919444444475")

    create_res = client.post(
        "/api/v1/directory", json=_contact_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    contact_id = create_res.json()["id"]

    patch_res = client.patch(
        f"/api/v1/directory/{contact_id}",
        json={"name_en": "Updated Police Station", "phone_primary": "100"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["name_en"] == "Updated Police Station"


# ── Delete (soft) ─────────────────────────────────────────────────────────────

def test_delete_contact_soft_removes_from_list(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444476")
    token = _login(client, org.id, "+919444444476")

    create_res = client.post(
        "/api/v1/directory", json=_contact_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    contact_id = create_res.json()["id"]

    del_res = client.delete(
        f"/api/v1/directory/{contact_id}",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert del_res.status_code == 204

    # Should no longer appear in public list (soft-deleted = is_active=False)
    list_res = client.get("/api/v1/directory", headers={"X-Organization-ID": str(org.id)})
    ids = [c["id"] for c in list_res.json()]
    assert contact_id not in ids
