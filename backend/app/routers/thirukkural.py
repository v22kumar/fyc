from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Path, Response

from app.schemas.thirukkural import ThirukkuralResponse
from app.services import thirukkural as service

router = APIRouter(prefix="/thirukkural", tags=["Thirukkural"])


def _secs_until_midnight_utc() -> int:
    """Seconds remaining until next UTC midnight — the kural changes then."""
    now = datetime.now(timezone.utc)
    midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return max(60, int((midnight - now).total_seconds()))


@router.get("/daily", response_model=ThirukkuralResponse)
def get_daily_thirukkural(response: Response = None):
    """
    Thirukkural of the day — the same couplet for everyone on a given date,
    rotating through all 1330 over time. Cached until UTC midnight.
    """
    if response is not None:
        ttl = _secs_until_midnight_utc()
        response.headers["Cache-Control"] = f"public, max-age={ttl}"
    return service.get_daily_kural()


@router.get("/{number}", response_model=ThirukkuralResponse)
def get_thirukkural(number: int = Path(..., ge=1, le=service.TOTAL_KURALS), response: Response = None):
    """Return a specific Thirukkural couplet by its number (1–1330). Content never changes."""
    if response is not None:
        response.headers["Cache-Control"] = "public, max-age=86400, immutable"
    return service.get_kural(number)
