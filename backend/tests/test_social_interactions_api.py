"""comments and follows carried user-generated content with no router tests.

The sharpest case is the comment sync: commenting on a post that came from
Instagram/Threads fires an outbound Graph API call using the post owner's
access token. Without an org filter on the post lookup, a comment aimed at
ANOTHER org's synced post would post to social media through their account.
"""
import uuid

from app.core.security import get_password_hash
from app.models.post import Post
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _make_org(db, **extra):
    org = Organization(id=uuid.uuid4(), slug=f"soc-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org", **extra)
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


def _post(db, org_id, author_id, source="thread", idem=None):
    p = Post(id=uuid.uuid4(), organization_id=org_id, author_id=author_id,
             content="Hello", source=source, idempotency_key=idem)
    db.add(p)
    db.commit()
    return p


# ── Comments ──────────────────────────────────────────────────────────────────

def test_comment_create_and_list_round_trip(client, db):
    org = _make_org(db)
    me = _make_user(db, org.id, "9900000001")
    post = _post(db, org.id, me.id)
    H = _h(org.id, _login(client, org.id, "9900000001"))

    r = client.post("/api/v1/comments", json={
        "entity_type": "post", "entity_id": str(post.id),
        "content": "Nice one",
    }, headers=H)
    assert r.status_code == 200

    r = client.get(f"/api/v1/comments/post/{post.id}", headers=H)
    assert [c["content"] for c in r.json()] == ["Nice one"]


def test_deleting_a_comment_stops_at_authorship(client, db):
    org = _make_org(db)
    author = _make_user(db, org.id, "9900000002")
    stranger = _make_user(db, org.id, "9900000003")
    admin = _make_user(db, org.id, "9900000004", role="ADMIN")
    post = _post(db, org.id, author.id)
    H_author = _h(org.id, _login(client, org.id, "9900000002"))
    H_stranger = _h(org.id, _login(client, org.id, "9900000003"))
    H_admin = _h(org.id, _login(client, org.id, "9900000004"))

    cid = client.post("/api/v1/comments", json={
        "entity_type": "post", "entity_id": str(post.id), "content": "Mine",
    }, headers=H_author).json()["id"]

    assert client.delete(f"/api/v1/comments/{cid}",
                         headers=H_stranger).status_code == 403
    assert client.delete(f"/api/v1/comments/{cid}",
                         headers=H_admin).status_code == 204


def test_comment_sync_never_borrows_another_orgs_token(client, db, monkeypatch):
    """Commenting on a foreign org's Instagram-synced post must not fire the
    outbound sync at all — that call runs with the post owner's token."""
    import app.routers.comments as comments_router

    calls = []
    monkeypatch.setattr(comments_router.requests, "post",
                        lambda *a, **k: calls.append(a) or type(
                            "R", (), {"status_code": 200,
                                      "json": lambda self: {"id": "x"},
                                      "text": ""})())

    org_b = _make_org(db, instagram_access_token="tok-b")
    owner = _make_user(db, org_b.id, "9900000005")
    foreign_post = _post(db, org_b.id, owner.id,
                         source="instagram", idem="ig_123")

    org_a = _make_org(db)
    _make_user(db, org_a.id, "9900000006")
    H_a = _h(org_a.id, _login(client, org_a.id, "9900000006"))

    r = client.post("/api/v1/comments", json={
        "entity_type": "post", "entity_id": str(foreign_post.id),
        "content": "sneaky",
    }, headers=H_a)
    assert r.status_code == 200
    assert calls == [], "no outbound sync may run on another org's post"


# ── Follows ───────────────────────────────────────────────────────────────────

def test_follow_toggles_on_and_off(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9900000007")
    H = _h(org.id, _login(client, org.id, "9900000007"))
    entity = str(uuid.uuid4())

    assert client.post("/api/v1/follows/toggle", json={
        "entity_type": "player", "entity_id": entity}, headers=H).status_code == 200
    mine = client.get("/api/v1/follows/me", headers=H).json()
    assert len(mine) == 1

    # The same tap again unfollows.
    client.post("/api/v1/follows/toggle", json={
        "entity_type": "player", "entity_id": entity}, headers=H)
    assert client.get("/api/v1/follows/me", headers=H).json() == []
