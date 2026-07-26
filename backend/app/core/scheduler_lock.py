"""Single-leader election for the in-process cron scheduler.

The APScheduler lives inside the web process. With `auto_start_machines` on
Fly, more than one machine can run at once, and each would fire every cron job
— duplicate birthday/digest pushes and WhatsApp broadcasts to the whole member
base. A shared SQLAlchemyJobStore gives *persistence*, not mutual exclusion, so
we elect a single leader here: on Postgres the instances race for one advisory
lock; exactly one wins and runs the scheduler.
"""
import logging
import os

from app.core.config import settings

logger = logging.getLogger(__name__)

# Keep the winning connection alive for the whole process lifetime — a
# session-level advisory lock is released the moment its connection closes.
_lock_conn = None

# Arbitrary constant key; every instance contends for this one lock.
_SCHEDULER_LOCK_KEY = 92710473


def should_run_scheduler() -> bool:
    """Return True if THIS process should own the cron scheduler.

    - `SCHEDULER_ENABLED=false` force-disables it (e.g. on a web-only process
      group where a dedicated worker runs cron instead).
    - SQLite ⇒ always True (single instance by construction).
    - Postgres ⇒ try to grab a global advisory lock; only the winner runs cron.
    - On any lock error, fall back to True so a single-instance deploy never
      silently loses its scheduled jobs.
    """
    if os.getenv("SCHEDULER_ENABLED", "true").strip().lower() in ("0", "false", "no"):
        logger.info("[scheduler] disabled via SCHEDULER_ENABLED")
        return False

    if settings.DATABASE_URL.strip().lower().startswith("sqlite"):
        return True

    global _lock_conn
    try:
        from sqlalchemy import create_engine, text
        from sqlalchemy.pool import NullPool

        # A throwaway engine (NullPool) so the held lock connection never
        # consumes the app's request pool.
        eng = create_engine(settings.DATABASE_URL, poolclass=NullPool)
        conn = eng.connect()
        acquired = conn.execute(
            text("SELECT pg_try_advisory_lock(:k)"), {"k": _SCHEDULER_LOCK_KEY}
        ).scalar()
        if acquired:
            _lock_conn = conn  # hold the lock for this process's lifetime
            logger.info("[scheduler] acquired leader lock — running cron on this instance")
            return True
        conn.close()
        logger.info("[scheduler] another instance owns the scheduler lock — standing down")
        return False
    except Exception as e:  # noqa: BLE001 - never let lock issues kill scheduling
        logger.warning(f"[scheduler] advisory-lock check failed ({e}); running scheduler anyway")
        return True
