from fastapi import APIRouter, Path

from app.schemas.thirukkural import ThirukkuralResponse
from app.services import thirukkural as service

router = APIRouter(prefix="/thirukkural", tags=["Thirukkural"])


@router.get("/daily", response_model=ThirukkuralResponse)
def get_daily_thirukkural():
    """
    Thirukkural of the day — the same couplet for everyone on a given date,
    rotating through all 1330 over time. Universal public content (no tenant
    scope, no auth required).
    """
    return service.get_daily_kural()


@router.get("/{number}", response_model=ThirukkuralResponse)
def get_thirukkural(number: int = Path(..., ge=1, le=service.TOTAL_KURALS)):
    """Return a specific Thirukkural couplet by its number (1–1330)."""
    return service.get_kural(number)
