import uuid
from datetime import datetime, timedelta, timezone
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"evt-org-{uuid.uuid4().hex[:6]}",
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


def _event_payload(start_offset=1, duration=2):
    now = datetime.now(timezone.utc)
    start = now + timedelta(hours=start_offset)
    end = start + timedelta(hours=duration)
    return {
        "title_ta": "சுதந்திர தினம்",
        "title_en": "Independence Day",
        "description_ta": "நிகழ்வு விவரம்",
        "description_en": "Event description",
        "event_start": start.isoformat(),
        "event_end": end.isoformat(),
        "is_published": True
    }


def test_create_event_executive(client, db):
    org = _make_org(db)
    exec_user = _make_executive(db, org.id, "+919333333331")
    token = _login(client, org.id, "+919333333331")

    res = client.post(
        "/api/v1/events",
        json=_event_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    data = res.json()
    assert data["title_en"] == "Independence Day"
    assert data["created_by_user_id"] == str(exec_user.id)


def test_create_event_citizen_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919333333332", role="PUBLIC_CITIZEN")

    res = client.post(
        "/api/v1/events",
        json=_event_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 403


def test_create_event_invalid_dates(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919333333333")
    token = _login(client, org.id, "+919333333333")

    now = datetime.now(timezone.utc)
    res = client.post(
        "/api/v1/events",
        json={
            "title_ta": "நிகழ்வு", "title_en": "Event",
            "description_ta": "விவரம்", "description_en": "Desc",
            "event_start": (now + timedelta(hours=2)).isoformat(),
            "event_end": (now + timedelta(hours=1)).isoformat()
        },
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 400


def test_list_events(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919333333334")
    token = _login(client, org.id, "+919333333334")

    client.post("/api/v1/events", json=_event_payload(),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    client.post("/api/v1/events", json=_event_payload(start_offset=3),
                headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/events", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_get_event_not_found(client, db):
    org = _make_org(db)
    res = client.get(
        f"/api/v1/events/{uuid.uuid4()}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


def test_event_checkin_volunteer(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919333333335")
    exec_token = _login(client, org.id, "+919333333335")

    event_res = client.post(
        "/api/v1/events", json=_event_payload(),
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)}
    )
    event_id = event_res.json()["id"]

    vol_token = _register(client, org.id, "+919333333336", role="VOLUNTEER")
    vol_id = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)}
    ).json()["id"]

    checkin_res = client.post(
        f"/api/v1/events/{event_id}/checkin",
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)}
    )
    assert checkin_res.status_code == 200
    data = checkin_res.json()
    assert data["message"] == "Check-in successful"
    assert data["user_id"] == vol_id


def test_event_checkin_duplicate(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919333333337")
    exec_token = _login(client, org.id, "+919333333337")

    event_id = client.post(
        "/api/v1/events", json=_event_payload(),
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)}
    ).json()["id"]

    vol_token = _register(client, org.id, "+919333333338", role="VOLUNTEER")
    headers = {"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)}

    client.post(f"/api/v1/events/{event_id}/checkin", headers=headers)
    res = client.post(f"/api/v1/events/{event_id}/checkin", headers=headers)
    assert res.status_code == 400
    assert "already checked in" in res.json()["detail"]


def test_event_checkin_citizen_denied(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919333333339")
    exec_token = _login(client, org.id, "+919333333339")

    event_id = client.post(
        "/api/v1/events", json=_event_payload(),
        headers={"Authorization": f"Bearer {exec_token}", "X-Organization-ID": str(org.id)}
    ).json()["id"]

    citizen_token = _register(client, org.id, "+919333333340", role="PUBLIC_CITIZEN")
    res = client.post(
        f"/api/v1/events/{event_id}/checkin",
        headers={"Authorization": f"Bearer {citizen_token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 403


# ── Event registration (Android RSVP flow) ────────────────────────────────────

def _registration_payload(name="Kumar"):
    return {
        "name": name,
        "dob": "2001-06-15T00:00:00Z",
        "gender": "Male",
        "mobile_number": "+919000000001",
        "school_college": "Govt Higher Secondary School",
        "class_grade": "12",
        "competition_category": [],
    }


def _create_event(client, db, org, phone, extra=None):
    _make_executive(db, org.id, phone)
    token = _login(client, org.id, phone)
    payload = _event_payload()
    if extra:
        payload.update(extra)
    res = client.post("/api/v1/events", json=payload,
                      headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)})
    assert res.status_code == 201
    return res.json()["id"], token


def test_register_for_event_anonymous(client, db):
    """The app's RSVP sheet posts without auth — must succeed for a published event."""
    org = _make_org(db)
    event_id, _ = _create_event(client, db, org, "+919333333341")

    res = client.post(f"/api/v1/events/{event_id}/register",
                      json=_registration_payload(),
                      headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert res.json()["name"] == "Kumar"


def test_register_with_future_deadline_succeeds(client, db):
    """Regression: SQLite returns naive datetimes; comparing them against
    datetime.now(timezone.utc) raised TypeError -> 500, which is why Android
    registration failed on any event that had a deadline set."""
    org = _make_org(db)
    deadline = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    event_id, _ = _create_event(client, db, org, "+919333333342",
                                extra={"registration_deadline": deadline})

    res = client.post(f"/api/v1/events/{event_id}/register",
                      json=_registration_payload(),
                      headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200


def test_register_past_deadline_rejected(client, db):
    org = _make_org(db)
    deadline = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    event_id, _ = _create_event(client, db, org, "+919333333343",
                                extra={"registration_deadline": deadline})

    res = client.post(f"/api/v1/events/{event_id}/register",
                      json=_registration_payload(),
                      headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 400
    assert "deadline" in res.json()["detail"].lower()


def test_registrants_names_only(client, db):
    """Member-facing list exposes names and count — never phone numbers."""
    org = _make_org(db)
    event_id, _ = _create_event(client, db, org, "+919333333344")

    for name in ["Kumar", "Priya"]:
        client.post(f"/api/v1/events/{event_id}/register",
                    json=_registration_payload(name=name),
                    headers={"X-Organization-ID": str(org.id)})

    res = client.get(f"/api/v1/events/{event_id}/registrants",
                     headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    body = res.json()
    assert body["count"] == 2
    assert body["names"] == ["Kumar", "Priya"]
    assert "+919000000001" not in str(body)  # no PII on the public projection


def test_registrants_other_tenant_404(client, db):
    org = _make_org(db)
    other = _make_org(db)
    event_id, _ = _create_event(client, db, org, "+919333333345")

    res = client.get(f"/api/v1/events/{event_id}/registrants",
                     headers={"X-Organization-ID": str(other.id)})
    assert res.status_code == 404
