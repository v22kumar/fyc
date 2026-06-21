from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.user import User
from app.schemas.chess import WeeklyAwardsOut
from app.services.weekly_awards import compute_weekly_awards

router = APIRouter(prefix="/chess/awards", tags=["Chess Awards"])


@router.get("/weekly", response_model=WeeklyAwardsOut)
def weekly_awards(
    current_user: User = Depends(get_current_user),
    tenant_id: str = Depends(require_tenant_id),
    db: Session = Depends(get_db),
):
    """Return weekly recognition awards for the organisation's chess players."""
    result = compute_weekly_awards(db, tenant_id)
    return result
