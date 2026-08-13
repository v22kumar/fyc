import uuid

from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.models.notification import Notification
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"chess-ch-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, name="Player"):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role="VOLUNTEER", is_verified=True)
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


def test_challenge_notifies_the_opponent(client, db):
    """Creating an online challenge must leave a notification for the opponent
    so a player who isn't sitting on the inbox screen still learns of it.

    This is the regression guard for the 'play requests never received' bug:
    previously create_challenge did a DB write only, with no push and no
    in-app record, so delivery depended entirely on the recipient polling.
    """
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000001", name="Alice")
    bob = _make_user(db, org.id, "9100000002", name="Bob")
    alice_tok = _login(client, org.id, "9100000001")

    r = client.post("/api/v1/chess/challenges",
                    json={"challenged_id": str(bob.id), "time_control": "untimed"},
                    headers=_h(org.id, alice_tok))
    assert r.status_code == 201, r.text

    # Bob (the challenged player) should now have a CHESS notification whose
    # data payload tells the app to open the challenge inbox.
    notes = (
        db.query(Notification)
        .filter(Notification.user_id == bob.id,
                Notification.notification_type == "CHESS")
        .all()
    )
    assert len(notes) == 1, "the opponent must be notified of an incoming challenge"
    note = notes[0]
    assert note.data.get("type") == "chess_challenge"
    # The tab is part of the contract, not decoration: without it the tap opens
    # the list of people you could challenge, beside the invitation itself.
    assert note.data.get("route") == "/chess/challenge?tab=inbox"
    assert "Alice" in note.body_en

    # And the notification is for Bob, never echoed back to the challenger.
    alice_notes = (
        db.query(Notification)
        .filter(Notification.user_id == alice.id,
                Notification.notification_type == "CHESS")
        .count()
    )
    assert alice_notes == 0


def test_accept_notifies_the_challenger(client, db):
    """Accepting a challenge must notify the original challenger so their app
    (which may not be polling) knows the game has started."""
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000011", name="Alice")
    bob = _make_user(db, org.id, "9100000012", name="Bob")
    alice_tok = _login(client, org.id, "9100000011")
    bob_tok = _login(client, org.id, "9100000012")

    r = client.post("/api/v1/chess/challenges",
                    json={"challenged_id": str(bob.id), "time_control": "untimed"},
                    headers=_h(org.id, alice_tok))
    assert r.status_code == 201, r.text
    challenge_id = r.json()["id"]

    r = client.post(f"/api/v1/chess/challenges/{challenge_id}/accept",
                    headers=_h(org.id, bob_tok))
    assert r.status_code == 200, r.text
    game_id = r.json()["game_id"]

    accept_notes = (
        db.query(Notification)
        .filter(Notification.user_id == alice.id,
                Notification.notification_type == "CHESS",
                Notification.title_en.like("%accepted%"))
        .all()
    )
    assert len(accept_notes) == 1, "the challenger must be told their challenge was accepted"
    assert accept_notes[0].data.get("type") == "chess_accept"
    assert accept_notes[0].data.get("game_id") == str(game_id)


def test_active_game_gives_challenger_a_reliable_join_signal(client, db):
    """After a challenge is accepted, BOTH players must be able to discover the
    resulting game by polling /chess/games/active — this is the fix for the
    challenger (who only got a best-effort push before) never joining, leaving
    the opponent stuck on 'waiting for opponent'."""
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000101", name="Alice")
    bob = _make_user(db, org.id, "9100000102", name="Bob")
    alice_tok = _login(client, org.id, "9100000101")
    bob_tok = _login(client, org.id, "9100000102")

    # No game yet → null for both.
    assert client.get("/api/v1/chess/games/active", headers=_h(org.id, alice_tok)).json() is None

    # Alice challenges Bob; Bob accepts → a waiting game is created.
    ch = client.post("/api/v1/chess/challenges",
                     json={"challenged_id": str(bob.id), "time_control": "untimed"},
                     headers=_h(org.id, alice_tok)).json()
    acc = client.post(f"/api/v1/chess/challenges/{ch['id']}/accept", headers=_h(org.id, bob_tok))
    assert acc.status_code == 200, acc.text
    game_id = acc.json()["game_id"]

    # The CHALLENGER (Alice) can now discover the game without any push.
    a = client.get("/api/v1/chess/games/active", headers=_h(org.id, alice_tok))
    assert a.status_code == 200
    assert a.json() is not None and a.json()["id"] == game_id
    assert a.json()["status"] == "waiting"

    # And so can the accepter (Bob).
    b = client.get("/api/v1/chess/games/active", headers=_h(org.id, bob_tok))
    assert b.json() is not None and b.json()["id"] == game_id


