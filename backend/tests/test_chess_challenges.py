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
    assert note.data.get("route") == "/chess/challenge"
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
