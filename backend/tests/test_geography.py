import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.models.geography import GeographicNode, GeoLevel
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"geo-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_admin(db, org_id, phone="+910000000010"):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="அட்மின்", full_name_en="Admin"))
    db.commit()
    return user


def _token(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


def test_list_geography_empty(client, db):
    res = client.get("/api/v1/geography")
    assert res.status_code == 200
    assert isinstance(res.json(), list)


def test_create_geography_node_admin(client, db):
    org = _make_org(db)
    admin = _make_admin(db, org.id, "+910000000011")
    token = _token(client, org.id, "+910000000011")

    res = client.post(
        "/api/v1/geography",
        json={"level": "DISTRICT", "name_ta": "கன்னியாகுமரி", "name_en": "Kanyakumari"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    data = res.json()
    assert data["level"] == "DISTRICT"
    assert data["name_en"] == "Kanyakumari"


def test_create_geography_child_node(client, db):
    org = _make_org(db)
    admin = _make_admin(db, org.id, "+910000000012")
    token = _token(client, org.id, "+910000000012")

    district_res = client.post(
        "/api/v1/geography",
        json={"level": "DISTRICT", "name_ta": "நெல்லை", "name_en": "Tirunelveli"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    district_id = district_res.json()["id"]

    taluk_res = client.post(
        "/api/v1/geography",
        json={"parent_id": district_id, "level": "TALUK", "name_ta": "நாகர்கோவில்", "name_en": "Nagercoil"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert taluk_res.status_code == 201
    assert taluk_res.json()["parent_id"] == district_id


def test_list_geography_by_level(client, db):
    org = _make_org(db)
    admin = _make_admin(db, org.id, "+910000000013")
    token = _token(client, org.id, "+910000000013")

    client.post(
        "/api/v1/geography",
        json={"level": "STATE", "name_ta": "தமிழ்நாடு", "name_en": "Tamil Nadu"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    res = client.get("/api/v1/geography?level=STATE")
    assert res.status_code == 200
    assert all(n["level"] == "STATE" for n in res.json())


def test_get_geography_node_not_found(client, db):
    res = client.get(f"/api/v1/geography/{uuid.uuid4()}")
    assert res.status_code == 404


def test_create_geography_invalid_parent(client, db):
    org = _make_org(db)
    admin = _make_admin(db, org.id, "+910000000014")
    token = _token(client, org.id, "+910000000014")

    res = client.post(
        "/api/v1/geography",
        json={"parent_id": str(uuid.uuid4()), "level": "TALUK",
              "name_ta": "தாலுகா", "name_en": "Taluk"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 404
