"""Instagram and Threads, pulled into the club's own feed.

Two faults, one of them invisible until weeks later.

* Meta's `media_url` is a **signed, short-lived link** into their CDN, and it
  was stored verbatim. A synced post looked right on the day and became a
  broken box some days later — silently, with nothing connecting the two
  events. The club would only notice that older feed items had lost their
  pictures.
* Three near-identical sync functions meant three places to fix anything, and
  one platform's failure could take the others down with it.
"""
import uuid

import pytest

from app.core.security import get_password_hash
from app.models.post import Post
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.services import social_sync


class _Response:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code
        self.text = str(payload)

    def json(self):
        return self._payload


def _org(db, **creds):
    org = Organization(id=uuid.uuid4(), slug=f"so-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org", is_active=True,
                       **creds)
    db.add(org)
    db.flush()
    admin = User(organization_id=org.id, phone_number=f"95{uuid.uuid4().int % 100000000:08d}",
                 password_hash=get_password_hash("pass"), role="SUPER_ADMIN",
                 is_verified=True)
    db.add(admin)
    db.flush()
    db.add(UserProfile(user_id=admin.id, full_name_ta="நிர்வாகி",
                       full_name_en="Admin"))
    db.commit()
    return org, admin


def test_an_expiring_instagram_link_is_replaced_by_our_own(db, monkeypatch):
    """The fault that made older feed posts lose their pictures."""
    org, admin = _org(db, instagram_access_token="t",
                      instagram_account_id="ig-1")

    monkeypatch.setattr(social_sync.requests, "get", lambda *a, **k: _Response(
        {"data": [{"id": "111", "caption": "Sports day",
                   "media_type": "IMAGE",
                   "media_url": "https://scontent.cdninstagram.com/expiring.jpg"}]}))
    monkeypatch.setattr(social_sync, "mirror_remote_image",
                        lambda url, **kw: "https://res.cloudinary.com/ours.jpg")

    provider = next(p for p in social_sync._PROVIDERS if p.name == "instagram")
    assert social_sync._sync_provider(db, org, admin, provider) == 1

    post = db.query(Post).filter(Post.organization_id == org.id).one()
    assert post.image_urls == ["https://res.cloudinary.com/ours.jpg"], \
        "a link we know will rot must not be what we store"
    assert post.content == "Sports day"
    assert post.source == "instagram"


def test_without_our_own_storage_their_link_is_kept(db, monkeypatch):
    """Honest degradation: pictures that expire beat no pictures at all.

    `/api/health/media` already reports which of the two you are running.
    """
    org, admin = _org(db, instagram_access_token="t",
                      instagram_account_id="ig-1")
    theirs = "https://scontent.cdninstagram.com/expiring.jpg"

    monkeypatch.setattr(social_sync.requests, "get", lambda *a, **k: _Response(
        {"data": [{"id": "222", "caption": "x", "media_type": "IMAGE",
                   "media_url": theirs}]}))
    monkeypatch.setattr(social_sync, "mirror_remote_image", lambda url, **kw: None)

    provider = next(p for p in social_sync._PROVIDERS if p.name == "instagram")
    social_sync._sync_provider(db, org, admin, provider)
    assert db.query(Post).filter(
        Post.organization_id == org.id).one().image_urls == [theirs]


def test_the_same_post_is_never_added_twice(db, monkeypatch):
    org, admin = _org(db, threads_access_token="t", threads_account_id="th-1")
    monkeypatch.setattr(social_sync.requests, "get", lambda *a, **k: _Response(
        {"data": [{"id": "333", "text": "Hello", "media_type": "TEXT_POST"}]}))
    monkeypatch.setattr(social_sync, "mirror_remote_image", lambda url, **kw: None)

    provider = next(p for p in social_sync._PROVIDERS if p.name == "threads")
    assert social_sync._sync_provider(db, org, admin, provider) == 1
    assert social_sync._sync_provider(db, org, admin, provider) == 0
    assert db.query(Post).filter(Post.organization_id == org.id).count() == 1


def test_one_platform_failing_does_not_stop_the_others(db, monkeypatch):
    """An expired Instagram token must not cost the club its Threads posts."""
    org, admin = _org(db, instagram_access_token="t", instagram_account_id="ig",
                      threads_access_token="t", threads_account_id="th")

    def _get(url, **kwargs):
        if "threads" in url:
            return _Response({"data": [{"id": "444", "text": "From Threads",
                                        "media_type": "TEXT_POST"}]})
        # What a real outage looks like: the request never completes.
        raise social_sync.requests.RequestException("instagram unreachable")

    monkeypatch.setattr(social_sync.requests, "get", _get)
    monkeypatch.setattr(social_sync, "mirror_remote_image", lambda url, **kw: None)
    monkeypatch.setattr(social_sync, "SessionLocal", lambda: db)
    monkeypatch.setattr(db, "close", lambda: None)

    social_sync.sync_social_feeds()

    posts = db.query(Post).filter(Post.organization_id == org.id).all()
    assert [p.source for p in posts] == ["threads"]


def test_a_platform_with_no_credentials_is_skipped(db, monkeypatch):
    org, admin = _org(db)  # nothing configured

    def _boom(*a, **k):
        pytest.fail("must not call a platform the club has not connected")

    monkeypatch.setattr(social_sync.requests, "get", _boom)
    for provider in social_sync._PROVIDERS:
        assert social_sync._sync_provider(db, org, admin, provider) == 0


def test_a_refusal_from_the_platform_adds_nothing(db, monkeypatch):
    org, admin = _org(db, instagram_access_token="t", instagram_account_id="ig")
    monkeypatch.setattr(social_sync.requests, "get",
                        lambda *a, **k: _Response({"error": "token expired"}, 400))

    provider = next(p for p in social_sync._PROVIDERS if p.name == "instagram")
    assert social_sync._sync_provider(db, org, admin, provider) == 0
    assert db.query(Post).filter(Post.organization_id == org.id).count() == 0
