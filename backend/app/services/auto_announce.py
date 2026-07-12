import logging
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models.announcement import Announcement, AnnouncementCategory

logger = logging.getLogger(__name__)


def auto_announce(
    db: Session,
    *,
    org_id: uuid.UUID,
    category: AnnouncementCategory,
    title_ta: str,
    title_en: str,
    body_ta: str,
    body_en: str,
    expires_at: Optional[datetime] = None,
    created_by_user_id: Optional[uuid.UUID] = None,
) -> None:
    """Post a system-generated announcement to the tenant's notice board.

    Club activity (a chess tournament opening for registration, a new event,
    a cricket tournament, a fresh opportunity) IS an announcement — members
    shouldn't depend on an admin remembering to also write a notice-board
    post. Called after the primary row is committed; best-effort and never
    raises into the caller, so a notice-board hiccup can't break the actual
    create.
    """
    try:
        db.add(Announcement(
            id=uuid.uuid4(),
            organization_id=org_id,
            title_ta=title_ta[:200],
            title_en=title_en[:200],
            body_ta=body_ta,
            body_en=body_en,
            category=category,
            expires_at=expires_at,
            created_by_user_id=created_by_user_id,
        ))
        db.commit()
    except Exception as e:  # pragma: no cover - best-effort delivery
        logger.warning(f"auto_announce failed (non-fatal): {e}")
        db.rollback()
