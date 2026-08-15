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


# ---------------------------------------------------------------------------
# When photo storage itself says no
# ---------------------------------------------------------------------------

def test_a_cloudinary_failure_is_a_sentence_not_a_500(client, db, monkeypatch):
    """Rotate the Cloudinary secret in the dashboard but not on Fly, and every
    field on /api/health/media stays green while every real upload dies.

    This is the failure members actually hit on the issue screen. It used to
    escape as a bare 500 — nothing the person holding the phone could act on,
    nothing on the health page to connect it to. It must also NOT fall back to
    container disk in production: that stores the photo somewhere a deploy
    erases, which is the same loss with a delay.
    """
    from app.routers import media

    org = _make_org(db)
    _make_executive(db, org.id, "+919555777001")
    token = _login(client, org.id, "+919555777001")

    monkeypatch.setattr(media, "_cloudinary_configured", lambda: True)
    monkeypatch.setattr(media, "_configure_cloudinary", lambda: None)

    def _refused(*a, **k):
        raise RuntimeError("401 Unauthorized - invalid signature")
    monkeypatch.setattr(media.cloudinary.uploader, "upload", _refused)

    r = client.post(
        "/api/v1/media/upload",
        files={"file": ("p.jpg", _fake_jpeg(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}",
                 "X-Organization-ID": str(org.id)},
    )

    assert r.status_code == 503, r.text
    assert "photo storage" in r.json()["detail"].lower()
    # And nothing was quietly written to disk instead.
    assert "uploads" not in r.text

    # The health page now carries the evidence — an admin reading it from a
    # phone sees the refusal, not a page of green configuration.
    last = media.storage_status()["last_upload"]
    assert last is not None and last["ok"] is False
    assert "401" in last["error"]


def test_a_working_upload_leaves_a_green_mark(client, db):
    """The other half: after a success the health page says so, so 'is it
    actually working' is answerable without asking a member to test it."""
    from app.routers import media

    org = _make_org(db)
    _make_executive(db, org.id, "+919555777002")
    token = _login(client, org.id, "+919555777002")

    r = client.post(
        "/api/v1/media/upload",
        files={"file": ("p.jpg", _fake_jpeg(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}",
                 "X-Organization-ID": str(org.id)},
    )
    assert r.status_code == 200, r.text

    last = media.storage_status()["last_upload"]
    assert last is not None and last["ok"] is True
    assert last["error"] is None
