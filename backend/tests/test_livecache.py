"""Live-scores cache-aside layer.

Exercises the in-memory fallback (no VALKEY_URL/REDIS_URL configured, which is
the default in CI): set/get round-trips, misses, and invalidation. The Valkey
path is a thin wrapper over the same interface and degrades to this fallback on
any error, so covering the fallback covers the contract the endpoint relies on.
"""
from app.core import livecache


def test_get_returns_none_on_miss():
    livecache._reset_for_tests()
    assert livecache.get_json("sports:live:missing") is None


def test_set_then_get_round_trips_json():
    livecache._reset_for_tests()
    payload = {"live": [{"score": 42}], "recent": [], "upcoming": []}
    livecache.set_json("sports:live:org1", payload)
    assert livecache.get_json("sports:live:org1") == payload


def test_invalidate_single_key():
    livecache._reset_for_tests()
    livecache.set_json("sports:live:org1", {"a": 1})
    livecache.set_json("sports:live:org2", {"b": 2})
    livecache.invalidate("sports:live:org1")
    assert livecache.get_json("sports:live:org1") is None
    assert livecache.get_json("sports:live:org2") == {"b": 2}


def test_invalidate_all():
    livecache._reset_for_tests()
    livecache.set_json("sports:live:org1", {"a": 1})
    livecache.set_json("sports:live:org2", {"b": 2})
    livecache.invalidate()
    assert livecache.get_json("sports:live:org1") is None
    assert livecache.get_json("sports:live:org2") is None


def test_live_endpoint_unaffected_by_cache_under_tests(client, db):
    """With TESTING true the endpoint must bypass the cache entirely — a smoke
    check that the wiring imports cleanly and still returns the live payload."""
    import uuid
    from app.models.tenant import Organization

    org = Organization(id=uuid.uuid4(), slug=f"lc-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()

    r = client.get("/api/v1/sports/live", headers={"X-Organization-ID": str(org.id)})
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body.keys()) == {"live", "recent", "upcoming"}
