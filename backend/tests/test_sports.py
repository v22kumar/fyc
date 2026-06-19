import uuid
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"spt-org-{uuid.uuid4().hex[:6]}",
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


def _make_admin(db, org_id, phone):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="நிர்வாகன்", full_name_en="Admin"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


def _register(client, org_id, phone, role="VOLUNTEER"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id), "phone_number": phone,
        "role": role, "full_name_ta": "பயனர்", "full_name_en": "User"
    })
    return res.json()["access_token"]


def _tournament_payload(**overrides):
    payload = {
        "name_ta": "கிரிக்கெட் போட்டி",
        "name_en": "Cricket Tournament",
        "sport": "cricket",
        "year": 2026,
        "format": "LEAGUE",
    }
    payload.update(overrides)
    return payload


def _create_tournament(client, org_id, token, **overrides):
    return client.post(
        "/api/v1/sports/tournaments",
        json=_tournament_payload(**overrides),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)},
    ).json()["id"]


def _create_team(client, org_id, token, tournament_id, name="Team Alpha"):
    return client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/teams",
        json={"name": name, "captain_name": "Captain", "is_fyc_team": False},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)},
    ).json()["id"]


# ── Tournaments ───────────────────────────────────────────────────────────────

def test_create_tournament_executive(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444521")
    token = _login(client, org.id, "+919444444521")

    res = client.post(
        "/api/v1/sports/tournaments",
        json=_tournament_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name_en"] == "Cricket Tournament"
    assert data["sport"] == "cricket"
    assert data["status"] == "UPCOMING"


def test_create_tournament_volunteer_denied(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444522", role="VOLUNTEER")

    res = client.post(
        "/api/v1/sports/tournaments",
        json=_tournament_payload(),
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 403


def test_list_tournaments_public(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444523")
    token = _login(client, org.id, "+919444444523")

    _create_tournament(client, org.id, token, name_en="Cricket Tournament")
    _create_tournament(client, org.id, token, name_en="Kabaddi Tournament", sport="kabaddi")

    res = client.get("/api/v1/sports/tournaments", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_get_tournament_not_found(client, db):
    org = _make_org(db)
    res = client.get(
        f"/api/v1/sports/tournaments/{uuid.uuid4()}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 404


def test_update_tournament_status(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444524")
    token = _login(client, org.id, "+919444444524")
    tournament_id = _create_tournament(client, org.id, token)

    res = client.patch(
        f"/api/v1/sports/tournaments/{tournament_id}/status?new_status=ONGOING",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert res.json()["status"] == "ONGOING"


# ── Teams ─────────────────────────────────────────────────────────────────────

def test_register_team_authenticated(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444525")
    exec_token = _login(client, org.id, "+919444444525")
    tournament_id = _create_tournament(client, org.id, exec_token)

    vol_token = _register(client, org.id, "+919444444526", role="VOLUNTEER")
    res = client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/teams",
        json={"name": "Team Alpha", "captain_name": "Alice", "is_fyc_team": True},
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Team Alpha"
    assert data["wins"] == 0


def test_list_teams_public(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444527")
    token = _login(client, org.id, "+919444444527")
    tournament_id = _create_tournament(client, org.id, token)

    _create_team(client, org.id, token, tournament_id, name="Alpha")
    _create_team(client, org.id, token, tournament_id, name="Beta")

    res = client.get(
        f"/api/v1/sports/tournaments/{tournament_id}/teams",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert len(res.json()) == 2


# ── Fixtures ──────────────────────────────────────────────────────────────────

def test_create_and_list_fixtures(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444528")
    token = _login(client, org.id, "+919444444528")
    tournament_id = _create_tournament(client, org.id, token)

    team_a_id = _create_team(client, org.id, token, tournament_id, name="Alpha")
    team_b_id = _create_team(client, org.id, token, tournament_id, name="Beta")

    fix_res = client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/fixtures",
        json={"team_a_id": team_a_id, "team_b_id": team_b_id, "match_number": 1},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert fix_res.status_code == 201
    assert fix_res.json()["status"] == "SCHEDULED"

    list_res = client.get(
        f"/api/v1/sports/tournaments/{tournament_id}/fixtures",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert list_res.status_code == 200
    assert len(list_res.json()) == 1


def test_submit_fixture_result(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444529")
    token = _login(client, org.id, "+919444444529")
    tournament_id = _create_tournament(client, org.id, token)

    team_a_id = _create_team(client, org.id, token, tournament_id, name="Winners")
    team_b_id = _create_team(client, org.id, token, tournament_id, name="Losers")

    fixture_id = client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/fixtures",
        json={"team_a_id": team_a_id, "team_b_id": team_b_id, "match_number": 1},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    ).json()["id"]

    result_res = client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/fixtures/{fixture_id}/result",
        json={"team_a_score": "150/5", "team_b_score": "120/10", "winner_id": team_a_id},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert result_res.status_code == 200
    data = result_res.json()
    assert data["status"] == "COMPLETED"
    assert data["team_a_score"] == "150/5"


# ── Challenges ────────────────────────────────────────────────────────────────

def test_submit_challenge_authenticated(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919444444530", role="VOLUNTEER")

    res = client.post(
        "/api/v1/sports/challenges",
        json={
            "challenger_team_name": "Street Warriors",
            "challenger_captain": "Ravi",
            "challenger_phone": "9876543210",
            "sport": "cricket",
            "venue": "Town Ground",
            "message": "We challenge you!",
        },
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 201
    data = res.json()
    assert data["challenger_team_name"] == "Street Warriors"
    assert data["status"] == "OPEN"


def test_respond_to_challenge_admin(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444531")
    admin_token = _login(client, org.id, "+919444444531")

    vol_token = _register(client, org.id, "+919444444532", role="VOLUNTEER")
    challenge_id = client.post(
        "/api/v1/sports/challenges",
        json={
            "challenger_team_name": "Tigers",
            "challenger_captain": "Kumar",
            "challenger_phone": "9000000000",
            "sport": "kabaddi",
        },
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)},
    ).json()["id"]

    patch_res = client.patch(
        f"/api/v1/sports/challenges/{challenge_id}",
        json={"status": "ACCEPTED", "admin_response": "We accept!"},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["status"] == "ACCEPTED"
    assert patch_res.json()["admin_response"] == "We accept!"


def test_respond_to_challenge_non_admin_denied(client, db):
    org = _make_org(db)
    _make_admin(db, org.id, "+919444444533")
    admin_token = _login(client, org.id, "+919444444533")

    vol_token = _register(client, org.id, "+919444444534", role="VOLUNTEER")
    challenge_id = client.post(
        "/api/v1/sports/challenges",
        json={
            "challenger_team_name": "Eagles",
            "challenger_captain": "Raj",
            "challenger_phone": "9000000001",
            "sport": "football",
        },
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)},
    ).json()["id"]

    patch_res = client.patch(
        f"/api/v1/sports/challenges/{challenge_id}",
        json={"status": "REJECTED"},
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)},
    )
    assert patch_res.status_code == 403
