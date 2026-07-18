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
        "email": phone + "@test.fyc",
        "date_of_birth": "1990-01-01",
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

def _close_registration(client, org_id, token, tournament_id):
    return client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/close-registration",
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)},
    )


def test_create_and_list_fixtures(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444528")
    token = _login(client, org.id, "+919444444528")
    tournament_id = _create_tournament(client, org.id, token)

    team_a_id = _create_team(client, org.id, token, tournament_id, name="Alpha")
    team_b_id = _create_team(client, org.id, token, tournament_id, name="Beta")

    # Fixtures require registration to be closed first.
    _close_registration(client, org.id, token, tournament_id)

    fix_res = client.post(
        f"/api/v1/sports/tournaments/{tournament_id}/fixtures",
        json={"team_a_id": team_a_id, "team_b_id": team_b_id, "match_number": 1},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)},
    )
    assert fix_res.status_code == 201
    assert fix_res.json()["status"] == "SCHEDULED"


def test_cannot_create_fixture_while_registration_open(client, db):
    """Admin is allowed to create fixtures even while registration is open."""
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444540")
    token = _login(client, org.id, "+919444444540")
    tournament_id = _create_tournament(client, org.id, token)

    team_a_id = _create_team(client, org.id, token, tournament_id, name="Alpha")
    team_b_id = _create_team(client, org.id, token, tournament_id, name="Beta")

    # Registration still OPEN — creating a fixture should succeed now.
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

    _close_registration(client, org.id, token, tournament_id)

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


# ── Net Run Rate in standings ────────────────────────────────────────────────

def test_standings_include_nrr_and_rank_by_it(client, db):
    """Two teams level on points (both 1 win) are ranked by NRR, and the value
    is returned on each team."""
    from app.models.sports import Team, Fixture
    org = _make_org(db)
    _make_executive(db, org.id, "+919444444401")
    token = _login(client, org.id, "+919444444401")
    tid = _create_tournament(client, org.id, token, match_config="10 Overs")

    a = _create_team(client, org.id, token, tid, name="Aces")
    b = _create_team(client, org.id, token, tid, name="Blasters")
    c = _create_team(client, org.id, token, tid, name="Chargers")
    d = _create_team(client, org.id, token, tid, name="Dashers")

    hdr = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    # Aces win big; Chargers win narrow. Both winners have 1 win / 3 pts.
    f1 = client.post(f"/api/v1/sports/tournaments/{tid}/fixtures",
                     json={"team_a_id": a, "team_b_id": b, "match_number": 1}, headers=hdr).json()["id"]
    f2 = client.post(f"/api/v1/sports/tournaments/{tid}/fixtures",
                     json={"team_a_id": c, "team_b_id": d, "match_number": 2}, headers=hdr).json()["id"]
    client.post(f"/api/v1/sports/tournaments/{tid}/fixtures/{f1}/result",
                json={"team_a_score": "120/3 (10.0 ov)", "team_b_score": "60/10 (8.0 ov)", "winner_id": a}, headers=hdr)
    client.post(f"/api/v1/sports/tournaments/{tid}/fixtures/{f2}/result",
                json={"team_a_score": "100/9 (10.0 ov)", "team_b_score": "101/8 (9.5 ov)", "winner_id": c}, headers=hdr)

    # Both the /teams and /standings endpoints must carry NRR (the mobile
    # standings screen uses /standings).
    for path in (f"/api/v1/sports/tournaments/{tid}/teams",
                 f"/api/v1/sports/tournaments/{tid}/standings"):
        res = client.get(path, headers={"X-Organization-ID": str(org.id)})
        assert res.status_code == 200, path
        rows = res.json()
        by_name = {r["name"]: r for r in rows}
        assert by_name["Aces"]["net_run_rate"] > 0, path
        assert by_name["Blasters"]["net_run_rate"] < 0, path
        winners = [r["name"] for r in rows if r["points"] == 3]
        assert winners[0] == "Aces" and winners[1] == "Chargers", path


