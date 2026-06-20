"""
Shared in-memory TTL cache utility.

Thread-safe, bounded size, no external dependencies.
Used where SQLAlchemy results need short-lived caching
(geography nodes, blood donor search pages, etc.).
"""
from datetime import datetime, timedelta, timezone
from threading import Lock
from typing import Any, Tuple


class TTLCache:
    """
    Simple in-memory cache with per-key TTL and bounded size.

    Size overflow uses LRU-style eviction (removes the entry whose
    expiry is soonest, i.e. would expire first anyway).
    """

    def __init__(self, ttl_seconds: int, maxsize: int = 512):
        self._store: dict[Any, Tuple[Any, datetime]] = {}
        self._ttl = timedelta(seconds=ttl_seconds)
        self._maxsize = maxsize
        self._lock = Lock()

    def get(self, key: Any) -> Tuple[bool, Any]:
        """Return (hit, value). Returns (False, None) on miss or expiry."""
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return False, None
            value, expires_at = entry
            if datetime.now(timezone.utc) >= expires_at:
                del self._store[key]
                return False, None
            return True, value

    def set(self, key: Any, value: Any) -> None:
        """Store value under key, evicting the soonest-expiring entry if full."""
        with self._lock:
            if key not in self._store and len(self._store) >= self._maxsize:
                soonest = min(self._store, key=lambda k: self._store[k][1])
                del self._store[soonest]
            self._store[key] = (value, datetime.now(timezone.utc) + self._ttl)

    def invalidate(self, key: Any = None) -> None:
        """Remove one key, or flush everything when key is None."""
        with self._lock:
            if key is None:
                self._store.clear()
            else:
                self._store.pop(key, None)

    @property
    def size(self) -> int:
        with self._lock:
            return len(self._store)
