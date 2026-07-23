from fastapi import APIRouter, Depends
from app.dependencies import get_current_user, RoleChecker
from app.services.whatsapp_broadcast import run_morning_broadcast, _last_broadcast

router = APIRouter(prefix="/broadcasts", tags=["Broadcasts"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


@router.post("/send-now")
async def trigger_broadcast(current_user=Depends(require_admin)):
    """Manually trigger the morning broadcast immediately (admin only)."""
    await run_morning_broadcast()
    return {
        "status": "sent",
        "detail": _last_broadcast,
    }


@router.get("/status")
def broadcast_status(current_user=Depends(require_admin)):
    """Return the result of the last broadcast run."""
    return _last_broadcast
