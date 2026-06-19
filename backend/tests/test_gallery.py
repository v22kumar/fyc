import uuid
from datetime import datetime, timedelta, timezone
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"gal-org-{uuid.uuid4().hex[:6]}",
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
        "role": role, "full_name_ta": "பயனர்", "full_name_en": "User"
    })
    return res.json()["access_token"]


def _create_event(client, org_id, token):
    now = datetime.now(timezone.utc)
    return client.post(
        "/api/v1/events",
        json={
            "title_ta": "நிகழ்வு",
            "title_en": "Event",
            "description_ta": "விவரம்",
            "description_en": "Description",
            "event_start": (now + timedelta(hours=1)).isoformat(),
            "event_end": (now + timedelta(hours=3)).isoformat(),
        },
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)},
    ).json()["id"]


# ── Upload photo ──────────────────────────────────────────────────────────────

def test_upload_photo_authenticated(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444481")
    exec_token = _login(client, org.id, "+919444444481")
    event_id = _create_event(client, org.id, exec_token)

    res = client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/photo.jpg", "caption_en": "A photo"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["photo_url"] == "https://example.com/photo.jpg"
    assert data["caption_en"] == "A photo"
    assert data["event_id"] == event_id


def test_upload_photo_unauthenticated_denied(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444482")
    exec_token = _login(client, org.id, "+919444444482")
    event_id = _create_event(client, org.id, exec_token)

    res = client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/photo.jpg"},
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


def test_upload_photo_event_not_found(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444483")
    exec_token = _login(client, org.id, "+919444444483")

    res = client.post(
        f"/api/v1/gallery/events/{uuid.uuid4()}",
        json={"photo_url": "https://example.com/photo.jpg"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


# ── List photos ───────────────────────────────────────────────────────────────

def test_list_photos_public(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444484")
    exec_token = _login(client, org.id, "+919444444484")
    event_id = _create_event(client, org.id, exec_token)

    client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/p1.jpg"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/p2.jpg"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )

    res = client.get("/api/v1/gallery", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_list_photos_for_event(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444485")
    exec_token = _login(client, org.id, "+919444444485")
    event_id = _create_event(client, org.id, exec_token)

    client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/photo.jpg"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )

    res = client.get(
        f"/api/v1/gallery/events/{event_id}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    photos = res.json()
    assert len(photos) == 1
    assert photos[0]["event_id"] == event_id


# ── Delete photo ──────────────────────────────────────────────────────────────

def test_delete_photo_by_uploader(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444486")
    exec_token = _login(client, org.id, "+919444444486")
    event_id = _create_event(client, org.id, exec_token)

    photo_res = client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/photo.jpg"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    photo_id = photo_res.json()["id"]

    del_res = client.delete(
        f"/api/v1/gallery/{photo_id}",
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    assert del_res.status_code == 204


def test_delete_photo_by_non_owner_denied(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444487")
    exec_token = _login(client, org.id, "+919444444487")
    event_id = _create_event(client, org.id, exec_token)

    photo_res = client.post(
        f"/api/v1/gallery/events/{event_id}",
        json={"photo_url": "https://example.com/photo.jpg"},
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    photo_id = photo_res.json()["id"]

    # Another volunteer tries to delete
    vol_token = _register(client, org.id, "+919444444488", role="VOLUNTEER")
    del_res = client.delete(
        f"/api/v1/gallery/{photo_id}",
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)},
    )
    assert del_res.status_code == 403