def _age_challenge(db, minutes):
    """Push every pending challenge back in time, the way an evening does."""
    from datetime import datetime, timedelta, timezone
    from app.models.chess import ChessChallenge
    when = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    for c in db.query(ChessChallenge).filter(ChessChallenge.status == "pending").all():
        c.created_at = when
    db.commit()


def test_a_challenge_nobody_answered_stops_being_offered(client, db):
    """"Waiting for … to accept…" for a person who left an hour ago.

    Challenges had no expiry, so every unanswered one stayed pending forever.
    Six stacked over the board on the first evening of real use — several
    addressed to bots, which never accept anything. A live invitation to play
    *now* has to stop claiming somebody is waiting.
    """
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000021", name="Alice")
    bob = _make_user(db, org.id, "9100000022", name="Bob")
    alice_tok = _login(client, org.id, "9100000021")
    bob_tok = _login(client, org.id, "9100000022")

    r = client.post("/api/v1/chess/challenges",
                    json={"challenged_id": str(bob.id), "time_control": "untimed"},
                    headers=_h(org.id, alice_tok))
    assert r.status_code == 201, r.text

    # Fresh: both sides see it.
    assert len(client.get("/api/v1/chess/challenges/outgoing",
                          headers=_h(org.id, alice_tok)).json()) == 1
    assert len(client.get("/api/v1/chess/challenges/incoming",
                          headers=_h(org.id, bob_tok)).json()) == 1

    _age_challenge(db, minutes=30)

    assert client.get("/api/v1/chess/challenges/outgoing",
                      headers=_h(org.id, alice_tok)).json() == [], \
        "the challenger was told somebody was still deciding"
    assert client.get("/api/v1/chess/challenges/incoming",
                      headers=_h(org.id, bob_tok)).json() == [], \
        "an invitation from an hour ago is not an invitation"


def test_accepting_a_stale_challenge_is_refused_rather_than_starting_a_game(client, db):
    """A notification opened late must not seat somebody at an empty board.

    Hiding the row is not enough on its own: the accept endpoint is reachable
    from a stale screen or an old notification, and accepting created a real
    game — with a clock — against a player who had long gone.
    """
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000031", name="Alice")
    bob = _make_user(db, org.id, "9100000032", name="Bob")
    alice_tok = _login(client, org.id, "9100000031")
    bob_tok = _login(client, org.id, "9100000032")

    r = client.post("/api/v1/chess/challenges",
                    json={"challenged_id": str(bob.id), "time_control": "blitz_5_0"},
                    headers=_h(org.id, alice_tok))
    challenge_id = r.json()["id"]

    _age_challenge(db, minutes=30)

    r = client.post(f"/api/v1/chess/challenges/{challenge_id}/accept",
                    headers=_h(org.id, bob_tok))
    assert r.status_code == 410, r.text
    assert "expired" in r.json()["detail"].lower()

    # And it is retired, not left pending to be tried again.
    from app.models.chess import ChessChallenge
    db.expire_all()
    assert db.query(ChessChallenge).filter(
        ChessChallenge.id == uuid.UUID(challenge_id)).first().status == "expired"


def test_a_fresh_challenge_is_still_acceptable(client, db):
    """The guard above must not make the ordinary case unplayable."""
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000041", name="Alice")
    bob = _make_user(db, org.id, "9100000042", name="Bob")
    alice_tok = _login(client, org.id, "9100000041")
    bob_tok = _login(client, org.id, "9100000042")

    r = client.post("/api/v1/chess/challenges",
                    json={"challenged_id": str(bob.id), "time_control": "untimed"},
                    headers=_h(org.id, alice_tok))
    challenge_id = r.json()["id"]

    r = client.post(f"/api/v1/chess/challenges/{challenge_id}/accept",
                    headers=_h(org.id, bob_tok))
    assert r.status_code == 200, r.text
    assert r.json()["game_id"]


def test_the_challenge_notification_points_at_the_inbox(client, db):
    """Tapping it landed on the tab beside the invitation.

    The push carries a route the app follows literally. '/chess/challenge'
    opens the page on its first tab — the list of people you *could* play —
    which is everything except the invitation the notification was about.
    """
    org = _make_org(db)
    alice = _make_user(db, org.id, "9100000051", name="Alice")
    bob = _make_user(db, org.id, "9100000052", name="Bob")
    alice_tok = _login(client, org.id, "9100000051")

    client.post("/api/v1/chess/challenges",
                json={"challenged_id": str(bob.id), "time_control": "untimed"},
                headers=_h(org.id, alice_tok))

    note = (db.query(Notification)
              .filter(Notification.user_id == bob.id)
              .order_by(Notification.created_at.desc())
              .first())
    assert note is not None
    assert "tab=inbox" in str(note.data), \
        f"the tap must land on the invitation, not beside it: {note.data}"
