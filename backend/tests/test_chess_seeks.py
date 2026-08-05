"""
Open seeks — the lobby, and the shareable "play me" link.

A directed challenge needs you to already know your opponent, which is no use to
a member who opens the app at 9pm and just wants a game. A seek is undirected:
it sits in a lobby until someone takes it, and its short code makes it a link.
"""
import uuid

from app.core.security import create_access_token, get_password_hash
from app.models.chess import ChessGame, ChessSeek
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}",
                       name_ta="x", name_en="x")
    db.add(org)
    db.commit()
    return org


def _user(db, org, name, phone):
    u = User(organization_id=org.id, phone_number=phone,
             password_hash=get_password_hash("x"), role="USER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.commit()
    return u


def _auth(u, org):
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(org.id))}",
        "X-Organization-ID": str(org.id),
    }


def _pair(db):
    org = _org(db)
    return org, _user(db, org, "Asha", "9200000001"), _user(db, org, "Bala", "9200000002")


# ── Creating ──────────────────────────────────────────────────────────────────

def test_seek_is_created_with_a_shareable_code(client, db):
    org, a, _ = _pair(db)
    r = client.post("/api/v1/chess/seeks", json={"time_control": "rapid_10_0"},
                    headers=_auth(a, org))
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["status"] == "open"
    assert body["is_mine"] is True
    assert body["short_code"]          # this is what gets sent on WhatsApp


def test_unknown_time_control_is_rejected(client, db):
    org, a, _ = _pair(db)
    r = client.post("/api/v1/chess/seeks", json={"time_control": "rapid_9000"},
                    headers=_auth(a, org))
    assert r.status_code == 400


def test_creating_twice_updates_the_existing_seek(client, db):
    """A lobby full of one player's duplicates is noise, and the second could
    never be honoured anyway."""
    org, a, _ = _pair(db)
    first = client.post("/api/v1/chess/seeks", json={"time_control": "blitz_5_0"},
                        headers=_auth(a, org)).json()
    second = client.post("/api/v1/chess/seeks", json={"time_control": "rapid_10_0"},
                         headers=_auth(a, org)).json()
    assert second["id"] == first["id"]
    assert second["time_control"] == "rapid_10_0"
    assert db.query(ChessSeek).filter(ChessSeek.status == "open").count() == 1


# ── The lobby ─────────────────────────────────────────────────────────────────

def test_lobby_shows_other_players_offers_and_flags_your_own(client, db):
    org, a, b = _pair(db)
    client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org))
    client.post("/api/v1/chess/seeks", json={}, headers=_auth(b, org))

    seen = client.get("/api/v1/chess/seeks", headers=_auth(a, org)).json()
    assert len(seen) == 2
    mine = [s for s in seen if s["is_mine"]]
    theirs = [s for s in seen if not s["is_mine"]]
    assert len(mine) == 1 and len(theirs) == 1
    assert theirs[0]["creator_name"] == "Bala"


def test_a_taken_seek_leaves_the_lobby(client, db):
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()
    client.post(f"/api/v1/chess/seeks/{seek['id']}/accept", headers=_auth(b, org))
    assert client.get("/api/v1/chess/seeks", headers=_auth(a, org)).json() == []


# ── Accepting ─────────────────────────────────────────────────────────────────

def test_accepting_starts_a_real_game_with_the_seek_clock(client, db):
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks",
                       json={"time_control": "rapid_10_0", "preferred_color": "white"},
                       headers=_auth(a, org)).json()

    r = client.post(f"/api/v1/chess/seeks/{seek['id']}/accept", headers=_auth(b, org))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["opponent_name"] == "Asha"
    assert body["color"] == "black"        # creator asked for white
    assert body["time_control"] == "rapid_10_0"

    game = db.query(ChessGame).filter(ChessGame.id == uuid.UUID(body["game_id"])).first()
    assert game.white_id == a.id and game.black_id == b.id
    assert game.status == "waiting"
    # The clock is banked at creation, as everywhere else.
    assert game.white_time_ms == 600_000


def test_creator_colour_preference_is_honoured(client, db):
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={"preferred_color": "black"},
                       headers=_auth(a, org)).json()
    body = client.post(f"/api/v1/chess/seeks/{seek['id']}/accept",
                       headers=_auth(b, org)).json()
    assert body["color"] == "white"        # accepter gets the other colour
    game = db.query(ChessGame).filter(ChessGame.id == uuid.UUID(body["game_id"])).first()
    assert game.black_id == a.id


def test_you_cannot_accept_your_own_seek(client, db):
    org, a, _ = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()
    r = client.post(f"/api/v1/chess/seeks/{seek['id']}/accept", headers=_auth(a, org))
    assert r.status_code == 400


def test_only_one_person_can_take_a_seek(client, db):
    """Two people tapping the same offer must not both get a game."""
    org, a, b = _pair(db)
    c = _user(db, org, "Chandra", "9200000003")
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()

    first = client.post(f"/api/v1/chess/seeks/{seek['id']}/accept", headers=_auth(b, org))
    second = client.post(f"/api/v1/chess/seeks/{seek['id']}/accept", headers=_auth(c, org))

    assert first.status_code == 200
    assert second.status_code == 409, second.text
    assert db.query(ChessGame).count() == 1


# ── Sharing ───────────────────────────────────────────────────────────────────

def test_short_code_resolves_for_the_person_you_sent_it_to(client, db):
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()

    r = client.get(f"/api/v1/chess/seeks/by-code/{seek['short_code']}",
                   headers=_auth(b, org))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["id"] == seek["id"]
    assert body["creator_name"] == "Asha"
    assert body["is_mine"] is False        # the recipient is not the creator


def test_unknown_code_is_a_clear_404(client, db):
    org, a, _ = _pair(db)
    r = client.get("/api/v1/chess/seeks/by-code/NOPE99", headers=_auth(a, org))
    assert r.status_code == 404


# ── Cancelling ────────────────────────────────────────────────────────────────

def test_creator_can_withdraw_their_offer(client, db):
    org, a, _ = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()
    assert client.delete(f"/api/v1/chess/seeks/{seek['id']}",
                         headers=_auth(a, org)).status_code == 204
    assert client.get("/api/v1/chess/seeks", headers=_auth(a, org)).json() == []


def test_you_cannot_withdraw_someone_elses_offer(client, db):
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()
    assert client.delete(f"/api/v1/chess/seeks/{seek['id']}",
                         headers=_auth(b, org)).status_code == 404


def test_a_withdrawn_seek_cannot_then_be_accepted(client, db):
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()
    client.delete(f"/api/v1/chess/seeks/{seek['id']}", headers=_auth(a, org))
    r = client.post(f"/api/v1/chess/seeks/{seek['id']}/accept", headers=_auth(b, org))
    assert r.status_code == 409


# ── Expiry ────────────────────────────────────────────────────────────────────

def test_stale_seeks_drop_out_of_the_lobby(client, db):
    """An offer nobody took should not sit there overnight."""
    from datetime import datetime, timedelta, timezone
    org, a, b = _pair(db)
    seek = client.post("/api/v1/chess/seeks", json={}, headers=_auth(a, org)).json()

    row = db.query(ChessSeek).filter(ChessSeek.id == uuid.UUID(seek["id"])).first()
    row.expires_at = datetime.now(timezone.utc) - timedelta(minutes=5)
    db.commit()

    assert client.get("/api/v1/chess/seeks", headers=_auth(b, org)).json() == []
