"""Notification retention: history older than the window is pruned; recent rows
(and every type) within the window are kept."""
import uuid
from datetime import datetime, timezone, timedelta

from app.models.tenant import Organization
from app.models.user import User
from app.models.notification import Notification
from app.services.daily_digest import prune_old_notifications


def _notif(org_id, user_id, ntype, created_at):
    return Notification(
        id=uuid.uuid4(), organization_id=org_id, user_id=user_id,
        title_en="t", title_ta="த", body_en="b", body_ta="ப",
        notification_type=ntype, created_at=created_at,
    )


def test_prune_deletes_old_keeps_recent(db):
    org = Organization(id=uuid.uuid4(), slug=f"n-{uuid.uuid4().hex[:6]}", name_ta="அ", name_en="Org")
    db.add(org); db.flush()
    user = User(organization_id=org.id, phone_number="+919000000123", role="PUBLIC_CITIZEN", is_verified=True)
    db.add(user); db.flush()

    now = datetime.now(timezone.utc)
    old_news = _notif(org.id, user.id, "NEWS", now - timedelta(days=10))
    old_admin = _notif(org.id, user.id, "ADMIN", now - timedelta(days=8))   # every type is pruned
    recent = _notif(org.id, user.id, "EVENT", now - timedelta(days=2))
    db.add_all([old_news, old_admin, recent])
    db.commit()

    deleted = prune_old_notifications(db, 7)
    assert deleted == 2

    remaining = db.query(Notification).filter(Notification.organization_id == org.id).all()
    assert len(remaining) == 1
    assert remaining[0].notification_type == "EVENT"