# ── Live scores (public Home strip) ──────────────────────────────────────────

def test_live_scores_endpoint(client, db):
    """Public /sports/live returns in-progress matches with a score summary,
    plus recent and upcoming fixtures — no auth required."""
    import uuid as _uuid
    from app.models.sports import Fixture
    from app.models.cricket import CricketMatch

    org = _make_org(db)
    _make_executive(db, org.id, "+919455500001")
    token = _login(client, org.id, "+919455500001")
    tid = _create_tournament(client, org.id, token, match_config="10 Overs")
    a = _create_team(client, org.id, token, tid, name="Strikers")
    b = _create_team(client, org.id, token, tid, name="Titans")
    hdr = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}

    # A live fixture with an in-progress cricket match.
    live_fx = client.post(f"/api/v1/sports/tournaments/{tid}/fixtures",
                          json={"team_a_id": a, "team_b_id": b, "match_number": 1}, headers=hdr).json()["id"]
    cm = CricketMatch(
        id=_uuid.uuid4(), organization_id=org.id, fixture_id=live_fx,
        status="FIRST_INNINGS", overs_per_innings=10,
        match_state={"batting_team_id": a, "score": 82, "wickets": 3, "overs": 7, "balls": 4, "target": None},
    )
    db.add(cm)
    db.commit()

    res = client.get("/api/v1/sports/live", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    body = res.json()
    assert len(body["live"]) == 1
    m = body["live"][0]
    assert m["summary"] == "82/3 (7.4)"
    assert m["batting_team"] == "Strikers"
    assert {m["team_a"], m["team_b"]} == {"Strikers", "Titans"}

    # The live fixture's own status stays SCHEDULED — it must NOT leak into the
    # upcoming list. live / recent / upcoming fixture IDs are disjoint.
    live_ids = {x["fixture_id"] for x in body["live"]}
    recent_ids = {x["fixture_id"] for x in body["recent"]}
    upcoming_ids = {x["fixture_id"] for x in body["upcoming"]}
    assert live_fx not in upcoming_ids
    assert live_ids.isdisjoint(recent_ids)
    assert live_ids.isdisjoint(upcoming_ids)
    assert recent_ids.isdisjoint(upcoming_ids)


def test_live_scores_public_no_auth(client, db):
    org = _make_org(db)
    res = client.get("/api/v1/sports/live", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert res.json() == {"live": [], "recent": [], "upcoming": []}


def test_tournament_village_wides_pins_to_match(client, db):
    """A tournament with village_wides=True forces the rule on every cricket
    match, even if the match init doesn't ask for it."""
    import uuid as _uuid
    from app.models.cricket import CricketMatch

    org = _make_org(db)
    _make_executive(db, org.id, "+919466600001")
    token = _login(client, org.id, "+919466600001")
    tid = _create_tournament(client, org.id, token, match_config="10 Overs", village_wides=True)
    hdr = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}

    # Tournament reflects the pin.
    got = client.get(f"/api/v1/sports/tournaments/{tid}", headers={"X-Organization-ID": str(org.id)}).json()
    assert got["village_wides"] is True

    a = _create_team(client, org.id, token, tid, name="VA")
    b = _create_team(client, org.id, token, tid, name="VB")
    fx = client.post(f"/api/v1/sports/tournaments/{tid}/fixtures",
                     json={"team_a_id": a, "team_b_id": b, "match_number": 1}, headers=hdr).json()["id"]

    # Init a cricket match WITHOUT asking for village_wides — the tournament pins it.
    res = client.post(f"/api/v1/fixtures/{fx}/cricket/init", json={
        "toss_winner_id": a, "toss_decision": "BAT", "overs": 10,
        "striker_name": "P1", "non_striker_name": "P2", "bowler_name": "P3",
    }, headers=hdr)
    assert res.status_code in (200, 201), res.text
    cm = db.query(CricketMatch).filter(CricketMatch.fixture_id == fx).first()
    assert cm is not None and cm.village_wides is True
