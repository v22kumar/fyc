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
    assert d.last_seen_lat is not None
    assert d.last_seen_at is not None


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
    first = db.query(BloodDonor).filter(BloodDonor.id == d.id).first().last_seen_at

    client.patch("/api/v1/blood-donors/me/location",
                 json={"lat": 8.1801, "lng": 77.4101}, headers=h)
    db.expire_all()
    again = db.query(BloodDonor).filter(BloodDonor.id == d.id).first().last_seen_at
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
    assert abs(fresh.last_seen_lat - 8.30) < 0.001


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
        BloodDonor.id == d.id).first().last_seen_at is None


def test_opening_the_app_elsewhere_never_moves_the_home_area(client, db):
    """The bug this schema split exists to prevent.

    A member registers in Nagercoil and later opens the app once while visiting
    Chennai. With both positions sharing one pair of columns, that single visit
    relocated their home area permanently — and nothing recorded that it had
    happened. The two claims have different lifetimes and must not share storage.
    """
    from app.models.blood_donor import BloodDonor
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000005")
    d.latitude, d.longitude = 8.1833, 77.4119          # home: Nagercoil
    db.commit()

    client.patch("/api/v1/blood-donors/me/location",
                 json={"lat": 13.0827, "lng": 80.2707},  # opened in Chennai
                 headers={"Authorization": f"Bearer {token}",
                          "X-Organization-ID": str(org.id)})
    db.expire_all()
    fresh = db.query(BloodDonor).filter(BloodDonor.id == d.id).first()

    assert abs(fresh.latitude - 8.1833) < 0.0001, "home area was overwritten"
    assert abs(fresh.last_seen_lat - 13.0827) < 0.0001
    assert fresh.last_seen_at is not None


def test_nearby_ranks_from_a_recent_position_and_says_so(client, db):
    """A fresh fix is better information than a home area — and the requester
    has to be told which one the distance came from, or they cannot judge it."""
    from datetime import datetime, timezone
    from app.models.blood_donor import BloodDonor
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000006")
    d.latitude, d.longitude = 8.50, 77.80              # home, far from the query
    d.last_seen_lat, d.last_seen_lng = 8.1840, 77.4125  # seen beside it, moments ago
    d.last_seen_at = datetime.now(timezone.utc)
    db.commit()

    r = client.get("/api/v1/blood-donors/nearby?lat=8.1833&lng=77.4119&radius_km=5",
                   headers={"X-Organization-ID": str(org.id)})
    assert r.status_code == 200, r.text
    hit = next(x for x in r.json() if x["id"] == str(d.id))
    assert hit["distance_km"] < 1          # measured from where they were seen
    assert hit["location_basis"] == "live"


def test_a_stale_fix_falls_back_to_the_home_area(client, db):
    """A last-seen position from months ago is not a better answer than "lives
    nearby" — it is only a more precise way to be wrong."""
    from datetime import datetime, timedelta, timezone
    from app.models.blood_donor import BloodDonor
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000007")
    d.latitude, d.longitude = 8.1840, 77.4125          # home, next to the query
    d.last_seen_lat, d.last_seen_lng = 13.08, 80.27     # seen in Chennai, long ago
    d.last_seen_at = datetime.now(timezone.utc) - timedelta(days=90)
    db.commit()

    r = client.get("/api/v1/blood-donors/nearby?lat=8.1833&lng=77.4119&radius_km=5",
                   headers={"X-Organization-ID": str(org.id)})
    hit = next(x for x in r.json() if x["id"] == str(d.id))
    assert hit["distance_km"] < 1
    assert hit["location_basis"] == "home"


def test_a_few_hours_old_is_recent_not_live(client, db):
    """Three states, not two. A fix from this morning is still worth ranking
    from, but calling it "live" would overstate it — and the app draws a filled
    dot for live and a hollow ring for recent, so the distinction is visible to
    the person deciding who to call."""
    from datetime import datetime, timedelta, timezone
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000008")
    d.latitude, d.longitude = 8.50, 77.80              # home, far from the query
    d.last_seen_lat, d.last_seen_lng = 8.1840, 77.4125  # seen beside it this morning
    d.last_seen_at = datetime.now(timezone.utc) - timedelta(hours=5)
    db.commit()

    r = client.get("/api/v1/blood-donors/nearby?lat=8.1833&lng=77.4119&radius_km=5",
                   headers={"X-Organization-ID": str(org.id)})
    hit = next(x for x in r.json() if x["id"] == str(d.id))
    assert hit["distance_km"] < 1          # still ranked from the fix
    assert hit["location_basis"] == "recent"


def test_source_filter_splits_club_members_from_imported_contacts(client, db):
    """Two populations that behave nothing alike. A club member can be located,
    notified and asked; an imported contact is a phone number from a public
    directory and nothing else. Showing them in one list promised the same
    thing for both."""
    import uuid
    from app.models.user import User, UserProfile
    from app.models.blood_donor import BloodDonor
    from app.core.security import get_password_hash

    org = _make_org(db)
    _donor_with_consent(client, db, org, phone="+919600000009")   # club member

    imported = User(id=uuid.uuid4(), organization_id=org.id,
                    phone_number="+919600000010", email="f2s@import.local",
                    password_hash=get_password_hash("x"), role="USER",
                    is_verified=False, source="F2S_IMPORT")
    db.add(imported); db.flush()
    db.add(UserProfile(user_id=imported.id, full_name_en="Imported Contact",
                       full_name_ta="இறக்குமதி தொடர்பு"))
    db.add(BloodDonor(id=uuid.uuid4(), organization_id=org.id,
                      user_id=imported.id, blood_group="O+", is_available=True))
    db.commit()

    h = {"X-Organization-ID": str(org.id)}
    club = client.get("/api/v1/blood-donors?source=club", headers=h).json()
    imp = client.get("/api/v1/blood-donors?source=imported", headers=h).json()
    both = client.get("/api/v1/blood-donors", headers=h).json()

    assert all(not d["is_imported"] for d in club), "an import leaked into the club list"
    assert imp and all(d["is_imported"] for d in imp)
    assert len(both) == len(club) + len(imp), "unfiltered must still return everyone"


def test_the_pin_sits_where_the_distance_was_measured_from(client, db):
    """The map and the row have to be the same claim.

    A donor seen this morning a kilometre away has a home area twenty
    kilometres off. Publishing the home area anyway put their pin somewhere the
    card never said they were — and a member deciding who to call reads both."""
    from datetime import datetime, timezone
    org = _make_org(db)
    token, d = _donor_with_consent(client, db, org, phone="+919600000011")
    d.latitude, d.longitude = 8.50, 77.80              # home, far away
    d.last_seen_lat, d.last_seen_lng = 8.1840, 77.4125  # seen beside the query
    d.last_seen_at = datetime.now(timezone.utc)
    db.commit()

    r = client.get("/api/v1/blood-donors/nearby?lat=8.1833&lng=77.4119&radius_km=5",
                   headers={"X-Organization-ID": str(org.id)})
    hit = next(x for x in r.json() if x["id"] == str(d.id))
    assert hit["location_basis"] == "live"
    assert abs(hit["approx_latitude"] - 8.18) < 0.005, "pin fell back to the home area"
    assert abs(hit["approx_longitude"] - 77.41) < 0.005
