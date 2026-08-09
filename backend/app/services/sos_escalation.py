"""The thing that notices nobody answered.

Escalation is on a timer for one reason only: **silence is the signal**. Not
severity, not a category, not anything the member said — just the fact that
45 seconds have passed and none of the five nearest people has tapped anything.

What this job is careful never to do is end an incident. A timer can widen a
ring, because widening is a thing the server genuinely did. A timer cannot mark
somebody safe, because being safe is a thing only a person knows. An incident
that runs out of waves stays open and unanswered, which is a true and useful
thing for the member and an organiser to be looking at.

Runs every 15 seconds. That is frequent for a cron job and cheap in practice —
the query is `status IN (RAISED, WIDENING)` against an indexed column, and in a
club this size it usually returns nothing at all.
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.services.sos_dispatch import (
    WAVES, dispatch_wave, display_name, next_wave_due_at,
)

logger = logging.getLogger(__name__)


def sweep_escalations(db: Optional[Session] = None) -> int:
    """Widen every ring whose wait has run out. Returns how many widened.

    Takes an optional session so this is callable from a test against the same
    database the test wrote to. Without it the sweep opened its own connection
    to the real engine and silently found no tables — passing quietly while
    doing nothing, which on an escalation timer is the worst possible failure.
    """
    from app.core.database import SessionLocal
    from app.models.safety import SosIncident, SosStatus

    owns_session = db is None
    db = db or SessionLocal()
    widened = 0
    try:
        now = datetime.now(timezone.utc)
        open_incidents = (
            db.query(SosIncident)
            .filter(SosIncident.status.in_(
                [SosStatus.RAISED.value, SosStatus.WIDENING.value]))
            .all()
        )
        for incident in open_incidents:
            due = next_wave_due_at(incident)
            if due is None or now < due:
                continue
            if (incident.wave or 1) >= len(WAVES):
                continue

            rows = dispatch_wave(db, incident,
                                 wave_number=(incident.wave or 1) + 1, now=now)
            db.commit()
            widened += 1

            # Guarded per incident. A push that blows up on one member's wave
            # must not abandon the sweep and leave every other open SOS
            # un-widened — the rows are already committed either way, so the
            # record of who should have been told survives the failure.
            if rows:
                try:
                    from app.routers.safety import _push_incident_wave

                    _push_incident_wave(
                        incident.organization_id, incident.id,
                        [(r.user_id, r.distance_m) for r in rows],
                        display_name(db, incident.raised_by_user_id),
                        incident.place_name,
                    )
                except Exception as exc:
                    logger.warning("SOS wave push failed for %s: %s",
                                   incident.id, exc)
    except Exception as exc:
        logger.warning("SOS escalation sweep failed: %s", exc)
        db.rollback()
    finally:
        if owns_session:
            db.close()
    return widened
