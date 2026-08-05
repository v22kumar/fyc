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


def test_a_directory_contact_who_signs_in_becomes_a_member(client, db):
    """Joining FYC is what takes someone off the cold-call list.

    The directory is phone numbers the club collected from a public source.
    Once one of those people installs the app and proves the number is theirs,
    they are reachable in the app — and leaving them filed as an import would
    keep offering them to strangers to ring out of the blue."""
    import uuid
    from app.models.user import User, UserProfile
    from app.models.blood_donor import BloodDonor
    from app.routers.auth import _graduate_from_directory
    from app.core.security import get_password_hash

    org = _make_org(db)
    u = User(id=uuid.uuid4(), organization_id=org.id,
             phone_number="+919600000012", email="joiner@import.local",
             password_hash=get_password_hash("x"), role="PUBLIC_CITIZEN",
             is_verified=True, source="F2S_IMPORT")
    db.add(u); db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="Joiner",
                       full_name_ta="சேர்ந்தவர்"))
    db.add(BloodDonor(id=uuid.uuid4(), organization_id=org.id, user_id=u.id,
                      blood_group="O+", is_available=True))
    db.commit()

    h = {"X-Organization-ID": str(org.id)}
    before = client.get("/api/v1/blood-donors?source=imported", headers=h).json()
    assert any(d["full_name_en"] == "Joiner" for d in before)

    _graduate_from_directory(db, u)

    assert u.source is None
    assert u.role == "PUBLIC_CITIZEN", "graduating must not change privileges"
    after_imported = client.get("/api/v1/blood-donors?source=imported", headers=h).json()
    after_club = client.get("/api/v1/blood-donors?source=club", headers=h).json()
    assert not any(d["full_name_en"] == "Joiner" for d in after_imported)
    assert any(d["full_name_en"] == "Joiner" for d in after_club)


def test_directory_contacts_segregate_by_taluk_and_neighbours(client, db):
    """The directory is organised by taluk, with the option to widen to the
    rest of the district — someone in Nagercoil looking for a rare group needs
    Thovalai and Agastheeswaram too, and nobody in Chennai."""
    import uuid
    from app.models.user import User, UserProfile
    from app.models.blood_donor import BloodDonor
    from app.models.geography import GeographicNode, GeoLevel
    from app.core.security import get_password_hash

    org = _make_org(db)
    state = GeographicNode(id=uuid.uuid4(), level=GeoLevel.STATE,
                           name_en="Tamil Nadu", name_ta="தமிழ்நாடு")
    db.add(state); db.flush()
    kk = GeographicNode(id=uuid.uuid4(), parent_id=state.id,
                        level=GeoLevel.DISTRICT, name_en="Kanyakumari",
                        name_ta="கன்னியாகுமரி")
    far = GeographicNode(id=uuid.uuid4(), parent_id=state.id,
                         level=GeoLevel.DISTRICT, name_en="Chennai",
                         name_ta="சென்னை")
    db.add_all([kk, far]); db.flush()
    nagercoil = GeographicNode(id=uuid.uuid4(), parent_id=kk.id,
                               level=GeoLevel.TALUK, name_en="Nagercoil",
                               name_ta="நாகர்கோவில்")
    thovalai = GeographicNode(id=uuid.uuid4(), parent_id=kk.id,
                              level=GeoLevel.TALUK, name_en="Thovalai",
                              name_ta="தோவாளை")
    mylapore = GeographicNode(id=uuid.uuid4(), parent_id=far.id,
                              level=GeoLevel.TALUK, name_en="Mylapore",
                              name_ta="மயிலாப்பூர்")
    db.add_all([nagercoil, thovalai, mylapore]); db.commit()

    def _contact(name, node, phone):
        u = User(id=uuid.uuid4(), organization_id=org.id, phone_number=phone,
                 email=f"{phone}@import.local",
                 password_hash=get_password_hash("x"), role="PUBLIC_CITIZEN",
                 is_verified=True, source="F2S_IMPORT")
        db.add(u); db.flush()
        db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
        db.add(BloodDonor(id=uuid.uuid4(), organization_id=org.id, user_id=u.id,
                          blood_group="O+", is_available=True,
                          geography_id=node.id))

    _contact("Here", nagercoil, "+919600000021")
    _contact("NextTaluk", thovalai, "+919600000022")
    _contact("FarAway", mylapore, "+919600000023")
    db.commit()

    h = {"X-Organization-ID": str(org.id)}
    base = f"/api/v1/blood-donors?source=imported&geography_id={nagercoil.id}"

    just_here = {d["full_name_en"] for d in client.get(base, headers=h).json()}
    assert just_here == {"Here"}

    district = {d["full_name_en"]
                for d in client.get(base + "&nearby=true", headers=h).json()}
    assert district == {"Here", "NextTaluk"}, "nearby must mean the district, not the state"


