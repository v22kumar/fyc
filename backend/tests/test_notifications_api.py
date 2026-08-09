"""The notifications router is the fan-out path to real phones — and it had
no HTTP tests. A regression here either spams the whole club or silently
mutes it, and both look like success from the endpoint's own response.

These tests pin the visible contract: your list is yours, marking read
stops at ownership, a click is stamped once, preferences round-trip, and
broadcast is an admin's tool that actually lands rows.
"""
import uuid

from app.core.security import get_password_hash
from app.models.notification import Notification
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"ntf-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, role="VOLUNTEER"):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role=role,
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="உறுப்பினர்",
                       full_name_en="Member"))
    db.commit()
    return u


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id),
                          "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def _notif(db, org_id, user_id, title="Hello"):
    n = Notification(
        id=uuid.uuid4(), organization_id=org_id, user_id=user_id,
        title_en=title, title_ta=title, body_en="Body", body_ta="Body",
        notification_type="ADMIN",
    )
    db.add(n)
    db.commit()
    return n


def test_the_list_is_mine_and_only_mine(client, db):
    org = _make_org(db)
    me = _make_user(db, org.id, "9700000001")
    other = _make_user(db, org.id, "9700000002")
    _notif(db, org.id, me.id, "Mine")
    _notif(db, org.id, other.id, "Theirs")
    H = _h(org.id, _login(client, org.id, "9700000001"))

    r = client.get("/api/v1/notifications", headers=H)
    assert r.status_code == 200
    titles = [n["title_en"] for n in r.json()]
    assert titles == ["Mine"]


def test_marking_read_stops_at_ownership(client, db):
    org = _make_org(db)
    me = _make_user(db, org.id, "9700000003")
    other = _make_user(db, org.id, "9700000004")
    mine = _notif(db, org.id, me.id)
    theirs = _notif(db, org.id, other.id)
    H = _h(org.id, _login(client, org.id, "9700000003"))

    r = client.put(f"/api/v1/notifications/{mine.id}/read", headers=H)
    assert r.status_code == 200
    assert r.json()["is_read"] is True

    # Someone else's notification must be indistinguishable from a missing one.
    r = client.put(f"/api/v1/notifications/{theirs.id}/read", headers=H)
    assert r.status_code == 404


def test_read_all_marks_mine_and_leaves_theirs(client, db):
    org = _make_org(db)
    me = _make_user(db, org.id, "9700000005")
    other = _make_user(db, org.id, "9700000006")
    _notif(db, org.id, me.id)
    _notif(db, org.id, me.id)
    theirs = _notif(db, org.id, other.id)
    H = _h(org.id, _login(client, org.id, "9700000005"))

    assert client.put("/api/v1/notifications/read-all",
                      headers=H).status_code == 200
    mine_after = client.get("/api/v1/notifications", headers=H).json()
    assert all(n["is_read"] for n in mine_after)
    db.expire_all()
    assert db.get(Notification, theirs.id).is_read is False


def test_a_click_is_stamped_once(client, db):
    org = _make_org(db)
    me = _make_user(db, org.id, "9700000007")
    n = _notif(db, org.id, me.id)
    H = _h(org.id, _login(client, org.id, "9700000007"))

    assert client.put(f"/api/v1/notifications/{n.id}/track-click",
                      headers=H).status_code == 200
    db.expire_all()
    first = db.get(Notification, n.id).clicked_at
    assert first is not None

    # A second tap (or a re-delivered webhook) must not move the timestamp.
    client.put(f"/api/v1/notifications/{n.id}/track-click", headers=H)
    db.expire_all()
    assert db.get(Notification, n.id).clicked_at == first


def test_preferences_round_trip(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9700000008")
    H = _h(org.id, _login(client, org.id, "9700000008"))

    r = client.get("/api/v1/notifications/preferences", headers=H)
    assert r.status_code == 200
    assert r.json()["push_enabled"] is True

    r = client.put("/api/v1/notifications/preferences",
                   json={"push_enabled": False}, headers=H)
    assert r.status_code == 200
    assert r.json()["push_enabled"] is False

    r = client.get("/api/v1/notifications/preferences", headers=H)
    assert r.json()["push_enabled"] is False


def test_broadcast_is_an_admins_tool(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9700000009")  # ordinary member
    H = _h(org.id, _login(client, org.id, "9700000009"))

    r = client.post("/api/v1/notifications/broadcast", json={
        "title_en": "T", "title_ta": "T", "body_en": "B", "body_ta": "B",
        "notification_type": "ADMIN",
    }, headers=H)
    assert r.status_code == 403


def test_broadcast_lands_a_row_for_the_members(client, db):
    org = _make_org(db)
    admin = _make_user(db, org.id, "9700000010", role="ADMIN")
    member = _make_user(db, org.id, "9700000011")
    H = _h(org.id, _login(client, org.id, "9700000010"))

    r = client.post("/api/v1/notifications/broadcast", json={
        "title_en": "Ground closed", "title_ta": "மைதானம் மூடல்",
        "body_en": "Rain", "body_ta": "மழை",
        "notification_type": "ADMIN",
    }, headers=H)
    assert r.status_code == 200

    # TestClient runs BackgroundTasks before returning, so the rows exist now.
    db.expire_all()
    got = db.query(Notification).filter(
        Notification.user_id == member.id).count()
    assert got == 1, "the broadcast must actually reach a member's inbox"
