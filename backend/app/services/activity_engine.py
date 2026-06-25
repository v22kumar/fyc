import logging
from sqlalchemy.orm import Session
from app.models.core_services import CommunityActivity
from uuid import UUID

logger = logging.getLogger(__name__)

class ActivityEngine:
    @staticmethod
    def log_activity(
        db: Session,
        organization_id: UUID,
        actor_id: UUID,
        action_type: str,
        entity_type: str,
        entity_id: UUID,
        message_en: str = None,
        message_ta: str = None,
        metadata_json: dict = None
    ):
        """
        Record a community activity (Event Created, Issue Resolved, Match Finished, etc.).
        This powers the Community Feed and Analytics.
        """
        try:
            activity = CommunityActivity(
                organization_id=organization_id,
                actor_id=actor_id,
                action_type=action_type,
                entity_type=entity_type,
                entity_id=entity_id,
                message_en=message_en,
                message_ta=message_ta,
                metadata_json=metadata_json
            )
            db.add(activity)
            db.commit()
            db.refresh(activity)
            return activity
        except Exception as e:
            logger.error(f"Failed to log activity: {e}")
            db.rollback()
            return None

    @staticmethod
    def get_timeline(db: Session, organization_id: UUID, entity_type: str, entity_id: UUID):
        """
        Fetch the chronological timeline of events for any given entity.
        """
        return db.query(CommunityActivity).filter(
            CommunityActivity.organization_id == organization_id,
            CommunityActivity.entity_type == entity_type,
            CommunityActivity.entity_id == entity_id
        ).order_by(CommunityActivity.created_at.asc()).all()
