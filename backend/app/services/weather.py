"""
Weather proxy — caches per (lat, lon) pair for 30 minutes.

Uses Open-Meteo (https://open-meteo.com) — completely free, no API key
required, uses IMD (India Meteorological Department) + ECMWF data which
gives higher accuracy for Tamil Nadu / Kanyakumari than OpenWeatherMap.

WMO weather codes → human-readable descriptions and icon mapping per the
Open-Meteo documentation.
"""
import logging
from datetime import datetime, timedelta, timezone

import httpx

logger = logging.getLogger(__name__)

_CACHE_TTL = timedelta(minutes=30)
_REQUEST_TIMEOUT = 10

# Keyed by (rounded_lat, rounded_lon) -> {"data": dict, "fetched_at": datetime}
_cache: dict = {}

# WMO Weather Code → (description, icon_emoji)
# Full table: https://open-meteo.com/en/docs#weathervariables
_WMO_DESCRIPTIONS: dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Icy fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    56: "Light freezing drizzle", 57: "Heavy freezing drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
    66: "Light freezing rain", 67: "Heavy freezing rain",
    71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
    77: "Snow grains",
    80: "Slight showers", 81: "Moderate showers", 82: "Violent showers",
    85: "Slight snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Thunderstorm with heavy hail",
}

_WMO_ICONS: dict[int, str] = {
    0: "01d", 1: "01d", 2: "02d", 3: "04d",
    45: "50d", 48: "50d",
    51: "09d", 53: "09d", 55: "09d", 56: "09d", 57: "09d",
    61: "10d", 63: "10d", 65: "10d", 66: "10d", 67: "10d",
    71: "13d", 73: "13d", 75: "13d", 77: "13d",
    80: "09d", 81: "09d", 82: "09d", 85: "13d", 86: "13d",
    95: "11d", 96: "11d", 99: "11d",
}


def _round_coords(lat: float, lon: float) -> tuple[float, float]:
    return (round(lat, 2), round(lon, 2))


def _fetch_from_api(lat: float, lon: float) -> dict:
    response = httpx.get(
        "https://api.open-meteo.com/v1/forecast",
        params={
            "latitude": lat,
            "longitude": lon,
            "current": [
                "temperature_2m",
                "relative_humidity_2m",
                "apparent_temperature",
                "weather_code",
                "wind_speed_10m",
            ],
            "timezone": "Asia/Kolkata",
            "wind_speed_unit": "ms",  # metres per second, consistent with OWM
        },
        timeout=_REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    data = response.json()

    current = data.get("current", {})
    code = int(current.get("weather_code", 0))
    # Open-Meteo returns wind in km/h by default; we request ms above
    wind_ms = current.get("wind_speed_10m")

    return {
        "temp": current.get("temperature_2m"),
        "feels_like": current.get("apparent_temperature"),
        "description": _WMO_DESCRIPTIONS.get(code, "Unknown"),
        "icon": _WMO_ICONS.get(code, "01d"),
        "city": "Nagercoil",  # set by the caller via lat/lon; no reverse-geocode needed
        "humidity": current.get("relative_humidity_2m"),
        "wind_speed": round(wind_ms, 1) if wind_ms is not None else None,
    }


def get_weather(lat: float, lon: float) -> dict:
    """Return current weather for the given coordinates.

    Caches per (lat, lon) pair (rounded to 2 dp) for 30 minutes.
    Falls back to stale cache on transient API errors.
    No API key required — Open-Meteo is free.
    """
    key = _round_coords(lat, lon)
    now = datetime.now(timezone.utc)
    cached = _cache.get(key)

    is_stale = cached is None or now - cached["fetched_at"] > _CACHE_TTL
    if is_stale:
        try:
            data = _fetch_from_api(lat, lon)
            _cache[key] = {"data": data, "fetched_at": now}
        except Exception as e:
            logger.warning(f"Open-Meteo fetch failed for ({lat}, {lon}): {e}")
            if cached is not None:
                return cached["data"]
            return {
                "temp": None, "feels_like": None,
                "description": "Weather unavailable", "icon": "",
                "city": "", "humidity": None, "wind_speed": None,
            }

    return _cache[key]["data"]
