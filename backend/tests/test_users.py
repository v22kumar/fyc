import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"usr-org-{uuid.uuid4().hex[:6]}",
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
        "role": role, "full_name_ta": "பயனர்", "full_name_en": "User"
    })
    return res.json()["access_token"]


# ── List Users ────────────────────────────────────────────────────────────────

def test_list_users_executive(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444541")
    exec_token = _login(client, org.id, "+919444444541")

    _register(client, org.id, "+919444444542", role="VOLUNTEER")
    _register(client, org.id, "+919444444543", role="VOLUNTEER")

    res = client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    data = res.json()
    assert len(data) >= 3  # includes the executive itself


def test_list_users_filter_by_role(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444544")
    exec_token = _login(client, org.id, "+919444444544")

    _register(client, org.id, "+919444444545", role="VOLUNTEER")
    _register(client, org.id, "+919444444546", role="PUBLIC_CITIZEN")

    res = client.get(
        "/api/v1/users?role=VOLUNTEER",
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    for user in res.json():
        assert user["role"] == "VOLUNTEER"


def test_list_users_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444547", role="VOLUNTEER")

    res = client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_list_users_citizen_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444548", role="PUBLIC_CITIZEN")

    res = client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_list_users_unauthenticated_denied(client, db):
    org = _make_org(db)
    res = client.get(
        "/api/v1/users",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 401


# ── Volunteer Certificate ─────────────────────────────────────────────────────

def test_get_certificate_non_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444549", role="PUBLIC_CITIZEN")

    res = client.get(
        "/api/v1/users/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_get_certificate_volunteer_returns_pdf(client, db):
    """Registration auto-creates VolunteerMetadata; certificate should always work for a VOLUNTEER."""
    org = _make_org(db)
    token = _register(client, org.id, "+919444444550", role="VOLUNTEER")

    res = client.get(
        "/api/v1/users/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    # VolunteerMetadata is created on registration, so we should get a PDF
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/pdf"


def test_get_certificate_volunteer_with_hours(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444551", role="VOLUNTEER")

    # Look up the user id from /me endpoint
    me_res = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    user_id = me_res.json()["id"]

    # Update the existing VolunteerMetadata (created during registration)
    vol_meta = db.query(VolunteerMetadata).filter(
        VolunteerMetadata.user_id == uuid.UUID(user_id)
    ).first()
    vol_meta.total_hours_accrued = 10.5
    vol_meta.skills = ["First Aid"]
    db.commit()

    res = client.get(
        "/api/v1/users/volunteers/my-certificate",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/pdf"
