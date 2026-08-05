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
        "email": phone + "@test.fyc",
        "date_of_birth": "1990-01-01",
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


def test_the_all_chip_returns_everyone_rather_than_nobody(client, db):
    """The app's "All" chip sends the literal string "All".

    That was matched against the blood_group column, so the default view of the
    entire screen — the one every member sees first — returned an empty list no
    matter how many donors were registered.
    """
    org = _make_org(db)
    _register(client, org.id, "9500000001")
    h = {"X-Organization-ID": str(org.id)}
    unfiltered = client.get("/api/v1/blood-donors", headers=h)
    as_all = client.get("/api/v1/blood-donors?blood_group=All", headers=h)
    assert as_all.status_code == 200
    assert len(as_all.json()) == len(unfiltered.json())


# ── Opportunistic location ────────────────────────────────────────────────────

def _donor_with_consent(client, db, org, phone="+919600000001", consent=True):
    from app.models.blood_donor import BloodDonor
    token = _register(client, org.id, phone)
    h = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    res = client.post("/api/v1/blood-donors/register",
                      json={"blood_group": "O+", "is_available": True}, headers=h)
    assert res.status_code == 201, res.text
    d = db.query(BloodDonor).filter(
        BloodDonor.id == uuid.UUID(res.json()["id"])).first()
    d.location_consent = consent
    db.commit()
    return token, d


def test_a_first_position_is_stored(client, db):
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org)
    r = client.patch("/api/v1/blood-donors/me/location",
                     json={"lat": 8.18, "lng": 77.41},
                     headers={"Authorization": f"Bearer {token}",
                              "X-Organization-ID": str(org.id)})
    assert r.status_code == 204, r.text
    db.expire_all()
    from app.models.blood_donor import BloodDonor
    d = db.query(BloodDonor).filter(BloodDonor.id == d.id).first()
    assert d.latitude is not None
    assert d.location_updated_at is not None


def test_opening_the_app_again_from_the_same_place_writes_nothing(client, db):
    """This runs on every app open. If it wrote each time it would be pure
    churn — a search that works in kilometres cannot see a few metres."""
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000002")
    h = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    client.patch("/api/v1/blood-donors/me/location",
                 json={"lat": 8.18, "lng": 77.41}, headers=h)
    db.expire_all()
    from app.models.blood_donor import BloodDonor
    first = db.query(BloodDonor).filter(BloodDonor.id == d.id).first().location_updated_at

    client.patch("/api/v1/blood-donors/me/location",
                 json={"lat": 8.1801, "lng": 77.4101}, headers=h)
    db.expire_all()
    again = db.query(BloodDonor).filter(BloodDonor.id == d.id).first().location_updated_at
    assert again == first


def test_moving_a_real_distance_does_update(client, db):
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000003")
    h = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    client.patch("/api/v1/blood-donors/me/location",
                 json={"lat": 8.18, "lng": 77.41}, headers=h)
    client.patch("/api/v1/blood-donors/me/location",
                 json={"lat": 8.30, "lng": 77.55}, headers=h)
    db.expire_all()
    from app.models.blood_donor import BloodDonor
    fresh = db.query(BloodDonor).filter(BloodDonor.id == d.id).first()
    assert abs(fresh.latitude - 8.30) < 0.001


def test_without_consent_nothing_is_recorded(client, db):
    """Opening the app is not consent to be located."""
    org = _make_org(db)
    from app.models.blood_donor import BloodDonor
    token, d = _donor_with_consent(client, db, org,
                                   phone="+919600000004", consent=False)
    r = client.patch("/api/v1/blood-donors/me/location",
                     json={"lat": 8.18, "lng": 77.41},
                     headers={"Authorization": f"Bearer {token}",
                              "X-Organization-ID": str(org.id)})
    assert r.status_code == 204
    db.expire_all()
    assert db.query(BloodDonor).filter(
        BloodDonor.id == d.id).first().location_updated_at is None
