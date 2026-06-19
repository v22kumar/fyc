"""
Tests for the club-member registration approval flow.

Phone numbers used: +919555555541 – +919555555549 (no collisions with other test files).
"""
import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


# ---------------------------------------------------------------------------
# Helpers (mirror the pattern from test_events.py)
# ---------------------------------------------------------------------------

def _make_org(db):
    org = Organization(
        id=uuid.uuid4(),
        slug=f"cr-org-{uuid.uuid4().hex[:6]}",
        name_ta="நிறுவனம்",
        name_en="Org",
    )
    db.add(org)
    db.commit()
    return org


def _make_admin(db, org_id, phone, role="ADMIN"):
    user = User(
        organization_id=org_id,
        phone_number=phone,
        password_hash=get_password_hash("pass"),
        role=role,
        is_verified=True,
    )
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="நிர்வாகி", full_name_en="Admin"))
    db.commit()
    return user


def _make_volunteer(db, org_id, phone):
    user = User(
        organization_id=org_id,
        phone_number=phone,
        password_hash=get_password_hash("pass"),
        role="VOLUNTEER",
        is_verified=True,
    )
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="தன்னார்வலர்", full_name_en="Volunteer"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post(
        "/api/v1/auth/login/password",
        json={"organization_id": str(org_id), "username": phone, "password": password},
    )
    assert r.status_code == 200, f"Login failed: {r.text}"
    return r.json()["access_token"]


def _register_club_member(client, org_id, phone):
    """Register with role=CLUB_MEMBER and return the full JSON response."""
    res = client.post(
        "/api/v1/auth/register",
        json={
            "organization_id": str(org_id),
            "phone_number": phone,
            "role": "CLUB_MEMBER",
            "full_name_ta": "உறுப்பினர்",
            "full_name_en": "Member",
        },
    )
    return res


def _auth_headers(token, org_id):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_register_as_club_member_gets_citizen_role(client, db):
    """
    Registering with role=CLUB_MEMBER must return a token whose embedded
    user.role is PUBLIC_CITIZEN (not CLUB_MEMBER).
    """
    org = _make_org(db)
    res = _register_club_member(client, org.id, "+919555555541")

    assert res.status_code == 200, res.text
    data = res.json()
    assert data["user"]["role"] == "PUBLIC_CITIZEN"


def test_pending_request_created_on_club_register(client, db):
    """
    After a CLUB_MEMBER registration, an admin listing GET /club-requests
    should see exactly one PENDING entry for that user.
    """
    org = _make_org(db)
    _make_admin(db, org.id, "+919555555542")

    res = _register_club_member(client, org.id, "+919555555543")
    assert res.status_code == 200, res.text
    registrant_id = res.json()["user"]["id"]

    admin_token = _login(client, org.id, "+919555555542")
    r = client.get(
        "/api/v1/club-requests",
        headers=_auth_headers(admin_token, org.id),
    )
    assert r.status_code == 200, r.text
    requests = r.json()
    assert len(requests) == 1
    assert requests[0]["status"] == "PENDING"
    assert requests[0]["user_id"] == registrant_id


def test_admin_can_approve_request(client, db):
    """
    An admin POSTing to /club-requests/{id}/approve must:
    - Return status=APPROVED
    - Upgrade the applicant's role to CLUB_MEMBER in the database
    """
    org = _make_org(db)
    _make_admin(db, org.id, "+919555555544")
    _register_club_member(client, org.id, "+919555555545")

    admin_token = _login(client, org.id, "+919555555544")
    headers = _auth_headers(admin_token, org.id)

    # Fetch the pending request id
    pending = client.get("/api/v1/club-requests", headers=headers).json()
    assert len(pending) == 1
    request_id = pending[0]["request_id"] if "request_id" in pending[0] else pending[0]["id"]
    applicant_id = pending[0]["user_id"]

    # Approve
    approve_res = client.post(
        f"/api/v1/club-requests/{request_id}/approve",
        headers=headers,
    )
    assert approve_res.status_code == 200, approve_res.text
    assert approve_res.json()["status"] == "APPROVED"

    # Verify the user's role was upgraded in the DB
    from app.models.user import User as UserModel
    from uuid import UUID
    db_user = db.query(UserModel).filter(UserModel.id == UUID(applicant_id)).first()
    assert db_user is not None
    assert db_user.role == "CLUB_MEMBER"


def test_admin_can_reject_request(client, db):
    """
    An admin POSTing to /club-requests/{id}/reject must:
    - Return status=REJECTED
    - Leave the applicant's role as PUBLIC_CITIZEN
    """
    org = _make_org(db)
    _make_admin(db, org.id, "+919555555546")
    _register_club_member(client, org.id, "+919555555547")

    admin_token = _login(client, org.id, "+919555555546")
    headers = _auth_headers(admin_token, org.id)

    pending = client.get("/api/v1/club-requests", headers=headers).json()
    assert len(pending) == 1
    request_id = pending[0]["id"]
    applicant_id = pending[0]["user_id"]

    reject_res = client.post(
        f"/api/v1/club-requests/{request_id}/reject",
        headers=headers,
    )
    assert reject_res.status_code == 200, reject_res.text
    assert reject_res.json()["status"] == "REJECTED"

    # User must still be PUBLIC_CITIZEN
    from app.models.user import User as UserModel
    from uuid import UUID
    db_user = db.query(UserModel).filter(UserModel.id == UUID(applicant_id)).first()
    assert db_user is not None
    assert db_user.role == "PUBLIC_CITIZEN"


def test_volunteer_cannot_view_requests(client, db):
    """
    A VOLUNTEER calling GET /club-requests must receive 403 Forbidden.
    """
    org = _make_org(db)
    _make_volunteer(db, org.id, "+919555555548")

    vol_token = _login(client, org.id, "+919555555548")
    res = client.get(
        "/api/v1/club-requests",
        headers=_auth_headers(vol_token, org.id),
    )
    assert res.status_code == 403
