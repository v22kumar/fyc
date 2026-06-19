"""
Gold price proxy — caches for 1 hour.
Uses goldapi.io free tier (https://www.goldapi.io).
If GOLD_API_KEY not set, returns stub.
Falls back to cached value on error.
"""
import logging
from datetime import datetime, timedelta, timezone

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_CACHE_TTL = timedelta(hours=1)
_REQUEST_TIMEOUT = 10

_GOLDAPI_URL = "https://www.goldapi.io/api/XAU/INR"

_cache: dict = {"data": None, "fetched_at": None}

_STUB = {
    "price_per_gram_24k": None,
    "price_per_gram_22k": None,
    "currency": "INR",
    "updated_at": "",
}


def _fetch_from_api() -> dict:
    response = httpx.get(
        _GOLDAPI_URL,
        headers={"x-access-token": settings.GOLD_API_KEY, "Content-Type": "application/json"},
        timeout=_REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    data = response.json()

    # goldapi.io returns price in troy ounces; gram price is in price_gram_24k field
    # Some tiers return price_gram_24k directly; fall back to calculation from price.
    price_gram_24k = data.get("price_gram_24k")
    if price_gram_24k is None:
        # price field is per troy ounce (1 troy oz = 31.1035 grams)
        price_oz = data.get("price")
        if price_oz:
            price_gram_24k = price_oz / 31.1035
        else:
            price_gram_24k = None

    price_gram_22k = (price_gram_24k * (22 / 24)) if price_gram_24k is not None else None

    return {
        "price_per_gram_24k": round(price_gram_24k, 2) if price_gram_24k is not None else None,
        "price_per_gram_22k": round(price_gram_22k, 2) if price_gram_22k is not None else None,
        "currency": "INR",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }


def get_gold_price() -> dict:
    """Return current gold price per gram in INR (24K and 22K).

    Caches the result for 1 hour. Returns a stub if GOLD_API_KEY is not set.
    Falls back to the last cached value on transient API errors.
    """
    if not settings.GOLD_API_KEY:
        return _STUB.copy()

    now = datetime.now(timezone.utc)
    is_stale = (
        _cache["fetched_at"] is None
        or now - _cache["fetched_at"] > _CACHE_TTL
    )

    if is_stale:
        try:
            data = _fetch_from_api()
            _cache["data"] = data
            _cache["fetched_at"] = now
        except Exception as e:
            logger.warning(f"Gold price API fetch failed: {e}")
            if _cache["data"] is not None:
                return _cache["data"]
            return _STUB.copy()

    return _cache["data"]
