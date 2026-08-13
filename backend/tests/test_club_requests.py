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
            "email": phone + "@test.fyc",
            "date_of_birth": "1990-01-01",
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


# ---------------------------------------------------------------------------
# Asking, from inside the app
# ---------------------------------------------------------------------------

def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def test_a_signed_in_member_can_ask_to_join(client, db):
    """Until now the only way to ask was a dropdown on the registration form.

    Most people arrive through Google, which skips that form entirely — so the
    member with the strongest claim to be in the club had no way to say so, and
    no way to find out what had happened to it. Both halves are tested here:
    asking, and being told where you stand.
    """
    org = _make_org(db)
    person = _make_volunteer(db, org.id, "+919555555561")
    tok = _login(client, org.id, "+919555555561")

    before = client.get("/api/v1/club-requests/me", headers=_h(org.id, tok)).json()
    assert before["status"] == "NONE"
    assert before["can_request"] is True
    assert before["is_member"] is False

    r = client.post("/api/v1/club-requests/me", headers=_h(org.id, tok))
    assert r.status_code == 201, r.text
    assert r.json()["status"] == "PENDING"

    after = client.get("/api/v1/club-requests/me", headers=_h(org.id, tok)).json()
    assert after["status"] == "PENDING"
    assert after["can_request"] is False, "the screen must not offer to ask twice"
    assert after["requested_at"] is not None


def test_asking_twice_does_not_cost_the_admin_two_decisions(client, db):
    """A second tap while the first is pending must not stack up the queue."""
    org = _make_org(db)
    _make_volunteer(db, org.id, "+919555555562")
    tok = _login(client, org.id, "+919555555562")

    client.post("/api/v1/club-requests/me", headers=_h(org.id, tok))
    r = client.post("/api/v1/club-requests/me", headers=_h(org.id, tok))
    assert r.status_code == 201
    assert r.json()["status"] == "PENDING"

    admin = _make_admin(db, org.id, "+919555555563")
    admin_tok = _login(client, org.id, "+919555555563")
    queue = client.get("/api/v1/club-requests", headers=_h(org.id, admin_tok)).json()
    mine = [q for q in queue if q["phone_number"] == "+919555555562"]
    assert len(mine) == 1, f"one person, one decision: {mine}"


def test_an_executive_member_can_approve(client, db):
    """Holding every request for one of two admins means a member who joined on
    Saturday is still waiting on Tuesday."""
    org = _make_org(db)
    _make_volunteer(db, org.id, "+919555555564")
    applicant_tok = _login(client, org.id, "+919555555564")
    client.post("/api/v1/club-requests/me", headers=_h(org.id, applicant_tok))

    exec_user = _make_admin(db, org.id, "+919555555565", role="EXECUTIVE_MEMBER")
    exec_tok = _login(client, org.id, "+919555555565")

    queue = client.get("/api/v1/club-requests", headers=_h(org.id, exec_tok)).json()
    assert len(queue) == 1, queue

    r = client.post(f"/api/v1/club-requests/{queue[0]['id']}/approve",
                    headers=_h(org.id, exec_tok))
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "APPROVED"

    mine = client.get("/api/v1/club-requests/me", headers=_h(org.id, applicant_tok)).json()
    assert mine["is_member"] is True
    assert mine["role"] == "CLUB_MEMBER"
    assert mine["can_request"] is False
    assert exec_user.role == "EXECUTIVE_MEMBER"


def test_an_ordinary_member_cannot_approve_themselves(client, db):
    """The obvious way to get in without being let in."""
    org = _make_org(db)
    _make_volunteer(db, org.id, "+919555555566")
    tok = _login(client, org.id, "+919555555566")
    client.post("/api/v1/club-requests/me", headers=_h(org.id, tok))

    assert client.get("/api/v1/club-requests", headers=_h(org.id, tok)).status_code == 403


def test_an_approved_member_is_not_offered_the_prompt_again(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919555555567", role="CLUB_MEMBER")
    tok = _login(client, org.id, "+919555555567")

    me = client.get("/api/v1/club-requests/me", headers=_h(org.id, tok)).json()
    assert me["is_member"] is True
    assert me["can_request"] is False

    r = client.post("/api/v1/club-requests/me", headers=_h(org.id, tok))
    assert r.status_code == 400
    assert "already" in r.json()["detail"].lower()


def test_simulation_bots_are_not_people_the_club_browses(client, db):
    """XBot 025 was offered as somebody to challenge, in the club's own list.

    The bots exist to play games during a load simulation. Nothing marked them,
    so they looked exactly like members.
    """
    from app.core.people import real_people
    from app.models.user import User as U

    org = _make_org(db)
    bot = User(organization_id=org.id, phone_number="+919555555568",
               email="xplatbot7@fyc.local", password_hash=get_password_hash("x"),
               role="USER", is_verified=True, source="SIMULATED_BOT")
    db.add(bot)
    db.flush()
    db.add(UserProfile(user_id=bot.id, full_name_en="XBot 007", full_name_ta="XBot 007"))
    real = _make_volunteer(db, org.id, "+919555555569")
    db.commit()

    visible = (db.query(U)
                 .filter(U.organization_id == org.id, real_people(U))
                 .all())
    ids = {u.id for u in visible}
    assert real.id in ids, "a real member must still be listed"
    assert bot.id not in ids, "a simulation bot is not a member"


def test_duplicates_are_reported_and_nothing_is_deleted(client, db):
    """One person is in the roster three times.

    Merging is not reversible and only somebody who knows these people can say
    which row is real, so this reports every account with what it holds and
    stops there.
    """
    org = _make_org(db)
    admin = _make_admin(db, org.id, "+919555555570")
    tok = _login(client, org.id, "+919555555570")

    for i, phone in enumerate(["+919555555571", "+919555555572", "+919555555573"]):
        u = User(organization_id=org.id, phone_number=phone,
                 password_hash=get_password_hash("pass"), role="USER", is_verified=True)
        db.add(u)
        db.flush()
        db.add(UserProfile(user_id=u.id, full_name_en="Varun Kumar",
                           full_name_ta="வருண் குமார்"))
    db.commit()

    groups = client.get("/api/v1/club-requests/duplicates",
                        headers=_h(org.id, tok)).json()
    varun = [g for g in groups if g["key"] == "varun kumar"]
    assert len(varun) == 1, groups
    assert len(varun[0]["accounts"]) == 3
    # Every account carries what a human needs to choose between them.
    for acc in varun[0]["accounts"]:
        assert "phone_number" in acc and "role" in acc and "is_verified" in acc

    # The admin, who appears once, is not reported as a duplicate.
    assert not [g for g in groups if g["key"] == "admin"]
    # And nothing was removed.
    assert db.query(User).filter(User.organization_id == org.id).count() >= 4
