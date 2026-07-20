import uuid

from app.models.tenant import Organization
from app.models.post import PostReport


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"post-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _register(client, org_id, phone, role="PUBLIC_CITIZEN"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id),
        "phone_number": phone,
        "email": phone + "@test.fyc",
        "date_of_birth": "1990-01-01",
        "role": role,
        "full_name_ta": "பயனர்",
        "full_name_en": "User",
    })
    assert res.status_code in (200, 201), res.text
    return res.json()["access_token"]


def _headers(token, org_id):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def _create_post(client, token, org_id, content="Hello", idempotency_key=None):
    body = {"content": content}
    if idempotency_key:
        body["idempotency_key"] = idempotency_key
    return client.post("/api/v1/posts", json=body, headers=_headers(token, org_id))


# ── report_post persistence ────────────────────────────────────────────────

def test_report_post_persists_row(client, db):
    org = _make_org(db)
    author = _register(client, org.id, "+919333000001")
    reporter = _register(client, org.id, "+919333000002")

    post_id = _create_post(client, author, org.id).json()["id"]

    res = client.post(
        f"/api/v1/posts/{post_id}/report",
        json={"reason": "spam"},
        headers=_headers(reporter, org.id),
    )
    assert res.status_code == 200
    assert res.json()["status"] == "reported"

    rows = db.query(PostReport).filter(PostReport.post_id == uuid.UUID(post_id)).all()
    assert len(rows) == 1
    assert rows[0].reason == "spam"


def test_report_post_is_idempotent_per_user(client, db):
    org = _make_org(db)
    author = _register(client, org.id, "+919333000003")
    reporter = _register(client, org.id, "+919333000004")
    post_id = _create_post(client, author, org.id).json()["id"]

    for _ in range(3):
        res = client.post(
            f"/api/v1/posts/{post_id}/report",
            json={"reason": "abuse"},
            headers=_headers(reporter, org.id),
        )
        assert res.status_code == 200

    rows = db.query(PostReport).filter(PostReport.post_id == uuid.UUID(post_id)).all()
    assert len(rows) == 1  # one row per reporter, not three


def test_report_missing_post_404(client, db):
    org = _make_org(db)
    reporter = _register(client, org.id, "+919333000005")
    res = client.post(
        f"/api/v1/posts/{uuid.uuid4()}/report",
        json={"reason": "x"},
        headers=_headers(reporter, org.id),
    )
    assert res.status_code == 404


# ── idempotency key on post creation ───────────────────────────────────────

def test_create_post_idempotency_key_dedupes(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919333000006")
    key = "same-key-123"

    r1 = _create_post(client, token, org.id, content="first", idempotency_key=key)
    r2 = _create_post(client, token, org.id, content="second", idempotency_key=key)

    assert r1.status_code == 201
    # Second call with the same key returns the first post rather than a new one.
    assert r2.json()["id"] == r1.json()["id"]
    assert r2.json()["content"] == "first"


def test_create_post_without_key_allows_duplicates(client, db):
    org = _make_org(db)
    token = _register(client, org.id, "+919333000007")

    r1 = _create_post(client, token, org.id, content="dup")
    r2 = _create_post(client, token, org.id, content="dup")

    # No idempotency key → two distinct posts (partial index only covers non-NULL).
    assert r1.json()["id"] != r2.json()["id"]


def test_feed_batched_counts_map_to_the_right_posts(client, db):
    """The batched (grouped) like/comment/repost counts and liked/reposted-by-me
    flags must attach to the correct post, not bleed across the page."""
    org = _make_org(db)
    author = _register(client, org.id, "+919333000101")
    liker = _register(client, org.id, "+919333000102")

    pa = _create_post(client, author, org.id, content="post A").json()["id"]
    pb = _create_post(client, author, org.id, content="post B").json()["id"]

    # Two people like post A; nobody touches post B.
    for tok in (author, liker):
        assert client.post(f"/api/v1/posts/{pa}/like", headers=_headers(tok, org.id)).status_code == 200
    # The liker comments once on post A.
    assert client.post(f"/api/v1/posts/{pa}/comments", json={"content": "nice"},
                       headers=_headers(liker, org.id)).status_code in (200, 201)

    feed = client.get("/api/v1/posts", headers=_headers(liker, org.id))
    assert feed.status_code == 200, feed.text
    by_id = {p["id"]: p for p in feed.json()}
    assert by_id[pa]["like_count"] == 2
    assert by_id[pa]["comment_count"] == 1
    assert by_id[pa]["liked_by_me"] is True   # liker liked A
    assert by_id[pb]["like_count"] == 0
    assert by_id[pb]["comment_count"] == 0
    assert by_id[pb]["liked_by_me"] is False  # counts didn't bleed from A
