import uuid

from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"chess-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, role="VOLUNTEER", name="Player"):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role=role, is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta=name, full_name_en=name))
    db.commit()
    return user


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def _setup(client, db, n_players=4):
    org = _make_org(db)
    mgr = _make_user(db, org.id, "9000000001", role="EXECUTIVE_MEMBER", name="Manager")
    mgr_tok = _login(client, org.id, "9000000001")
    players = []
    for i in range(n_players):
        phone = f"90000001{i:02d}"
        u = _make_user(db, org.id, phone, name=f"P{i}")
        players.append((u, _login(client, org.id, phone)))
    return org, mgr, mgr_tok, players


def _create(client, org_id, mgr_tok):
    r = client.post("/api/v1/chess/tournaments",
                    json={"name": "Club Knockout"}, headers=_h(org_id, mgr_tok))
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_full_knockout_flow(client, db):
    org, mgr, mgr_tok, players = _setup(client, db, n_players=4)
    tid = _create(client, org.id, mgr_tok)

    # Players register — all land in PENDING, none counted as approved yet.
    for u, tok in players:
        r = client.post(f"/api/v1/chess/tournaments/{tid}/register", headers=_h(org.id, tok))
        assert r.status_code == 200, r.text
        assert r.json()["my_status"] == "PENDING"

    r = client.get(f"/api/v1/chess/tournaments/{tid}", headers=_h(org.id, mgr_tok))
    body = r.json()
    assert body["entry_count"] == 0  # nobody approved yet
    assert body["pending_count"] == 4

    # Starting before approvals fails — no approved players.
    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=_h(org.id, mgr_tok))
    assert r.status_code == 400

    # Manager approves everyone.
    for u, _ in players:
        r = client.post(
            f"/api/v1/chess/tournaments/{tid}/registrations/{u.id}/decision",
            json={"approve": True}, headers=_h(org.id, mgr_tok))
        assert r.status_code == 200, r.text

    r = client.get(f"/api/v1/chess/tournaments/{tid}", headers=_h(org.id, mgr_tok))
    assert r.json()["entry_count"] == 4

    # A non-manager cannot approve.
    r = client.post(
        f"/api/v1/chess/tournaments/{tid}/registrations/{players[0][0].id}/decision",
        json={"approve": True}, headers=_h(org.id, players[1][1]))
    assert r.status_code == 403

    # Close registration → new registrations are rejected.
    r = client.post(f"/api/v1/chess/tournaments/{tid}/close", headers=_h(org.id, mgr_tok))
    assert r.status_code == 200
    assert r.json()["status"] == "REGISTRATION_CLOSED"

    # Start → bracket drawn, round 1 activated, current_round == 1.
    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=_h(org.id, mgr_tok))
    assert r.status_code == 200, r.text
    detail = r.json()
    assert detail["status"] == "IN_PROGRESS"
    assert detail["current_round"] == 1
    assert detail["rounds"] == 2
    r1 = [m for m in detail["matches"] if m["round"] == 1]
    r2 = [m for m in detail["matches"] if m["round"] == 2]
    assert len(r1) == 2 and len(r2) == 1
    assert all(m["activated"] for m in r1)
    assert not r2[0]["activated"]  # round 2 not started yet

    # Resolve round 1 via manager override (stands in for finished Arena games).
    for m in r1:
        r = client.post(
            f"/api/v1/chess/tournaments/{tid}/matches/{m['id']}/result",
            json={"winner_id": m["player_a"]["id"]}, headers=_h(org.id, mgr_tok))
        assert r.status_code == 200, r.text

    # Round 2 slot is filled but still not activated (manual gate).
    r = client.get(f"/api/v1/chess/tournaments/{tid}", headers=_h(org.id, mgr_tok))
    final = [m for m in r.json()["matches"] if m["round"] == 2][0]
    assert final["player_a"] and final["player_b"]
    assert not final["activated"]
    assert final["status"] != "READY"

    # Manager starts round 2.
    r = client.post(f"/api/v1/chess/tournaments/{tid}/next-round", headers=_h(org.id, mgr_tok))
    assert r.status_code == 200, r.text
    final = [m for m in r.json()["matches"] if m["round"] == 2][0]
    assert final["activated"] and final["status"] == "READY"

    # Decide the final → champion crowned, tournament complete.
    r = client.post(
        f"/api/v1/chess/tournaments/{tid}/matches/{final['id']}/result",
        json={"winner_id": final["player_a"]["id"]}, headers=_h(org.id, mgr_tok))
    assert r.status_code == 200, r.text
    done = r.json()
    assert done["status"] == "COMPLETED"
    assert done["champion"]["id"] == final["player_a"]["id"]


