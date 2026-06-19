from typing import Optional

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.services import weather as weather_service
from app.services import gold_price as gold_price_service

router = APIRouter(prefix="/utilities", tags=["Utilities"])


# ── Response schemas ──────────────────────────────────────────────────────────

class WeatherResponse(BaseModel):
    temp: Optional[float]
    feels_like: Optional[float]
    description: str
    icon: str
    city: str
    humidity: Optional[int]
    wind_speed: Optional[float]


class GoldPriceResponse(BaseModel):
    price_per_gram_24k: Optional[float]
    price_per_gram_22k: Optional[float]
    currency: str
    updated_at: str


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/weather", response_model=WeatherResponse)
def get_weather(
    lat: float = Query(..., description="Latitude of the location"),
    lon: float = Query(..., description="Longitude of the location"),
):
    """Current weather for the given coordinates (30-minute cache per location).

    Returns a placeholder response when OPENWEATHER_API_KEY is not configured.
    """
    return weather_service.get_weather(lat=lat, lon=lon)


@router.get("/gold-price", response_model=GoldPriceResponse)
def get_gold_price():
    """Current gold price per gram in INR — 24K and 22K (1-hour cache).

    Returns a placeholder response when GOLD_API_KEY is not configured.
    """
    return gold_price_service.get_gold_price()
