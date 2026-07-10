"""End-to-end 'can we actually run a tournament?' tests.

Two complete lifecycles exercised through the real HTTP API:

  * Chess  — knockout: create → register → approve/reject → close → draw
             bracket (with a fair bye for an odd count) → Ready-gate → play →
             manual Start-Next-Round → app/in-person conduct → champion.
  * Cricket — league: create → register teams → approve → close → generate
             fixtures → live ball-by-ball scoring (runs, extras, wicket, undo)
             → record result → standings.

These are deliberately written against the routers a real organizer hits, so a
green run here means an organizer can conduct a tournament front to back.
"""
import uuid

from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


# ── shared fixtures/helpers ──────────────────────────────────────────────────
def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"tf-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, role="VOLUNTEER", name="Player"):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role=role, is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta=name, full_name_en=name))
    db.commit()
    return u


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


# ══════════════════════════════════════════════════════════════════════════════
# CHESS — full knockout lifecycle
# ══════════════════════════════════════════════════════════════════════════════
def test_conduct_full_chess_tournament(client, db):
    org = _make_org(db)
    mgr = _make_user(db, org.id, "9700000001", role="EXECUTIVE_MEMBER", name="Manager")
    mtok = _login(client, org.id, "9700000001")
    # 4 people register; only 3 will be approved → exercises rejection + an odd
    # bracket (bye).
    players = []
    for i in range(4):
        u = _make_user(db, org.id, f"97000001{i:02d}", name=f"P{i}")
        players.append((u, _login(client, org.id, f"97000001{i:02d}")))

    base = "/api/v1/chess/tournaments"

    # Create.
    r = client.post(base, json={"name": "Village Chess Cup"}, headers=_h(org.id, mtok))
    assert r.status_code == 201, r.text
    tid = r.json()["id"]
    assert r.json()["status"] == "REGISTRATION_OPEN"

    # Register — everyone lands PENDING (nobody counted as approved yet).
    for u, tok in players:
        rr = client.post(f"{base}/{tid}/register", headers=_h(org.id, tok))
        assert rr.status_code == 200, rr.text
        assert rr.json()["my_status"] == "PENDING"
    snap = client.get(f"{base}/{tid}", headers=_h(org.id, mtok)).json()
    assert snap["entry_count"] == 0 and snap["pending_count"] == 4

    # A non-manager cannot approve.
    deny = client.post(f"{base}/{tid}/registrations/{players[0][0].id}/decision",
                       json={"approve": True}, headers=_h(org.id, players[1][1]))
    assert deny.status_code == 403

    # Manager approves 3, rejects 1.
    for u, _ in players[:3]:
        ok = client.post(f"{base}/{tid}/registrations/{u.id}/decision",
                         json={"approve": True}, headers=_h(org.id, mtok))
        assert ok.status_code == 200, ok.text
    rej = client.post(f"{base}/{tid}/registrations/{players[3][0].id}/decision",
                      json={"approve": False}, headers=_h(org.id, mtok))
    assert rej.status_code == 200
    snap = client.get(f"{base}/{tid}", headers=_h(org.id, mtok)).json()
    assert snap["entry_count"] == 3 and snap["pending_count"] == 0

    # Close registration (manual), then start.
    assert client.post(f"{base}/{tid}/close", headers=_h(org.id, mtok)).json()["status"] == "REGISTRATION_CLOSED"
    started = client.post(f"{base}/{tid}/start", headers=_h(org.id, mtok))
    assert started.status_code == 200, started.text
    detail = started.json()
    assert detail["status"] == "IN_PROGRESS"
    assert detail["current_round"] == 1
    assert detail["rounds"] == 2  # 3 players → size-4 bracket

    r1 = [m for m in detail["matches"] if m["round"] == 1]
    r2 = [m for m in detail["matches"] if m["round"] == 2]
    assert len(r1) == 2 and len(r2) == 1
    byes = [m for m in r1 if m["status"] == "BYE"]
    real = [m for m in r1 if m["status"] == "READY"]
    assert len(byes) == 1 and len(real) == 1          # odd count → exactly one bye
    assert all(m["activated"] for m in r1)            # round 1 live
    assert not r2[0]["activated"]                     # final not started yet
    # Bye winner already sits in the final.
    assert r2[0]["player_a"] or r2[0]["player_b"]

    # Ready-gate: a player in the real match cannot open the board alone.
    rm = real[0]
    a_tok = next(t for u, t in players if str(u.id) == rm["player_a"]["id"])
    b_tok = next(t for u, t in players if str(u.id) == rm["player_b"]["id"])
    solo = client.post(f"{base}/{tid}/matches/{rm['id']}/play", headers=_h(org.id, a_tok))
    assert solo.status_code == 409                    # waiting for opponent
    client.post(f"{base}/{tid}/matches/{rm['id']}/ready", headers=_h(org.id, b_tok))
    play = client.post(f"{base}/{tid}/matches/{rm['id']}/play", headers=_h(org.id, a_tok))
    assert play.status_code == 200 and play.json()["game_id"]

    # Organizer records the round-1 winner (stands in for the finished game).
    res = client.post(f"{base}/{tid}/matches/{rm['id']}/result",
                      json={"winner_id": rm["player_a"]["id"]}, headers=_h(org.id, mtok))
    assert res.status_code == 200, res.text

    # Final slot now filled but the round is NOT auto-activated (manual gate).
    final = [m for m in client.get(f"{base}/{tid}", headers=_h(org.id, mtok)).json()["matches"]
             if m["round"] == 2][0]
    assert final["player_a"] and final["player_b"]
    assert not final["activated"] and final["status"] != "READY"

    # Organizer runs the final in person, at a venue.
    conducted = client.post(f"{base}/{tid}/matches/{final['id']}/conduct",
                            json={"mode": "PHYSICAL", "venue": "FYC Club Hall"},
                            headers=_h(org.id, mtok))
    assert conducted.status_code == 200, conducted.text
    fm = [m for m in conducted.json()["matches"] if m["id"] == final["id"]][0]
    assert fm["conduct_mode"] == "PHYSICAL" and fm["venue"] == "FYC Club Hall"

    # Start the final round, then record the physical result → champion.
    nxt = client.post(f"{base}/{tid}/next-round", headers=_h(org.id, mtok))
    assert nxt.status_code == 200, nxt.text
    assert [m for m in nxt.json()["matches"] if m["round"] == 2][0]["activated"]

    done = client.post(f"{base}/{tid}/matches/{final['id']}/result",
                       json={"winner_id": final["player_a"]["id"]}, headers=_h(org.id, mtok))
    assert done.status_code == 200, done.text
    body = done.json()
    assert body["status"] == "COMPLETED"
    assert body["champion"]["id"] == final["player_a"]["id"]