def _member(db, org, phone, name="Member", dob=None):
    import uuid
    from app.models.user import User, UserProfile
    from app.core.security import get_password_hash
    u = User(id=uuid.uuid4(), organization_id=org.id, phone_number=phone,
             email=f"{phone}@fyc.local", password_hash=get_password_hash("x"),
             role="PUBLIC_CITIZEN", is_verified=True)
    db.add(u); db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name,
                       date_of_birth=dob))
    db.commit()
    return u


def _auth(u, org):
    from app.core.security import create_access_token
    return {"Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(org.id))}",
            "X-Organization-ID": str(org.id)}


def test_asking_one_donor_reaches_only_that_donor(client, db):
    """Picking a person and asking them is a different act from broadcasting.

    A hundred names is not a decision anyone can make, and ringing them one at
    a time is what this replaces. A targeted request reaches one phone, and
    nobody else's evening is interrupted by an ask that was never for them."""
    from app.models.blood_request import BloodRequest
    org = _make_org(db)
    asker = _member(db, org, "+919600000031", "Meena")
    _, chosen = _donor_with_consent(db=db, client=client, org=org,
                                    phone="+919600000032")
    _, bystander = _donor_with_consent(db=db, client=client, org=org,
                                       phone="+919600000033")
    for d in (chosen, bystander):
        d.latitude, d.longitude = 8.1833, 77.4119
        d.notify_opt_in = True
    db.commit()

    r = client.post("/api/v1/blood-requests", headers=_auth(asker, org), json={
        "patient_blood_group": chosen.blood_group,
        "units_needed": 1,
        "hospital_name": "Asaripallam GH",
        "latitude": 8.1833, "longitude": 77.4119,
        "target_donor_id": str(chosen.id),
    })
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["notified_count"] == 1, "a targeted ask must not fan out"
    assert body["target_donor_name"] is not None

    from uuid import UUID as _UUID
    req = db.query(BloodRequest).filter(
        BloodRequest.id == _UUID(body["id"])).first()
    assert req.target_donor_user_id == chosen.user_id
    assert req.target_donor_user_id != bystander.user_id


def test_the_number_arrives_only_after_the_donor_says_yes(client, db):
    """The exchange this replaces handed out a stranger's number so you could
    ring and find out. Now you ask, they agree, and then you have a number for
    a call they are expecting."""
    org = _make_org(db)
    asker = _member(db, org, "+919600000034", "Meena")
    donor_token, donor = _donor_with_consent(db=db, client=client, org=org,
                                             phone="+919600000035")
    donor.latitude, donor.longitude = 8.1833, 77.4119
    db.commit()

    created = client.post("/api/v1/blood-requests", headers=_auth(asker, org), json={
        "patient_blood_group": donor.blood_group,
        "units_needed": 1,
        "latitude": 8.1833, "longitude": 77.4119,
        "target_donor_id": str(donor.id),
    }).json()
    rid = created["id"]

    before = client.get(f"/api/v1/blood-requests/{rid}",
                        headers=_auth(asker, org)).json()
    assert before["pledges"] == [], "nobody has answered yet"

    dh = {"Authorization": f"Bearer {donor_token}",
          "X-Organization-ID": str(org.id)}
    declined = client.post(f"/api/v1/blood-requests/{rid}/pledge", headers=dh,
                           json={"status": "DECLINED"})
    assert declined.status_code == 200, declined.text
    after_no = client.get(f"/api/v1/blood-requests/{rid}",
                          headers=_auth(asker, org)).json()
    assert after_no["pledges"][0]["donor_phone"] is None, \
        "a declining donor's number must never be disclosed"

    client.post(f"/api/v1/blood-requests/{rid}/pledge", headers=dh,
                json={"status": "ACCEPTED"})
    after_yes = client.get(f"/api/v1/blood-requests/{rid}",
                           headers=_auth(asker, org)).json()
    assert after_yes["pledges"][0]["donor_phone"] == "+919600000035"


def test_a_bystander_never_sees_the_donor_number(client, db):
    """Accepting reveals a number to the person who asked — not to anyone who
    happens to open the request."""
    org = _make_org(db)
    asker = _member(db, org, "+919600000036", "Meena")
    nosy = _member(db, org, "+919600000037", "Nosy")
    donor_token, donor = _donor_with_consent(db=db, client=client, org=org,
                                             phone="+919600000038")
    donor.latitude, donor.longitude = 8.1833, 77.4119
    db.commit()

    rid = client.post("/api/v1/blood-requests", headers=_auth(asker, org), json={
        "patient_blood_group": donor.blood_group,
        "latitude": 8.1833, "longitude": 77.4119,
        "target_donor_id": str(donor.id),
    }).json()["id"]
    client.post(f"/api/v1/blood-requests/{rid}/pledge",
                headers={"Authorization": f"Bearer {donor_token}",
                         "X-Organization-ID": str(org.id)},
                json={"status": "ACCEPTED"})

    seen = client.get(f"/api/v1/blood-requests/{rid}",
                      headers=_auth(nosy, org)).json()
    assert seen["pledges"][0]["donor_name"] is not None
    assert seen["pledges"][0]["donor_phone"] is None
