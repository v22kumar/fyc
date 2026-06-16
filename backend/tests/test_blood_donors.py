import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"bd-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _register(client, org_id, phone, role="VOLUNTEER"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id),
        "phone_number": phone,
        "role": role,
        "full_name_ta": "தானியம்",
        "full_name_en": "Donor Test"
    })
    return res.json()["access_token"]


def test_register_blood_donor(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111111")

    res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "O+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    data = res.json()
    assert data["blood_group"] == "O+"
    assert data["is_available"] is True


def test_register_donor_invalid_blood_group(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111112")

    res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "X+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 400


def test_register_donor_duplicate(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111113")

    client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "A+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "B+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 400


def test_search_donors_public(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111114")

    client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "B+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )

    res = client.get(
        "/api/v1/blood-donors?blood_group=B%2B",
        headers={"X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 200
    assert len(res.json()) >= 1
    assert res.json()[0]["blood_group"] == "B+"
    # Phone number must NOT be in public response
    for donor in res.json():
        assert "phone_number" not in donor


def test_search_donors_no_results_for_unavailable(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111115")

    client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "AB-", "is_available": False},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )

    res = client.get(
        "/api/v1/blood-donors?blood_group=AB-&available_only=true",
        headers={"X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 200
    assert len(res.json()) == 0


def test_update_availability(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111116")

    reg_res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "A-", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    donor_id = reg_res.json()["id"]

    upd_res = client.patch(
        f"/api/v1/blood-donors/{donor_id}/availability",
        json={"is_available": False},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert upd_res.status_code == 200
    assert upd_res.json()["is_available"] is False


def test_request_contact_authenticated(client, db):
    org = _make_org(db)
    donor_token = _register(client, org.id, "+919111111117")
    requester_token = _register(client, org.id, "+919111111118")

    reg_res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "O-", "is_available": True},
        headers={"Authorization": f"Bearer {donor_token}", "X-Organization-ID": str(org.id)}
    )
    donor_id = reg_res.json()["id"]

    contact_res = client.post(
        f"/api/v1/blood-donors/{donor_id}/request-contact",
        headers={"Authorization": f"Bearer {requester_token}", "X-Organization-ID": str(org.id)}
    )
    assert contact_res.status_code == 200
    data = contact_res.json()
    assert "phone_number" in data
    assert "whatsapp_link" in data
    assert "wa.me" in data["whatsapp_link"]


def test_request_contact_public_no_auth_required(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111119")
    reg_res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "A+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    donor_id = reg_res.json()["id"]

    res = client.post(
        f"/api/v1/blood-donors/{donor_id}/request-contact",
        headers={"X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 200
    data = res.json()
    assert "phone_number" in data
    assert "whatsapp_link" in data


def test_request_contact_missing_tenant_header_rejected(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919111111120")
    reg_res = client.post(
        "/api/v1/blood-donors/register",
        json={"blood_group": "A+", "is_available": True},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    donor_id = reg_res.json()["id"]

    res = client.post(f"/api/v1/blood-donors/{donor_id}/request-contact")
    assert res.status_code == 400
