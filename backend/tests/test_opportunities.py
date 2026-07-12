import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.models.opportunity import Opportunity, OpportunityType
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"opp-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, role):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role=role, is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="பயனர்", full_name_en="User"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


def _job_payload(**overrides):
    payload = {
        "type": "JOB",
        "title_ta": "தச்சர் தேவை",
        "title_en": "Carpenter needed",
        "description_en": "Two days of woodwork",
        "budget": "₹500/day",
        "contact_phone": "9876543210",
    }
    payload.update(overrides)
    return payload


def _headers(token, org_id):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


# ── Posting is open to members (CLUB_MEMBER+) ─────────────────────────────────

def test_member_can_post_job(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "+919555000001", role="CLUB_MEMBER")
    token = _login(client, org.id, "+919555000001")

    res = client.post("/api/v1/opportunities", json=_job_payload(), headers=_headers(token, org.id))
    assert res.status_code == 201
    data = res.json()
    assert data["type"] == "JOB"
    assert data["budget"] == "₹500/day"
    assert data["posted_by"] is not None
    # The public create shape must not leak the poster's phone number.
    assert "contact_phone" not in data


def test_role_below_member_cannot_post(client, db):
    """VOLUNTEER sits below CLUB_MEMBER — posting is denied."""
    org = _make_org(db)
    _make_user(db, org.id, "+919555000002", role="VOLUNTEER")
    token = _login(client, org.id, "+919555000002")

    res = client.post("/api/v1/opportunities", json=_job_payload(), headers=_headers(token, org.id))
    assert res.status_code == 403


def test_post_course_type_rejected(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "+919555000003", role="ADMIN")
    token = _login(client, org.id, "+919555000003")

    res = client.post("/api/v1/opportunities", json=_job_payload(type="COURSE"),
                      headers=_headers(token, org.id))
    assert res.status_code == 422


# ── Legacy COURSE rows never surface in the Jobs feed ─────────────────────────

def test_legacy_course_hidden_from_default_list(client, db):
    org = _make_org(db)
    db.add(Opportunity(organization_id=org.id, type=OpportunityType.COURSE,
                       title_ta="பழைய படிப்பு", title_en="Legacy course", is_active=True))
    db.add(Opportunity(organization_id=org.id, type=OpportunityType.JOB,
                       title_ta="வேலை", title_en="A job", is_active=True))
    db.commit()

    res = client.get("/api/v1/opportunities", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    types = {item["type"] for item in res.json()}
    assert "JOB" in types
    assert "COURSE" not in types


def test_course_filter_rejected(client, db):
    org = _make_org(db)
    res = client.get("/api/v1/opportunities?type=COURSE", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 422


def test_volunteer_filter_allowed(client, db):
    org = _make_org(db)
    db.add(Opportunity(organization_id=org.id, type=OpportunityType.VOLUNTEER,
                       title_ta="தொண்டு", title_en="Help drive", is_active=True))
    db.commit()
    res = client.get("/api/v1/opportunities?type=VOLUNTEER", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert all(item["type"] == "VOLUNTEER" for item in res.json())


# ── contact_phone is member-only ──────────────────────────────────────────────

def test_contact_phone_withheld_on_list_present_on_detail(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "+919555000004", role="CLUB_MEMBER")
    token = _login(client, org.id, "+919555000004")

    create = client.post("/api/v1/opportunities", json=_job_payload(),
                         headers=_headers(token, org.id))
    opp_id = create.json()["id"]

    # Public list — phone must be absent.
    lst = client.get("/api/v1/opportunities", headers={"X-Organization-ID": str(org.id)})
    assert lst.status_code == 200
    item = next(i for i in lst.json() if i["id"] == opp_id)
    assert "contact_phone" not in item

    # Authenticated detail — phone is revealed.
    detail = client.get(f"/api/v1/opportunities/{opp_id}", headers=_headers(token, org.id))
    assert detail.status_code == 200
    assert detail.json()["contact_phone"] == "9876543210"


def test_detail_requires_auth(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "+919555000005", role="CLUB_MEMBER")
    token = _login(client, org.id, "+919555000005")
    opp_id = client.post("/api/v1/opportunities", json=_job_payload(),
                         headers=_headers(token, org.id)).json()["id"]

    res = client.get(f"/api/v1/opportunities/{opp_id}", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 401
