"""weekly_games had five write endpoints and zero tests — the highest
write-count untested router in the app. These pin the contract, including
the authorization fix that came out of writing them: edit and delete were
accepted from ANY signed-in member; the app merely hid the buttons.
"""
import uuid
from datetime import datetime, timedelta, timezone

from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"wg-{uuid.uuid4().hex[:6]}",
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


def _create(client, H, title="Friday Cricket"):
    when = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    r = client.post("/api/v1/weekly-games", json={
        "title": title, "sport": "cricket", "scheduled_at": when,
        "venue": "Beach ground",
    }, headers=H)
    assert r.status_code == 200
    return r.json()


def test_create_then_list_within_the_tenant(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9800000001")
    H = _h(org.id, _login(client, org.id, "9800000001"))

    _create(client, H)
    games = client.get("/api/v1/weekly-games", headers=H).json()
    assert [g["title"] for g in games] == ["Friday Cricket"]

    # Another org sees nothing.
    org_b = _make_org(db)
    _make_user(db, org_b.id, "9800000002")
    HB = _h(org_b.id, _login(client, org_b.id, "9800000002"))
    assert client.get("/api/v1/weekly-games", headers=HB).json() == []


def test_joining_twice_makes_one_player(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9800000003")
    H = _h(org.id, _login(client, org.id, "9800000003"))
    game = _create(client, H)

    first = client.post(f"/api/v1/weekly-games/{game['id']}/join", headers=H)
    again = client.post(f"/api/v1/weekly-games/{game['id']}/join", headers=H)
    assert first.status_code == again.status_code == 200
    assert len(again.json()["players"]) == 1, "a double-tap is one join"


def test_editing_belongs_to_the_organizer(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9800000004")  # organizer
    _make_user(db, org.id, "9800000005")  # another member
    H_org = _h(org.id, _login(client, org.id, "9800000004"))
    H_other = _h(org.id, _login(client, org.id, "9800000005"))
    game = _create(client, H_org)

    # The stranger's edit and delete are refused — this was accepted before.
    r = client.patch(f"/api/v1/weekly-games/{game['id']}",
                     json={"title": "Hijacked"}, headers=H_other)
    assert r.status_code == 403
    assert client.delete(f"/api/v1/weekly-games/{game['id']}",
                         headers=H_other).status_code == 403

    # The organizer's edit works.
    r = client.patch(f"/api/v1/weekly-games/{game['id']}",
                     json={"title": "Saturday Cricket"}, headers=H_org)
    assert r.status_code == 200
    assert r.json()["title"] == "Saturday Cricket"


def test_an_admin_can_clean_up_any_game(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9800000006")
    _make_user(db, org.id, "9800000007", role="ADMIN")
    H_creator = _h(org.id, _login(client, org.id, "9800000006"))
    H_admin = _h(org.id, _login(client, org.id, "9800000007"))
    game = _create(client, H_creator)

    assert client.delete(f"/api/v1/weekly-games/{game['id']}",
                         headers=H_admin).status_code == 204
    assert client.get("/api/v1/weekly-games", headers=H_creator).json() == []


def test_another_orgs_game_id_is_a_404(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9800000008")
    H = _h(org.id, _login(client, org.id, "9800000008"))
    game = _create(client, H)

    org_b = _make_org(db)
    _make_user(db, org_b.id, "9800000009", role="ADMIN")
    HB = _h(org_b.id, _login(client, org_b.id, "9800000009"))
    assert client.post(f"/api/v1/weekly-games/{game['id']}/join",
                       headers=HB).status_code == 404
    assert client.delete(f"/api/v1/weekly-games/{game['id']}",
                         headers=HB).status_code == 404