def test_ready_gating_blocks_solo_play(client, db):
    org, mgr, mgr_tok, players = _setup(client, db, n_players=2)
    tid = _create(client, org.id, mgr_tok)
    for u, tok in players:
        client.post(f"/api/v1/chess/tournaments/{tid}/register", headers=_h(org.id, tok))
        client.post(f"/api/v1/chess/tournaments/{tid}/registrations/{u.id}/decision",
                    json={"approve": True}, headers=_h(org.id, mgr_tok))
    client.post(f"/api/v1/chess/tournaments/{tid}/close", headers=_h(org.id, mgr_tok))
    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=_h(org.id, mgr_tok))
    match = [m for m in r.json()["matches"] if m["round"] == 1][0]
    mid = match["id"]

    # Player A tries to play alone → blocked until B is ready.
    tok_a = next(t for u, t in players if str(u.id) == match["player_a"]["id"])
    tok_b = next(t for u, t in players if str(u.id) == match["player_b"]["id"])
    r = client.post(f"/api/v1/chess/tournaments/{tid}/matches/{mid}/play", headers=_h(org.id, tok_a))
    assert r.status_code == 409  # waiting for opponent

    # B marks ready, now A can open the board.
    client.post(f"/api/v1/chess/tournaments/{tid}/matches/{mid}/ready", headers=_h(org.id, tok_b))
    r = client.post(f"/api/v1/chess/tournaments/{tid}/matches/{mid}/play", headers=_h(org.id, tok_a))
    assert r.status_code == 200, r.text
    assert r.json()["game_id"]


def test_odd_players_get_a_bye(client, db):
    org, mgr, mgr_tok, players = _setup(client, db, n_players=3)
    tid = _create(client, org.id, mgr_tok)
    for u, tok in players:
        client.post(f"/api/v1/chess/tournaments/{tid}/register", headers=_h(org.id, tok))
        client.post(f"/api/v1/chess/tournaments/{tid}/registrations/{u.id}/decision",
                    json={"approve": True}, headers=_h(org.id, mgr_tok))
    client.post(f"/api/v1/chess/tournaments/{tid}/close", headers=_h(org.id, mgr_tok))
    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=_h(org.id, mgr_tok))
    detail = r.json()
    assert detail["rounds"] == 2
    r1 = [m for m in detail["matches"] if m["round"] == 1]
    # 3 players in a size-4 bracket → one real match + one bye.
    byes = [m for m in r1 if m["status"] == "BYE"]
    assert len(byes) == 1
    # The bye winner is already sitting in the round-2 slot.
    final = [m for m in detail["matches"] if m["round"] == 2][0]
    assert final["player_a"] or final["player_b"]


def test_physical_conduct_sets_venue(client, db):
    org, mgr, mgr_tok, players = _setup(client, db, n_players=2)
    tid = _create(client, org.id, mgr_tok)
    for u, tok in players:
        client.post(f"/api/v1/chess/tournaments/{tid}/register", headers=_h(org.id, tok))
        client.post(f"/api/v1/chess/tournaments/{tid}/registrations/{u.id}/decision",
                    json={"approve": True}, headers=_h(org.id, mgr_tok))
    client.post(f"/api/v1/chess/tournaments/{tid}/close", headers=_h(org.id, mgr_tok))
    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=_h(org.id, mgr_tok))
    match = [m for m in r.json()["matches"] if m["round"] == 1][0]
    mid = match["id"]

    r = client.post(
        f"/api/v1/chess/tournaments/{tid}/matches/{mid}/conduct",
        json={"mode": "PHYSICAL", "venue": "FYC Hall"}, headers=_h(org.id, mgr_tok))
    assert r.status_code == 200, r.text
    m = [x for x in r.json()["matches"] if x["id"] == mid][0]
    assert m["conduct_mode"] == "PHYSICAL"
    assert m["venue"] == "FYC Hall"

    # Online play is blocked on a physical match.
    tok_a = next(t for u, t in players if str(u.id) == match["player_a"]["id"])
    r = client.post(f"/api/v1/chess/tournaments/{tid}/matches/{mid}/play", headers=_h(org.id, tok_a))
    assert r.status_code == 400
