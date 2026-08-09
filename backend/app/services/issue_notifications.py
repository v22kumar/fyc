"""Push notifications for the civic complaint flow.

These live here rather than in the router because they run in a FastAPI
``BackgroundTask``, after the response has been sent and the request-scoped
session has been closed. Each function therefore opens and closes its own
session.

## What this replaces

``app/services/notifications.py``, which posted to
``https://fcm.googleapis.com/fcm/send`` with an ``Authorization: key=…``
header. That is FCM's **legacy HTTP API, decommissioned by Google in June
2024**. Every send from it had been failing since — silently, because the
helper caught the error, logged it and returned ``False``, and the router
ignored the return value. Issue-assigned and issue-resolved pushes have simply
not arrived for as long as that has been true.

The same module also offered topic broadcasts (``/topics/org_<slug>_blood``).
Those are not ported: no client anywhere in the repository ever calls
``subscribeToTopic``, so the topics had no subscribers even when the endpoint
still existed. Reviving a delivery path with nobody on the other end would look
like a fix and be nothing. Per-user delivery through ``NotificationService`` is
what actually reaches a phone, and it is what every other feature already uses.

## What changes as a result

Going through ``NotificationService`` means these notifications now also:

* leave an in-app record, so a missed push is still visible in the notification
  list rather than being lost with the tray entry,
* respect the member's ``push_enabled`` preference,
* localise into any registered language via ``i18n_key`` rather than carrying
  hardcoded Tamil and English strings.
"""
from __future__ import annotations

import logging
from uuid import UUID

from app.core import i18n
from app.core.database import SessionLocal
from app.schemas.notification import NotificationCategory
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)


def _send(
    user_id: UUID,
    organization_id: UUID,
    key: str,
    params: dict,
    route: str,
) -> None:
    """Deliver one localised push + in-app record. Never raises.

    A notification that fails must not take down the background task that
    carries it — the complaint itself is already saved and the member's screen
    has already been answered.
    """
    db = SessionLocal()
    try:
        NotificationService(db).send_push_only(
            user_id=user_id,
            organization_id=organization_id,
            # The stored en/ta columns are the fallback for a client that
            # predates the registry; the i18n_key is what resolves at send time
            # into the member's own language.
            title_en=i18n.t(f"{key}.title", "en", **params) or "",
            title_ta=i18n.t(f"{key}.title", "ta", **params) or "",
            body_en=i18n.t(f"{key}.body", "en", **params) or "",
            body_ta=i18n.t(f"{key}.body", "ta", **params) or "",
            notification_type=NotificationCategory.ISSUES.value,
            data={"i18n_key": key, "i18n_params": params, "route": route},
        )
    except Exception as e:  # pragma: no cover - best-effort delivery
        logger.warning("issue notification %s failed for user %s: %s", key, user_id, e)
    finally:
        db.close()


def notify_issue_received(
    user_id: UUID, organization_id: UUID, issue_id: str, category: str
) -> None:
    """Acknowledge a complaint to the person who reported it.

    Distinct from :func:`notify_issue_assigned`, which it used to share. A
    reporter was being told a complaint had been "assigned to you… please act
    promptly" about the pothole they had just photographed.
    """
    _send(
        user_id,
        organization_id,
        "issue.received",
        {"category": category},
        f"/issues/{issue_id}",
    )


def notify_issue_assigned(
    user_id: UUID, organization_id: UUID, issue_id: str, category: str
) -> None:
    """Tell a volunteer that a complaint is now theirs."""
    _send(
        user_id,
        organization_id,
        "issue.assigned",
        {"category": category},
        f"/issues/{issue_id}",
    )


def notify_issue_resolved(user_id: UUID, organization_id: UUID, issue_id: str) -> None:
    """Tell the reporter their complaint was resolved."""
    _send(
        user_id,
        organization_id,
        "issue.resolved",
        {},
        f"/issues/{issue_id}",
    )
