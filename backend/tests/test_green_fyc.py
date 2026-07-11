import uuid
from datetime import date
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"grn-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_executive(db, org_id, phone):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role="EXECUTIVE_MEMBER", is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="நிர்வாகி", full_name_en="Executive"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


def _register(client, org_id, phone, role="VOLUNTEER"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id), "phone_number": phone,
        "email": phone + "@test.fyc",
        "date_of_birth": "1990-01-01",
        "role": role, "full_name_ta": "பயனர்", "full_name_en": "User"
    })
    return res.json()["access_token"]


def _drive_payload(**overrides):
    payload = {
        "title_ta": "மர நடவு இயக்கம்",
        "title_en": "Tree Plantation Drive",
        "drive_date": str(date.today()),
        "target_count": 100,
        "is_active": True,
    }
    payload.update(overrides)
    return payload


def _tree_payload(drive_id=None, **overrides):
    payload = {
        "species_en": "Neem",
        "species_ta": "வேம்பு",
        "planted_date": str(date.today()),
    }
    if drive_id:
        payload["drive_id"] = str(drive_id)
    payload.update(overrides)
    return payload


# ── Drives ────────────────────────────────────────────────────────────────────

def test_create_drive_executive(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444491")
    token = _login(client, org.id, "+919444444491")

    res = client.post(
        "/api/v1/green/drives",
        json=_drive_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["title_en"] == "Tree Plantation Drive"
    assert data["target_count"] == 100
    assert data["tree_count"] == 0


def test_create_drive_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444492", role="VOLUNTEER")

    res = client.post(
        "/api/v1/green/drives",
        json=_drive_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_list_drives_public(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444493")
    token = _login(client, org.id, "+919444444493")

    client.post("/api/v1/green/drives", json=_drive_payload(title_en="Drive 1"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    client.post("/api/v1/green/drives", json=_drive_payload(title_en="Drive 2"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/green/drives", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_get_drive_not_found(client, db):
    org = _make_org(db)
    res = client.get(
        f"/api/v1/green/drives/{uuid.uuid4()}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


def test_update_drive(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444494")
    token = _login(client, org.id, "+919444444494")

    create_res = client.post(
        "/api/v1/green/drives", json=_drive_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    drive_id = create_res.json()["id"]

    patch_res = client.patch(
        f"/api/v1/green/drives/{drive_id}",
        json={"target_count": 200, "is_active": False},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["target_count"] == 200
    assert patch_res.json()["is_active"] is False


# ── Trees ─────────────────────────────────────────────────────────────────────

def test_register_tree_authenticated(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444495", role="VOLUNTEER")

    res = client.post(
        "/api/v1/green/trees",
        json=_tree_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["species_en"] == "Neem"
    assert data["status"] == "PLANTED"


def test_register_tree_unauthenticated_denied(client, db):
    org = _make_org(db)
    res = client.post(
        "/api/v1/green/trees",
        json=_tree_payload(),
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


def test_register_tree_linked_to_drive(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444496")
    exec_token = _login(client, org.id, "+919444444496")

    drive_id = client.post(
        "/api/v1/green/drives", json=_drive_payload(),
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    ).json()["id"]

    vol_token = _register(client, org.id, "+919444444497", role="VOLUNTEER")
    res = client.post(
        "/api/v1/green/trees",
        json=_tree_payload(drive_id=drive_id),
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    assert res.json()["drive_id"] == drive_id


def test_list_trees_public(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444498", role="VOLUNTEER")

    client.post("/api/v1/green/trees", json=_tree_payload(),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/green/trees", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) >= 1


def test_update_tree_growth_by_registrant(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444499", role="VOLUNTEER")

    tree_id = client.post(
        "/api/v1/green/trees", json=_tree_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    ).json()["id"]

    patch_res = client.patch(
        f"/api/v1/green/trees/{tree_id}/growth",
        json={"growth_photo_url": "https://example.com/growth.jpg", "status": "GROWING"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["status"] == "GROWING"
    assert patch_res.json()["growth_photo_url"] == "https://example.com/growth.jpg"


def test_update_tree_growth_by_non_owner_denied(client, db):
    org = _make_org(db)
    owner_token = _register(client, org.id, "+919444444500", role="VOLUNTEER")
    other_token = _register(client, org.id, "+919444444501", role="VOLUNTEER")

    tree_id = client.post(
        "/api/v1/green/trees", json=_tree_payload(),
        headers={"Authorization": f"Bearer {owner_token}", "X-Organization-ID": str(org.id)},
    ).json()["id"]

    patch_res = client.patch(
        f"/api/v1/green/trees/{tree_id}/growth",
        json={"growth_photo_url": "https://example.com/g.jpg", "status": "MATURE"},
        headers={"Authorization": f"Bearer {other_token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 403


# ── Stats ─────────────────────────────────────────────────────────────────────

def test_get_stats(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444502", role="VOLUNTEER")

    client.post("/api/v1/green/trees", json=_tree_payload(),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/green/stats", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    data = res.json()
    assert "total_planted" in data
    assert "drives_count" in data
    assert data["total_planted"] >= 1
