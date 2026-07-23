"""
Gold price proxy — caches for 12 hours.
Uses goldapi.io (https://www.goldapi.io) — 100 req/month free plan.

12-hour cache = max 2 fetches/day = ~60/month, safely within the 100/month limit.
Falls back to cached value on error so stale data is shown rather than an error.
Set GOLD_API_KEY in Fly.io secrets (flyctl secrets set GOLD_API_KEY=...).
"""
import json
import logging
from datetime import datetime, timedelta, timezone

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_CACHE_TTL = timedelta(hours=12)  # 100 req/month plan → max ~60/month at 12h TTL
_REQUEST_TIMEOUT = 10

_GOLDAPI_URL = "https://www.goldapi.io/api/XAU/INR"

# goldapi.io returns international spot price. Indian retail price includes:
#   15% Basic Customs Duty + 3% GST = effective factor ~1.185
# This brings the displayed price in line with IBJA/jeweler association rates.
_INDIA_DUTY_FACTOR = 1.15 * 1.03  # ≈ 1.1845

_cache: dict = {"data": None, "fetched_at": None}

_STUB = {
    "price_per_gram_24k": None,
    "price_per_gram_22k": None,
    "currency": "INR",
    "updated_at": "",
}


async def _fetch_from_api() -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            _GOLDAPI_URL,
            headers={"x-access-token": settings.GOLD_API_KEY, "Content-Type": "application/json"},
            timeout=_REQUEST_TIMEOUT,
        )
    response.raise_for_status()
    data = response.json()

    # goldapi.io returns price in troy ounces; gram price is in price_gram_24k field
    # Some tiers return price_gram_24k directly; fall back to calculation from price.
    spot_gram_24k = data.get("price_gram_24k")
    if spot_gram_24k is None:
        # price field is per troy ounce (1 troy oz = 31.1035 grams)
        price_oz = data.get("price")
        if price_oz:
            spot_gram_24k = price_oz / 31.1035
        else:
            spot_gram_24k = None

    # Apply India import duty + GST to convert international spot → Indian retail price
    price_gram_24k = (spot_gram_24k * _INDIA_DUTY_FACTOR) if spot_gram_24k is not None else None
    price_gram_22k = (spot_gram_24k * (22 / 24) * _INDIA_DUTY_FACTOR) if spot_gram_24k is not None else None

    return {
        "price_per_gram_24k": round(price_gram_24k, 2) if price_gram_24k is not None else None,
        "price_per_gram_22k": round(price_gram_22k, 2) if price_gram_22k is not None else None,
        "currency": "INR",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }


async def get_gold_price() -> dict:
    """Return current gold price per gram in INR (24K and 22K).

    Caches the result for 12 hours (stays within 100 req/month plan).
    Returns a stub if GOLD_API_KEY is not set.
    Falls back to the last cached value on transient API errors.
    """
    if not settings.GOLD_API_KEY:
        return _STUB.copy()

    cache_key = "gold_price_cache"
    now = datetime.now(timezone.utc)
    
    from app.core.cache import get_valkey
    valkey = get_valkey()
    
    if valkey:
        cached_data = valkey.get(cache_key)
        if cached_data:
            try:
                return json.loads(cached_data)
            except Exception as e:
                logger.warning(f"Valkey cache parse error for gold price: {e}")

    is_stale = (
        _cache["fetched_at"] is None
        or now - _cache["fetched_at"] > _CACHE_TTL
    )

    if is_stale:
        try:
            data = await _fetch_from_api()
            _cache["data"] = data
            _cache["fetched_at"] = now
            if valkey:
                valkey.setex(cache_key, int(_CACHE_TTL.total_seconds()), json.dumps(data))
        except Exception as e:
            logger.warning(f"Gold price API fetch failed: {e}")
            # Cache the failure (or stale data) for a shorter duration (e.g. 5 minutes) to prevent thread pool exhaustion
            _cache["fetched_at"] = now - _CACHE_TTL + timedelta(minutes=5)
            if _cache["data"] is not None:
                return _cache["data"]
            return _STUB.copy()

    return _cache["data"]
