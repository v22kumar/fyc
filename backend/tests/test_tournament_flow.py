"""The tournament flow service, and the two failure modes it exists to close.

**A drawn game used to park its match LIVE forever.** `auto_resolve` skipped
draws with a comment that "a replay/decider is needed" — and no replay path
existed. `next-round` refuses while anything is undecided, so one drawn game
stalled the whole event. Draws are common in chess.

**A crash during start stranded the tournament in STARTING_LOCK** — a status no
enum contains, that the app renders as a dead screen, and that no endpoint
could clear.
"""
import uuid

from app.models.chess import ChessGame
from app.models.chess_tournament import (
    ChessTournament,
    ChessTournamentEntry,
    ChessTournamentMatch,
)
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash
from app.services import tournament_flow as flow


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"fl-{uuid.uuid4().hex[:8]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _user(db, org_id, phone, role="VOLUNTEER", name="Player"):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role=role, is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta=name, full_name_en=name))
    db.commit()
    return u


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone,
                          "password": "pass"})
    return {"Authorization": f"Bearer {r.json()['access_token']}",
            "X-Organization-ID": str(org_id)}


def _tournament(db, client, n_players=4):
    """A started tournament with n approved players, via the real API."""
    org = _org(db)
    mgr = _user(db, org.id, "9600000001", role="EXECUTIVE_MEMBER", name="Manager")
    mh = _login(client, org.id, "9600000001")
    r = client.post("/api/v1/chess/tournaments",
                    json={"name": "Flow Cup"}, headers=mh)
    tid = r.json()["id"]

    players = []
    for i in range(n_players):
        p = _user(db, org.id, f"96000001{i:02d}", name=f"P{i}")
        ph = _login(client, org.id, p.phone_number)
        client.post(f"/api/v1/chess/tournaments/{tid}/register", headers=ph)
        client.post(
            f"/api/v1/chess/tournaments/{tid}/registrations/{p.id}/decision",
            json={"approve": True}, headers=mh)
        players.append((p, ph))

    client.post(f"/api/v1/chess/tournaments/{tid}/close", headers=mh)
    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=mh)
    assert r.status_code == 200, r.text
    return org, mgr, mh, tid, players


# ── draws ────────────────────────────────────────────────────────────────────


def _make_live_with_result(db, tid, result):
    """Attach a finished game to the first READY match and mark it LIVE."""
    m = (db.query(ChessTournamentMatch)
           .filter(ChessTournamentMatch.tournament_id == uuid.UUID(tid),
                   ChessTournamentMatch.round == 1,
                   ChessTournamentMatch.status == "READY")
           .first())
    game = ChessGame(id=uuid.uuid4(), organization_id=m.organization_id,
                     white_id=m.player_a_id, black_id=m.player_b_id,
                     mode="online", status="finished", result=result)
    db.add(game)
    m.game_id = game.id
    m.status = "LIVE"
    db.commit()
    return m


def test_a_draw_sends_the_match_to_replay_instead_of_parking_it(client, db):
    org, mgr, mh, tid, players = _tournament(db, client)
    m = _make_live_with_result(db, tid, "draw")

    detail = client.get(f"/api/v1/chess/tournaments/{tid}", headers=mh).json()
    row = next(x for x in detail["matches"] if x["id"] == str(m.id))

    assert row["status"] == "READY", "playable again, not LIVE forever"
    assert row["game_id"] is None, "the drawn game is unlinked"
    assert row["a_ready"] is False and row["b_ready"] is False, (
        "both players must consciously come back to the board"
    )
    assert row["winner_id"] is None


def test_a_replayed_match_can_be_played_again(client, db):
    org, mgr, mh, tid, players = _tournament(db, client)
    m = _make_live_with_result(db, tid, "draw")
    client.get(f"/api/v1/chess/tournaments/{tid}", headers=mh)  # resolves

    # Both players ready up and play — a fresh game is created.
    a_h = next(h for (p, h) in players if p.id == m.player_a_id)
    b_h = next(h for (p, h) in players if p.id == m.player_b_id)
    client.post(f"/api/v1/chess/tournaments/{tid}/matches/{m.id}/ready", headers=a_h)
    client.post(f"/api/v1/chess/tournaments/{tid}/matches/{m.id}/ready", headers=b_h)
    r = client.post(f"/api/v1/chess/tournaments/{tid}/matches/{m.id}/play", headers=a_h)
    assert r.status_code == 200, r.text
    assert r.json()["game_id"] is not None


def test_a_decisive_game_still_advances(client, db):
    org, mgr, mh, tid, players = _tournament(db, client)
    m = _make_live_with_result(db, tid, "white_wins")

    detail = client.get(f"/api/v1/chess/tournaments/{tid}", headers=mh).json()
    row = next(x for x in detail["matches"] if x["id"] == str(m.id))
    assert row["status"] == "DONE"
    assert row["winner_id"] == str(m.player_a_id)


def test_the_organizer_can_still_decide_a_tie(client, db):
    """The result override is the tiebreak of last resort after repeated draws."""
    org, mgr, mh, tid, players = _tournament(db, client)
    m = _make_live_with_result(db, tid, "draw")
    client.get(f"/api/v1/chess/tournaments/{tid}", headers=mh)

    r = client.post(
        f"/api/v1/chess/tournaments/{tid}/matches/{m.id}/result",
        json={"winner_id": str(m.player_a_id)}, headers=mh)
    assert r.status_code == 200, r.text
    row = next(x for x in r.json()["matches"] if x["id"] == str(m.id))
    assert row["winner_id"] == str(m.player_a_id)


