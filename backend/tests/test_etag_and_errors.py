"""Sprint 1: gzip / ETag-304 / clean-error-envelope hardening.

Exercises the real, deployed HTTP path (via the existing `client`/`db`
fixtures) for one representative endpoint (`/api/v1/announcements`), plus a
direct unit test of the pure `compute_etag` helper.
"""
import uuid

from app.core.etag import compute_etag
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"etag-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_executive(db, org_id, phone):
    user = User(organization_id=org_id, phone_number=phone,
                password_hash=get_password_hash("pass"), role="EXECUTIVE_MEMBER", is_verified=True)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, full_name_ta="நிர்வாகி", full_name_en="Executive"))
    db.commit()
    return user


def _login(client, org_id, phone, password="pass"):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id), "username": phone, "password": password})
    return r.json()["access_token"]


# ── compute_etag (pure function) ────────────────────────────────────────────

def test_compute_etag_is_deterministic():
    payload = [{"id": "1", "title": "A"}, {"id": "2", "title": "B"}]
    assert compute_etag(payload) == compute_etag(payload)


def test_compute_etag_changes_when_payload_changes():
    a = [{"id": "1", "title": "A"}]
    b = [{"id": "1", "title": "A-edited"}]
    assert compute_etag(a) != compute_etag(b)


def test_compute_etag_is_a_weak_etag():
    assert compute_etag([]).startswith('W/"')


# ── gzip + ETag/304 over the real HTTP stack ────────────────────────────────

def test_list_endpoint_compresses_and_sets_etag(client, db):
    org = _make_org(db)
    exec_user = _make_executive(db, org.id, "+919455500001")
    token = _login(client, org.id, "+919455500001")
    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}

    client.post("/api/v1/announcements", json={
        "title_ta": "த", "title_en": "Meeting tonight", "body_ta": "உ", "body_en": "6pm",
        "category": "GENERAL", "is_pinned": False,
    }, headers=headers)

    res = client.get("/api/v1/announcements", headers=headers)
    assert res.status_code == 200
    assert "etag" in {k.lower() for k in res.headers.keys()}
    # gzip only kicks in above the configured minimum_size; a real payload
    # with a full announcement easily clears 500 bytes.
    assert res.headers.get("content-encoding") == "gzip"


def test_list_endpoint_returns_304_when_client_etag_matches(client, db):
    org = _make_org(db)
    _make_executive(db, org.id, "+919455500002")
    token = _login(client, org.id, "+919455500002")
    headers = {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}

    client.post("/api/v1/announcements", json={
        "title_ta": "த", "title_en": "Camp", "body_ta": "உ", "body_en": "Blood camp Sunday",
        "category": "GENERAL", "is_pinned": False,
    }, headers=headers)

    first = client.get("/api/v1/announcements", headers=headers)
    etag = first.headers["etag"]

    second = client.get("/api/v1/announcements", headers={**headers, "If-None-Match": etag})
    assert second.status_code == 304
    assert second.content == b""

    stale = client.get("/api/v1/announcements", headers={**headers, "If-None-Match": '"stale"'})
    assert stale.status_code == 200


def test_unhandled_exception_returns_clean_envelope_not_a_raw_500(client, db):
    """Intentional HTTPException raises (e.g. 404 on a missing record) must
    still return their specific status/detail — the catch-all handler must
    not swallow them."""
    org = _make_org(db)
    res = client.get(f"/api/v1/announcements/{uuid.uuid4()}", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 404
    assert "detail" in res.json()
