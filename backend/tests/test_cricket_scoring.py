"""Regression tests for two data-integrity bugs reported from live scoring:

1. Two different physical players entered under the SAME name on the same
   team silently collapse into one Player row (_get_or_create_player matches
   by name), so both the striker and non-striker show identical, merged
   stats. Reject requests where a batter role would collide on name.

2. Confirming a wicket without typing a replacement batter's name left the
   dismissed player's id in place for the next ball, corrupting the batting
   order — the app then resumes with no valid non-striker to pick from
   ("Confirm current players" shows a blank, unselectable option). Require a
   distinct new batter name whenever the innings continues past a wicket.
"""
import uuid

from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"cs-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_exec(db, org_id, phone):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role="EXECUTIVE_MEMBER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="நிர்வாகி", full_name_en="Organizer"))
    db.commit()
    return u


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def _setup_fixture(client, db):
    """Org + organizer + a 2-team cricket fixture ready to score, matching the
    real client flow (create tournament → register teams → approve → close →
    generate fixtures)."""
    org = _make_org(db)
    _make_exec(db, org.id, "9500000001")
    tok = _login(client, org.id, "9500000001")
    H = _h(org.id, tok)

    tid = client.post("/api/v1/sports/tournaments", json={
        "name_ta": "கிரிக்கெட்", "name_en": "Cricket",
        "sport": "cricket", "year": 2026, "format": "LEAGUE",
    }, headers=H).json()["id"]

    team_ids = []
    for name in ("Eagles", "Phoenix"):
        tr = client.post(f"/api/v1/sports/tournaments/{tid}/teams",
                         json={"name": name, "captain_name": f"{name} Cap",
                               "contact_phone": None, "is_fyc_team": False}, headers=H)
        team_ids.append(tr.json()["id"])
        client.patch(f"/api/v1/sports/tournaments/{tid}/teams/{tr.json()['id']}/status",
                    json={"status": "APPROVED"}, headers=H)
    client.post(f"/api/v1/sports/tournaments/{tid}/close-registration", headers=H)

    fixtures = client.post(f"/api/v1/sports/tournaments/{tid}/generate-fixtures", headers=H).json()
    fid = fixtures[0]["id"]
    return H, fid, team_ids


def _init_payload(bat_team, **overrides):
    payload = {
        "toss_winner_id": bat_team, "toss_decision": "BAT", "overs": 20,
        "striker_name": "Kumar", "non_striker_name": "Raj", "bowler_name": "Vel",
    }
    payload.update(overrides)
    return payload


def test_init_rejects_identical_striker_and_non_striker_names(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                    json=_init_payload(team_ids[0], non_striker_name="Kumar"), headers=H)
    assert r.status_code == 400
    assert "different players" in r.json()["detail"]


def test_init_rejects_names_differing_only_by_case_or_whitespace(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                    json=_init_payload(team_ids[0], striker_name="  KUMAR  ", non_striker_name="kumar"),
                    headers=H)
    assert r.status_code == 400


def test_wicket_without_new_batter_name_is_rejected_mid_innings(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0]), headers=H)
    assert init.status_code == 200, init.text
    p = init.json()["current_players"]

    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p["striker_id"], "non_striker_id": p["non_striker_id"],
        "bowler_id": p["bowler_id"], "runs_batter": 0, "is_wicket": True,
        "wicket_type": "BOWLED", "player_dismissed_id": p["striker_id"],
        # new_batter_name deliberately omitted — this is the exact bug: the
        # UI let the "Confirm Wicket" button submit with a blank field.
    }, headers=H)
    assert r.status_code == 400
    assert "new batter" in r.json()["detail"].lower()

    # The match must not have advanced — no ball recorded, wickets unchanged.
    ms = client.get(f"/api/v1/fixtures/{fid}/cricket", headers=H).json()
    assert ms["match_state"]["wickets"] == 0


def test_wicket_with_colliding_replacement_name_is_rejected(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0]), headers=H)
    p = init.json()["current_players"]  # striker=Kumar, non_striker=Raj

    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p["striker_id"], "non_striker_id": p["non_striker_id"],
        "bowler_id": p["bowler_id"], "runs_batter": 0, "is_wicket": True,
        "wicket_type": "BOWLED", "player_dismissed_id": p["striker_id"],
        "new_batter_name": "Raj",  # collides with the surviving non-striker
    }, headers=H)
    assert r.status_code == 400
    assert "different players" in r.json()["detail"]


def test_wicket_with_distinct_replacement_name_succeeds_and_stats_stay_separate(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0]), headers=H)
    p = init.json()["current_players"]

    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p["striker_id"], "non_striker_id": p["non_striker_id"],
        "bowler_id": p["bowler_id"], "runs_batter": 4, "is_wicket": False,
    }, headers=H)
    assert r.status_code == 200

    w = client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
        "striker_id": p["striker_id"], "non_striker_id": p["non_striker_id"],
        "bowler_id": p["bowler_id"], "runs_batter": 0, "is_wicket": True,
        "wicket_type": "BOWLED", "player_dismissed_id": p["striker_id"],
        "new_batter_name": "Suresh",
    }, headers=H)
    assert w.status_code == 200, w.text
    state = w.json()["match_state"]
    assert state["wickets"] == 1

    # Kumar (out, 4 runs) and Raj (not out, 0 runs) must be DISTINCT entries —
    # this is the exact regression: before the fix, a blank replacement name
    # would leave Kumar's id on the next ball and merge his stats with Raj's.
    names_to_runs = {b["name"]: b["runs"] for b in state["batters"].values()}
    assert names_to_runs.get("Kumar") == 4
    assert names_to_runs.get("Raj") == 0
    assert names_to_runs.get("Suresh") == 0  # just arrived, ledger entry only
    assert len(state["batters"]) == 3  # three distinct player ids, none merged


def test_second_innings_rejects_identical_names(client, db):
    H, fid, team_ids = _setup_fixture(client, db)
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init",
                       json=_init_payload(team_ids[0], overs=1), headers=H)
    p = init.json()["current_players"]
    # Bowl out the 1-over innings quickly (6 dot balls) to reach innings break.
    for _ in range(6):
        client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json={
            "striker_id": p["striker_id"], "non_striker_id": p["non_striker_id"],
            "bowler_id": p["bowler_id"], "runs_batter": 1,
        }, headers=H)

    r = client.post(f"/api/v1/fixtures/{fid}/cricket/second-innings",
                    json=_init_payload(team_ids[1], striker_name="Arun", non_striker_name="Arun"),
                    headers=H)
    assert r.status_code == 400
