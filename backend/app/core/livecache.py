"""
Cache-aside layer for hot public reads (the cross-tournament live-scores strip,
polled every ~20s by every open client during a match).

Backends, in preference order:
  1. Valkey / Redis  — used when VALKEY_URL or REDIS_URL is set. redis-py speaks
     the Valkey wire protocol, so either works. This is the right choice once the
     app runs on more than one instance (a shared cache across replicas).
  2. Process-local in-memory TTLCache — the automatic fallback when no URL is
     configured (or the server is briefly unreachable). Requires zero infra and
     is correct for a single instance.

The layer is deliberately fail-open: any Valkey error degrades to the in-memory
cache (and ultimately to a live DB read), never to an error surfaced to a user.
Values must be JSON-serializable.

Provision on Fly (free, open-source Valkey add-on or any Redis-compatible URL):
    flyctl secrets set VALKEY_URL="redis://default:<password>@<host>:6379"
"""
import json
import logging
import os

from .cache import TTLCache

logger = logging.getLogger(__name__)

_TTL_SECONDS = int(os.getenv("LIVE_CACHE_TTL_SECONDS", "4"))
_memory = TTLCache(ttl_seconds=_TTL_SECONDS, maxsize=256)

# Resolved once, lazily, on first use — importing/connecting at module import
# time would couple app boot to Valkey availability, which we explicitly avoid.
_redis = None
_redis_resolved = False


def _client():
    """Return a live Valkey/Redis client, or None to use the in-memory fallback."""
    global _redis, _redis_resolved
    if _redis_resolved:
        return _redis
    _redis_resolved = True
    url = os.getenv("VALKEY_URL") or os.getenv("REDIS_URL")
    if not url:
        return None
    try:
        import redis  # lazy: only needed when a cache URL is configured

        client = redis.from_url(
            url,
            socket_connect_timeout=0.5,
            socket_timeout=0.5,
            decode_responses=True,
        )
        client.ping()
        _redis = client
        logger.info("livecache: using Valkey/Redis backend")
    except Exception as exc:  # noqa: BLE001 — any failure → in-memory fallback
        logger.warning("livecache: Valkey/Redis unavailable (%s); using in-memory cache", exc)
        _redis = None
    return _redis


def get_json(key: str):
    """Return the cached value for `key`, or None on miss/expiry."""
    client = _client()
    if client is not None:
        try:
            raw = client.get(key)
            return json.loads(raw) if raw else None
        except Exception as exc:  # noqa: BLE001
            logger.warning("livecache: get failed (%s); falling back to memory", exc)
    hit, value = _memory.get(key)
    return value if hit else None


def set_json(key: str, value, ttl_seconds: int | None = None) -> None:
    """Cache `value` (JSON-serializable) under `key` for the configured TTL."""
    ttl = ttl_seconds or _TTL_SECONDS
    client = _client()
    if client is not None:
        try:
            client.setex(key, ttl, json.dumps(value, default=str))
            return
        except Exception as exc:  # noqa: BLE001
            logger.warning("livecache: set failed (%s); falling back to memory", exc)
    _memory.set(key, value)


def invalidate(key: str | None = None) -> None:
    """Drop one key (or flush everything when key is None)."""
    client = _client()
    if client is not None:
        try:
            if key is None:
                client.flushdb()
            else:
                client.delete(key)
        except Exception as exc:  # noqa: BLE001
            logger.warning("livecache: invalidate failed (%s)", exc)
    _memory.invalidate(key)


def _reset_for_tests() -> None:
    """Test hook: clear the in-memory cache and force backend re-resolution."""
    global _redis, _redis_resolved
    _redis = None
    _redis_resolved = False
    _memory.invalidate()