# ══════════════════════════════════════════════════════════════════════════════
# CRICKET — full league lifecycle with live ball-by-ball scoring
# ══════════════════════════════════════════════════════════════════════════════
def test_conduct_full_cricket_tournament(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9600000001", role="EXECUTIVE_MEMBER", name="Organizer")
    tok = _login(client, org.id, "9600000001")
    H = _h(org.id, tok)

    # Create a cricket league.
    r = client.post("/api/v1/sports/tournaments", json={
        "name_ta": "கிரிக்கெட் கோப்பை", "name_en": "Cricket Cup",
        "sport": "cricket", "year": 2026, "format": "LEAGUE",
    }, headers=H)
    assert r.status_code == 201, r.text
    tid = r.json()["id"]

    # Register two teams — MANUAL_APPROVAL → they start PENDING.
    team_ids = []
    for name in ("Eagles", "Phoenix"):
        tr = client.post(f"/api/v1/sports/tournaments/{tid}/teams",
                         json={"name": name, "captain_name": f"{name} Cap",
                               "contact_phone": None, "is_fyc_team": False}, headers=H)
        assert tr.status_code == 201, tr.text
        assert tr.json()["status"] == "PENDING"
        team_ids.append(tr.json()["id"])

    # Fixtures cannot be generated while registration is still open.
    early = client.post(f"/api/v1/sports/tournaments/{tid}/generate-fixtures", headers=H)
    assert early.status_code == 400

    # Approve both teams, then close registration.
    for team_id in team_ids:
        ap = client.patch(f"/api/v1/sports/tournaments/{tid}/teams/{team_id}/status",
                          json={"status": "APPROVED"}, headers=H)
        assert ap.status_code == 200 and ap.json()["status"] == "APPROVED"
    assert client.post(f"/api/v1/sports/tournaments/{tid}/close-registration", headers=H).status_code == 200

    # Generate the round-robin fixtures → one Eagles vs Phoenix match.
    gen = client.post(f"/api/v1/sports/tournaments/{tid}/generate-fixtures", headers=H)
    assert gen.status_code == 200, gen.text
    fixtures = gen.json()
    assert len(fixtures) == 1
    fx = fixtures[0]
    fid = fx["id"]

    # ── Live ball-by-ball scoring ───────────────────────────────────────────
    bat_team = team_ids[0]  # Eagles win the toss and bat
    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init", json={
        "toss_winner_id": bat_team, "toss_decision": "BAT", "overs": 5,
        "striker_name": "Striker", "non_striker_name": "NonStriker",
        "bowler_name": "Bowler",
    }, headers=H)
    assert init.status_code == 200, init.text
    cur = init.json()["current_players"]
    striker, non_striker, bowler = cur["striker_id"], cur["non_striker_id"], cur["bowler_id"]

    def ball(**kw):
        payload = {"striker_id": striker, "non_striker_id": non_striker,
                   "bowler_id": bowler, "runs_batter": 0, "extras_type": "NONE",
                   "extras_runs": 0, "is_wicket": False}
        payload.update(kw)
        return client.post(f"/api/v1/fixtures/{fid}/cricket/ball", json=payload, headers=H)

    assert ball(runs_batter=4).status_code == 200          # boundary
    assert ball(runs_batter=1).status_code == 200          # single
    assert ball(extras_type="WIDE", extras_runs=1).status_code == 200  # extra
    st = ball(runs_batter=6).json()["match_state"]         # six
    assert st["score"] > 0                                 # runs are accumulating
    score_before_wicket = st["score"]

    # A wicket falls; a new batter comes in.
    w = ball(is_wicket=True, wicket_type="BOWLED",
             player_dismissed_id=striker, new_batter_name="Fresh Bat")
    assert w.status_code == 200, w.text
    assert w.json()["match_state"]["wickets"] == 1

    # Undo the wicket ball → wickets back to 0 (scoring is correctable live).
    undo = client.post(f"/api/v1/fixtures/{fid}/cricket/undo", headers=H)
    assert undo.status_code == 200
    assert undo.json()["match_state"]["wickets"] == 0
    assert undo.json()["match_state"]["score"] == score_before_wicket

    # Only the assigned scorer (exec) can score — a random member can't.
    outsider = _make_user(db, org.id, "9600000099", name="Outsider")
    otok = _login(client, org.id, "9600000099")
    blocked = client.post(f"/api/v1/fixtures/{fid}/cricket/ball",
                          json={"striker_id": striker, "non_striker_id": non_striker,
                                "bowler_id": bowler, "runs_batter": 1},
                          headers=_h(org.id, otok))
    assert blocked.status_code == 403

    # ── Record the result → standings update ────────────────────────────────
    res = client.post(f"/api/v1/sports/tournaments/{tid}/fixtures/{fid}/result", json={
        "team_a_score": "78/4", "team_b_score": "60/9",
        "winner_id": fx["team_a_id"], "result_notes": "Eagles win by 18 runs",
    }, headers=H)
    assert res.status_code == 200, res.text
    assert res.json()["status"] == "COMPLETED"
    assert str(res.json()["winner_id"]) == str(fx["team_a_id"])

    standings = client.get(f"/api/v1/sports/tournaments/{tid}/standings", headers=H).json()
    by_id = {t["id"]: t for t in standings}
    winner = by_id[fx["team_a_id"]]
    loser = by_id[fx["team_b_id"]]
    assert winner["wins"] == 1 and winner["points"] == 3
    assert loser["losses"] == 1
