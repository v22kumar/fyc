"""
Weather proxy — caches per (lat, lon) pair for 30 minutes.
Uses OpenWeatherMap Current Weather API (free tier).
If OPENWEATHER_API_KEY is not set, returns a placeholder stub.
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_CACHE_TTL = timedelta(minutes=30)
_REQUEST_TIMEOUT = 10

# Keyed by (rounded_lat, rounded_lon) -> {"data": dict, "fetched_at": datetime}
_cache: dict = {}

_STUB = {
    "temp": None,
    "feels_like": None,
    "description": "Weather not configured",
    "icon": "",
    "city": "",
    "humidity": None,
    "wind_speed": None,
}


def _round_coords(lat: float, lon: float) -> tuple[float, float]:
    return (round(lat, 2), round(lon, 2))


def _fetch_from_api(lat: float, lon: float) -> dict:
    url = (
        f"https://api.openweathermap.org/data/2.5/weather"
        f"?lat={lat}&lon={lon}&appid={settings.OPENWEATHER_API_KEY}&units=metric"
    )
    response = httpx.get(url, timeout=_REQUEST_TIMEOUT)
    response.raise_for_status()
    data = response.json()

    weather = data.get("weather", [{}])[0]
    main = data.get("main", {})
    wind = data.get("wind", {})

    return {
        "temp": main.get("temp"),
        "feels_like": main.get("feels_like"),
        "description": weather.get("description", ""),
        "icon": weather.get("icon", ""),
        "city": data.get("name", ""),
        "humidity": main.get("humidity"),
        "wind_speed": wind.get("speed"),
    }


def get_weather(lat: float, lon: float) -> dict:
    """Return current weather for the given coordinates.

    Caches results per (lat, lon) pair (rounded to 2 decimal places) for
    30 minutes. Returns a stub if OPENWEATHER_API_KEY is not configured.
    Falls back to cached data on transient API errors.
    """
    if not settings.OPENWEATHER_API_KEY:
        return _STUB.copy()

    key = _round_coords(lat, lon)
    now = datetime.now(timezone.utc)
    cached = _cache.get(key)

    is_stale = cached is None or now - cached["fetched_at"] > _CACHE_TTL
    if is_stale:
        try:
            data = _fetch_from_api(lat, lon)
            _cache[key] = {"data": data, "fetched_at": now}
        except Exception as e:
            logger.warning(f"Weather API fetch failed for ({lat}, {lon}): {e}")
            if cached is not None:
                # Return stale cache rather than an error
                return cached["data"]
            return _STUB.copy()

    return _cache[key]["data"]