def test_a_drawn_match_no_longer_blocks_the_round_forever(client, db):
    """The original stall: draw → LIVE forever → next-round refuses forever.

    After the replay the match is undecided but *playable* — and once decided
    (here by the organizer), the round can end.
    """
    org, mgr, mh, tid, players = _tournament(db, client, n_players=4)
    # Decide match 0 normally, draw match 1.
    matches = (db.query(ChessTournamentMatch)
                 .filter(ChessTournamentMatch.tournament_id == uuid.UUID(tid),
                         ChessTournamentMatch.round == 1)
                 .order_by(ChessTournamentMatch.slot).all())
    client.post(
        f"/api/v1/chess/tournaments/{tid}/matches/{matches[0].id}/result",
        json={"winner_id": str(matches[0].player_a_id)}, headers=mh)
    m1 = matches[1]
    game = ChessGame(id=uuid.uuid4(), organization_id=m1.organization_id,
                     white_id=m1.player_a_id, black_id=m1.player_b_id,
                     mode="online", status="finished", result="draw")
    db.add(game)
    m1.game_id = game.id
    m1.status = "LIVE"
    db.commit()

    r = client.post(f"/api/v1/chess/tournaments/{tid}/next-round", headers=mh)
    assert r.status_code == 400, "a replayed match is still undecided"

    client.post(
        f"/api/v1/chess/tournaments/{tid}/matches/{m1.id}/result",
        json={"winner_id": str(m1.player_b_id)}, headers=mh)
    r = client.post(f"/api/v1/chess/tournaments/{tid}/next-round", headers=mh)
    assert r.status_code == 200, r.text


# ── the lock ─────────────────────────────────────────────────────────────────


def test_a_stranded_starting_lock_is_recoverable(client, db):
    """A start that died after taking the lock used to hold the event hostage.

    Pressing Start again is the recovery: the half-made draw is cleared and a
    fresh one made.
    """
    org = _org(db)
    mgr = _user(db, org.id, "9600000201", role="EXECUTIVE_MEMBER")
    mh = _login(client, org.id, "9600000201")
    r = client.post("/api/v1/chess/tournaments", json={"name": "Lock Cup"},
                    headers=mh)
    tid = r.json()["id"]
    for i in range(2):
        p = _user(db, org.id, f"96000003{i:02d}", name=f"L{i}")
        ph = _login(client, org.id, p.phone_number)
        client.post(f"/api/v1/chess/tournaments/{tid}/register", headers=ph)
        client.post(
            f"/api/v1/chess/tournaments/{tid}/registrations/{p.id}/decision",
            json={"approve": True}, headers=mh)

    # Simulate the crash: the lock taken, half a bracket written, no commit
    # completing the start.
    tour = db.get(ChessTournament, uuid.UUID(tid))
    tour.status = "STARTING_LOCK"
    db.add(ChessTournamentMatch(
        id=uuid.uuid4(), organization_id=org.id,
        tournament_id=tour.id, round=1, slot=0, status="PENDING"))
    db.commit()

    r = client.post(f"/api/v1/chess/tournaments/{tid}/start", headers=mh)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "IN_PROGRESS"
    assert len(body["matches"]) == 1, "the half-made draw was cleared, not doubled"


# A note on what is NOT tested here: the start endpoint also restores the
# previous status if the draw itself raises mid-request. That path calls
# `db.rollback()`, and this suite's fixture binds the app and the test to one
# session inside one outer transaction — a rollback erases the test's own
# fixtures, so the restoration cannot be observed from here (verified
# empirically; commit-then-rollback loses the committed row in this harness).
# The user-facing guarantee does not depend on it: STARTING_LOCK is itself
# startable, so even a crash that skips the restore leaves the organizer one
# press away from recovery — which the test above proves.


# ── the seeding invariant, now unit-testable ─────────────────────────────────


def test_byes_land_on_different_seeds(db):
    """Front-against-back pairing: with 5 in a bracket of 8, the three byes go
    to three different players rather than gifting one a free semi-final."""
    org = _org(db)
    users = [_user_row(db, org.id, i) for i in range(5)]
    tour = ChessTournament(id=uuid.uuid4(), organization_id=org.id,
                           name="Seed Cup", status="REGISTRATION_CLOSED")
    db.add(tour)
    db.commit()

    flow.draw_bracket(db, tour, org.id, [u.id for u in users])
    db.commit()

    r1 = (db.query(ChessTournamentMatch)
            .filter(ChessTournamentMatch.tournament_id == tour.id,
                    ChessTournamentMatch.round == 1).all())
    byes = [m for m in r1 if m.status == "BYE"]
    assert len(byes) == 3
    assert len({m.player_a_id for m in byes}) == 3
    # And every bye already advanced its player into round 2.
    assert all(m.winner_id is not None for m in byes)


def _user_row(db, org_id, i):
    u = User(organization_id=org_id, phone_number=f"96000005{i:02d}",
             password_hash="x", role="VOLUNTEER", is_verified=True)
    db.add(u)
    db.commit()
    return u
