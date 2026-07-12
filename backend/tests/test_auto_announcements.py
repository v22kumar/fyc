import uuid

from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"aa-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, role):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role=role, is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="பயனர்", full_name_en="User"))
    db.commit()
    return user


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def _announcements(client, org_id):
    r = client.get("/api/v1/announcements", headers={"X-Organization-ID": str(org_id)})
    assert r.status_code == 200, r.text
    return r.json()


def test_chess_tournament_creates_announcement(client, db):
    """Opening a chess tournament for registration must land on the notice
    board automatically — members shouldn't rely on a separate admin post."""
    org = _make_org(db)
    _make_user(db, org.id, "+919777000001", "EXECUTIVE_MEMBER")
    tok = _login(client, org.id, "+919777000001")

    r = client.post("/api/v1/chess/tournaments",
                    json={"name": "Winter Knockout"}, headers=_h(org.id, tok))
    assert r.status_code == 201, r.text

    anns = _announcements(client, org.id)
    assert len(anns) == 1
    assert anns[0]["category"] == "EVENT"
    assert "Winter Knockout" in anns[0]["title_en"]
    assert "registration open" in anns[0]["title_en"]


def test_official_sports_tournament_creates_announcement_draft_stays_silent(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "+919777000011", "EXECUTIVE_MEMBER")
    _make_user(db, org.id, "+919777000012", "CLUB_MEMBER")
    exec_tok = _login(client, org.id, "+919777000011")
    member_tok = _login(client, org.id, "+919777000012")

    payload = {"name_ta": "கிரிக்கெட் கோப்பை", "name_en": "Cricket Cup",
               "sport": "CRICKET", "year": 2026}

    # Member creation lands as DRAFT → no notice-board noise.
    r = client.post("/api/v1/sports/tournaments", json=payload, headers=_h(org.id, member_tok))
    assert r.status_code == 201, r.text
    assert _announcements(client, org.id) == []

    # Admin creation is official (UPCOMING) → announced.
    r = client.post("/api/v1/sports/tournaments", json=payload, headers=_h(org.id, exec_tok))
    assert r.status_code == 201, r.text
    anns = _announcements(client, org.id)
    assert len(anns) == 1
    assert "Cricket Cup" in anns[0]["title_en"]
    assert anns[0]["category"] == "EVENT"


def test_active_opportunity_creates_announcement(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "+919777000021", "EXECUTIVE_MEMBER")
    tok = _login(client, org.id, "+919777000021")

    r = client.post("/api/v1/opportunities",
                    json={"type": "VOLUNTEER", "title_ta": "மர நடவு",
                          "title_en": "Tree Planting Drive", "is_active": True},
                    headers=_h(org.id, tok))
    assert r.status_code == 201, r.text

    anns = _announcements(client, org.id)
    assert len(anns) == 1
    assert anns[0]["category"] == "OPPORTUNITY"
    assert "Tree Planting Drive" in anns[0]["title_en"]
