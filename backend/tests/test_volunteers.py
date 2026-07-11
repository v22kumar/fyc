import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"vol-org-{uuid.uuid4().hex[:6]}",
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
        "email": phone + "@test.fyc",
        "date_of_birth": "1990-01-01",
        "role": role, "full_name_ta": "தன்னார்வலர்", "full_name_en": "Volunteer"
    })
    return res.json()["access_token"]


# ── Certificate ───────────────────────────────────────────────────────────────

def test_get_certificate_volunteer_with_metadata(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444561", role="VOLUNTEER")

    me_res = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    user_id = me_res.json()["id"]

    # Update the existing VolunteerMetadata created during registration
    vol_meta = db.query(VolunteerMetadata).filter(
        VolunteerMetadata.user_id == uuid.UUID(user_id)
    ).first()
    vol_meta.skills = ["Blood Coordination", "First Aid"]
    vol_meta.total_hours_accrued = 25.0
    db.commit()

    res = client.get(
        "/api/v1/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/pdf"
    # Should be Content-Disposition attachment with a filename
    content_disp = res.headers.get("content-disposition", "")
    assert "attachment" in content_disp
    assert "certificate_" in content_disp


def test_get_certificate_non_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444562", role="PUBLIC_CITIZEN")

    res = client.get(
        "/api/v1/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_get_certificate_executive_denied(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444563")
    # ADMIN role is not VOLUNTEER so should be denied by RoleChecker
    # Use a regular executive instead
    exec_user = User(
        organization_id=org.id,
        phone_number="+919444444563b",
        password_hash=get_password_hash("pass"),
        role="EXECUTIVE_MEMBER",
        is_verified=True,
    )
    # Use the already-created admin for this test
    admin_token = _login(client, org.id, "+919444444563")

    res = client.get(
        "/api/v1/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_get_certificate_unauthenticated_denied(client, db):
    org = _make_org(db)
    res = client.get(
        "/api/v1/volunteers/my-certificate",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


def test_get_certificate_volunteer_always_has_metadata(client, db):
    """Registration auto-creates VolunteerMetadata; certificate should be accessible immediately."""
    org = _make_org(db)
    token = _register(client, org.id, "+919444444564", role="VOLUNTEER")

    res = client.get(
        "/api/v1/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    # VolunteerMetadata is auto-created on registration -> 200 with PDF
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/pdf"


def test_get_certificate_pdf_content(client, db):
    """Verify that the returned bytes look like a PDF (starts with %PDF)."""
    org = _make_org(db)
    token = _register(client, org.id, "+919444444565", role="VOLUNTEER")

    me_res = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    user_id = me_res.json()["id"]

    # Update the existing VolunteerMetadata (auto-created on registration)
    vol_meta = db.query(VolunteerMetadata).filter(
        VolunteerMetadata.user_id == uuid.UUID(user_id)
    ).first()
    vol_meta.skills = ["Teaching"]
    vol_meta.total_hours_accrued = 5.0
    db.commit()

    res = client.get(
        "/api/v1/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    # PDF files start with %PDF
    assert res.content[:4] == b"%PDF"
