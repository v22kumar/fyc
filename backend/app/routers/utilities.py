from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Response
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

from app.core.config import settings
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
    response: Response = None,
):
    """Current weather for the given coordinates (30-minute server cache per location)."""
    # Instruct browsers/CDNs to cache for 30 min; serve stale up to 1hr while revalidating
    if response is not None:
        response.headers["Cache-Control"] = "public, max-age=1800, stale-while-revalidate=3600"
    return weather_service.get_weather(lat=lat, lon=lon)


@router.get("/gold-price", response_model=GoldPriceResponse)
def get_gold_price(response: Response = None):
    """Current gold price per gram in INR — 24K and 22K (12-hour server cache)."""
    # 12hr cache matches the server-side TTL; serve stale up to 24hr while revalidating
    if response is not None:
        response.headers["Cache-Control"] = "public, max-age=43200, stale-while-revalidate=86400"
    return gold_price_service.get_gold_price()


@router.get("/app/download", tags=["App"])
def download_app():
    """302 redirect to the latest FYC Connect Android APK.

    Set APP_APK_URL env var to the APK's public URL, e.g.:
        flyctl secrets set APP_APK_URL=https://fyc-backend.fly.dev/uploads/fyc-connect-latest.apk
    """
    if not settings.APP_APK_URL:
        raise HTTPException(
            status_code=404,
            detail="App download not yet available. Admin must set APP_APK_URL.",
        )
    return RedirectResponse(url=settings.APP_APK_URL, status_code=302)


@router.get("/app/info", tags=["App"])
def app_info():
    """Returns basic metadata about the Android app download."""
    return {
        "name": "FYC Connect",
        "platform": "Android",
        "package": "com.friendsyouthclub.fycconnect",
        "available": bool(settings.APP_APK_URL),
        "download_url": settings.APP_APK_URL or None,
    }
