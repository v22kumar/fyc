import io
import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"med-org-{uuid.uuid4().hex[:6]}",
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


def _fake_jpeg(size_bytes=1024):
    """Return a minimal JPEG-like bytes object (fake content for testing)."""
    # JPEG magic bytes followed by filler
    data = b"\xff\xd8\xff\xe0" + b"\x00" * (size_bytes - 4)
    return io.BytesIO(data)


def _fake_png(size_bytes=1024):
    """Return a minimal PNG-like bytes object (fake content for testing)."""
    # PNG magic bytes followed by filler
    data = b"\x89PNG\r\n\x1a\n" + b"\x00" * (size_bytes - 8)
    return io.BytesIO(data)


# ── Upload ────────────────────────────────────────────────────────────────────

def test_upload_jpeg_authenticated(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444511")
    token = _login(client, org.id, "+919444444511")

    res = client.post(
        "/api/v1/media/upload",
        files={"file": ("photo.jpg", _fake_jpeg(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    data = res.json()
    assert "url" in data
    assert "filename" in data
    assert data["filename"].endswith(".jpg")


def test_upload_png_authenticated(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444512")
    token = _login(client, org.id, "+919444444512")

    res = client.post(
        "/api/v1/media/upload",
        files={"file": ("image.png", _fake_png(), "image/png")},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["filename"].endswith(".png")


def test_upload_unauthenticated_denied(client, db):
    org = _make_org(db)
    res = client.post(
        "/api/v1/media/upload",
        files={"file": ("photo.jpg", _fake_jpeg(), "image/jpeg")},
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


def test_upload_unsupported_type_rejected(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444513")
    token = _login(client, org.id, "+919444444513")

    pdf_content = io.BytesIO(b"%PDF-1.4 fake pdf content")
    res = client.post(
        "/api/v1/media/upload",
        files={"file": ("document.pdf", pdf_content, "application/pdf")},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 415


def test_upload_volunteer_can_upload(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444514", role="VOLUNTEER")

    res = client.post(
        "/api/v1/media/upload",
        files={"file": ("photo.jpg", _fake_jpeg(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    # Any authenticated user should be able to upload
    assert res.status_code == 200


def test_upload_url_path_returned(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444515", role="VOLUNTEER")

    res = client.post(
        "/api/v1/media/upload",
        files={"file": ("mypic.jpg", _fake_jpeg(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    data = res.json()
    # URL should start with /uploads/
    assert data["url"].startswith("/uploads/")
