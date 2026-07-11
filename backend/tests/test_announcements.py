import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"ann-org-{uuid.uuid4().hex[:6]}",
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
        "email": phone + "@test.fyc",
        "date_of_birth": "1990-01-01",
        "role": role, "full_name_ta": "பயனர்", "full_name_en": "User"
    })
    return res.json()["access_token"]


def _ann_payload(**overrides):
    payload = {
        "title_ta": "அறிவிப்பு தலைப்பு",
        "title_en": "Announcement Title",
        "body_ta": "அறிவிப்பு உடல்",
        "body_en": "Announcement Body",
        "category": "GENERAL",
        "is_pinned": False,
    }
    payload.update(overrides)
    return payload


# ── Create ────────────────────────────────────────────────────────────────────

def test_create_announcement_executive(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444441")
    token = _login(client, org.id, "+919444444441")

    res = client.post(
        "/api/v1/announcements",
        json=_ann_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["title_en"] == "Announcement Title"
    assert data["category"] == "GENERAL"
    assert data["is_pinned"] is False


def test_create_announcement_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444442", role="VOLUNTEER")

    res = client.post(
        "/api/v1/announcements",
        json=_ann_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_create_announcement_citizen_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444443", role="PUBLIC_CITIZEN")

    res = client.post(
        "/api/v1/announcements",
        json=_ann_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


# ── List / Get ────────────────────────────────────────────────────────────────

def test_list_announcements_public(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444444")
    token = _login(client, org.id, "+919444444444")

    client.post("/api/v1/announcements", json=_ann_payload(title_en="First"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    client.post("/api/v1/announcements", json=_ann_payload(title_en="Second", category="ALERT"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    # Public listing requires no auth
    res = client.get("/api/v1/announcements", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_list_announcements_filter_by_category(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444445")
    token = _login(client, org.id, "+919444444445")

    client.post("/api/v1/announcements", json=_ann_payload(title_en="Gen", category="GENERAL"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    client.post("/api/v1/announcements", json=_ann_payload(title_en="Alert", category="ALERT"),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/announcements?category=ALERT", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["category"] == "ALERT"


def test_get_announcement_not_found(client, db):
    org = _make_org(db)
    res = client.get(
        f"/api/v1/announcements/{uuid.uuid4()}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


# ── Update ────────────────────────────────────────────────────────────────────

def test_update_announcement(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444446")
    token = _login(client, org.id, "+919444444446")

    create_res = client.post(
        "/api/v1/announcements", json=_ann_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    ann_id = create_res.json()["id"]

    patch_res = client.patch(
        f"/api/v1/announcements/{ann_id}",
        json={"title_en": "Updated Title", "is_pinned": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["title_en"] == "Updated Title"
    assert patch_res.json()["is_pinned"] is True


# ── Delete ────────────────────────────────────────────────────────────────────

def test_delete_announcement_admin_only(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444447")
    exec_token = _login(client, org.id, "+919444444447")

    create_res = client.post(
        "/api/v1/announcements", json=_ann_payload(),
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    ann_id = create_res.json()["id"]

    # Executive cannot delete (only ADMIN/SUPER_ADMIN can)
    del_res = client.delete(
        f"/api/v1/announcements/{ann_id}",
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    assert del_res.status_code == 403


def test_delete_announcement_by_admin(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444448")
    admin_token = _login(client, org.id, "+919444444448")

    create_res = client.post(
        "/api/v1/announcements", json=_ann_payload(),
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)},
    )
    ann_id = create_res.json()["id"]

    del_res = client.delete(
        f"/api/v1/announcements/{ann_id}",
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)},
    )
    assert del_res.status_code == 204

    # Confirm it's gone
    get_res = client.get(
        f"/api/v1/announcements/{ann_id}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert get_res.status_code == 404
