"""Reverse geocoding (lat/lng → human-readable address) via OpenStreetMap
Nominatim — free, no API key. Results cached 24 h. Never raises: returns None on
any failure so a complaint still records its coordinates.

Nominatim's usage policy requires a descriptive User-Agent and ≤1 req/s; complaint
submission is low-volume and cached, which stays well inside that.
"""
import logging
from typing import Optional

import httpx

from app.core.cache import TTLCache

logger = logging.getLogger(__name__)

_cache = TTLCache(ttl_seconds=86400, maxsize=1024)
_UA = "FYC-Connect/1.0 (Friends Youth Club civic complaints; contact: noreply@fycconnect.org)"


def reverse_geocode(latitude: float, longitude: float) -> Optional[str]:
    """Return a readable address for the point, or None."""
    key = (round(float(latitude), 4), round(float(longitude), 4))
    hit, cached = _cache.get(key)
    if hit:
        return cached
    address = None
    try:
        with httpx.Client(timeout=8.0, headers={"User-Agent": _UA}) as client:
            r = client.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={
                    "lat": latitude, "lon": longitude,
                    "format": "jsonv2", "zoom": 18, "addressdetails": 1,
                },
            )
            r.raise_for_status()
            data = r.json()
            address = data.get("display_name")
    except Exception as e:
        logger.warning("[geocode] reverse failed for %s,%s: %s", latitude, longitude, e)
    _cache.set(key, address)
    return address
