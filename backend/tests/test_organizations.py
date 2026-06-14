import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db, slug="org-x"):
    org = Organization(id=uuid.uuid4(), slug=slug, name_ta="நிறுவனம்", name_en="Org X")
    db.add(org)
    db.commit()
    return org


def _make_superadmin(db, org_id):
    user = User(
        organization_id=org_id,
        phone_number="+910000000001",
        password_hash=get_password_hash("pass"),
        role="SUPER_ADMIN",
        is_verified=True
    )
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="அட்மின்", full_name_en="Admin"))
    db.commit()
    return user


def _login(client, org_id, phone, password):
    res = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org_id),
        "username": phone,
        "password": password
    })
    return res.json()["access_token"]


def test_list_organizations_public(client, db):
    """Public endpoint returns active organizations."""
    _make_org(db, "list-test-org")
    res = client.get("/api/v1/organizations")
    assert res.status_code == 200
    slugs = [o["slug"] for o in res.json()]
    assert "list-test-org" in slugs


def test_get_organization_by_id(client, db):
    org = _make_org(db, "get-test-org")
    res = client.get(f"/api/v1/organizations/{org.id}")
    assert res.status_code == 200
    assert res.json()["slug"] == "get-test-org"


def test_get_organization_not_found(client, db):
    res = client.get(f"/api/v1/organizations/{uuid.uuid4()}")
    assert res.status_code == 404


def test_create_organization_superadmin(client, db):
    org = _make_org(db, "base-org")
    superadmin = _make_superadmin(db, org.id)
    token = _login(client, org.id, superadmin.phone_number, "pass")

    res = client.post(
        "/api/v1/organizations",
        json={"slug": "new-club", "name_ta": "புதிய கிளப்", "name_en": "New Club"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    assert res.json()["slug"] == "new-club"


def test_create_organization_duplicate_slug(client, db):
    org = _make_org(db, "dup-org")
    superadmin = _make_superadmin(db, org.id)
    token = _login(client, org.id, superadmin.phone_number, "pass")

    client.post(
        "/api/v1/organizations",
        json={"slug": "dup-org-2", "name_ta": "நகல்", "name_en": "Dup"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    res = client.post(
        "/api/v1/organizations",
        json={"slug": "dup-org-2", "name_ta": "நகல்", "name_en": "Dup"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 400


def test_create_organization_non_admin_denied(client, db):
    org = _make_org(db, "non-admin-org")
    res = client.post(
        "/api/v1/auth/register",
        json={"organization_id": str(org.id), "phone_number": "+919000000001",
              "role": "PUBLIC_CITIZEN", "full_name_ta": "மக்கள்", "full_name_en": "Citizen"}
    )
    token = res.json()["access_token"]

    res = client.post(
        "/api/v1/organizations",
        json={"slug": "denied-org", "name_ta": "நிறுவனம்", "name_en": "Denied"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 403
