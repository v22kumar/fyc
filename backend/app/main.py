import logging
import os
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from app.core.config import settings
from app.core.database import Base, engine, SessionLocal
from app.middleware.tenant import TenantMiddleware
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash
from fastapi.staticfiles import StaticFiles
from app.routers import auth
from app.routers import organizations, geography, blood_donors, issues, events, membership
from app.routers import users as users_router, media as media_router
from app.routers import posts as posts_router
from app.routers import chess_tournaments as chess_tournaments_router
from app.routers import community as community_router, sports as sports_router, cricket as cricket_router
from app.routers import directory as directory_router, announcements as announcements_router
from app.routers import gallery as gallery_router, green_fyc as green_router
from app.routers import volunteers as volunteers_router
from app.routers import thirukkural as thirukkural_router
from app.routers import news as news_router
from app.routers import opportunities as opportunities_router
from app.routers import audit as audit_router
from app.routers import club_requests as club_requests_router
from app.routers import utilities as utilities_router
from app.routers import instagram as instagram_router
from app.routers import broadcasts as broadcasts_router
from app.routers import app_meta as app_meta_router
from app.routers import chess as chess_router
from app.routers import awards as awards_router
from app.routers import weekly_games as weekly_games_router
from app.models.directory import seed_default_contacts

# Import all models so Base.metadata sees them before create_all
import app.models  # noqa: F401


def _seed_database():
    """Seed default organization and superadmin on first startup."""
    db = SessionLocal()
    try:
        org = db.query(Organization).first()
        if not org:
            default_org_id = uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d")
            org = Organization(
                id=default_org_id,
                slug="fyc-nagercoil",
                name_ta="பிரண்ட்ஸ் யூத் கிள்ளு (நாகர்கோவில்)",
                name_en="Friends Youth Club (Nagercoil)"
            )
            db.add(org)
            db.commit()
            db.refresh(org)

            admin_user_id = uuid.UUID("e30d7b27-5d07-4c7a-bc12-f04bf4c86e00")
            superadmin = User(
                id=admin_user_id,
                organization_id=org.id,
                phone_number=settings.FIRST_SUPERADMIN_PHONE,
                email="admin@fycconnect.org",
                password_hash=get_password_hash(settings.FIRST_SUPERADMIN_PASSWORD),
                role="SUPER_ADMIN",
                is_verified=True,
                preferred_language="ta"
            )
            db.add(superadmin)
            db.flush()

            profile = UserProfile(
                user_id=superadmin.id,
                full_name_ta="சூப்பர் அட்மின்",
                full_name_en="Super Administrator"
            )
            db.add(profile)
            db.commit()
            print("Database seeded with default organization and superadmin credentials.")

        # Always ensure default contacts are seeded (idempotent)
        seed_default_contacts(db, uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d"))

        # Seed blood donors from CSV if fewer than expected (seeder is idempotent)
        from sqlalchemy import text
        donor_count = db.execute(text("SELECT COUNT(*) FROM blood_donors")).scalar() or 0
        if donor_count < 1000 and os.environ.get("DATABASE_URL") != "sqlite:///:memory:":
            print(f"Blood donors count is {donor_count} — seeding from friends2support CSV...")
            try:
                import sys as _sys
                _sys.path.insert(0, ".")
                from seeds.import_donors import main as _seed_donors
                _seed_donors()
            except Exception as _e:
                print(f"Blood donor seeding failed: {_e}")

        # Ensure performance indexes exist (idempotent — IF NOT EXISTS)
        db.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_bd_org_bg_avail "
            "ON blood_donors (organization_id, blood_group, is_available)"
        ))
        db.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_bd_geography ON blood_donors (geography_id)"
        ))
        db.commit()

        # Add new columns to existing DB if not present (idempotent)
        for migration in [
            ("user_profiles", "date_of_birth", "ALTER TABLE user_profiles ADD COLUMN date_of_birth DATE"),
            ("users", "fcm_token", "ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255)"),
        ]:
            table, col, sql = migration
            cols = db.execute(text(f"PRAGMA table_info({table})")).fetchall()
            if col not in [c[1] for c in cols]:
                db.execute(text(sql))
                db.commit()
                print(f"[migration] Added column {table}.{col}")

        # Ensure the owner account is SUPER_ADMIN. Email + bootstrap password are
        # env-overridable so the credential is not pinned in source; the literal
        # fallback preserves the existing login until BOOTSTRAP_ADMIN_PASSWORD is set.
        bootstrap_email = os.getenv("BOOTSTRAP_ADMIN_EMAIL", "vrn2252@gmail.com")
        bootstrap_password = os.getenv("BOOTSTRAP_ADMIN_PASSWORD", "V22@kumar")
        admin_user = db.query(User).filter(User.email == bootstrap_email).first()
        if not admin_user:
            admin_user = User(
                id=uuid.uuid4(),
                organization_id=uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d"),
                phone_number="+919999999999",
                email=bootstrap_email,
                password_hash=get_password_hash(bootstrap_password),
                role="SUPER_ADMIN",
                is_verified=True,
                preferred_language="en"
            )
            db.add(admin_user)
            db.flush()
            profile = UserProfile(
                user_id=admin_user.id,
                full_name_ta="அட்மின்",
                full_name_en="Varun Admin"
            )
            db.add(profile)
            db.commit()
            print(f"Created {bootstrap_email} as SUPER_ADMIN.")
        elif admin_user.role != "SUPER_ADMIN":
            # Only elevate role; do not silently reset the password on every boot.
            admin_user.role = "SUPER_ADMIN"
            db.commit()
            print(f"Elevated {bootstrap_email} to SUPER_ADMIN.")
            
    except Exception as e:
        print(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)

    scheduler = None

    # Everything below is real-deployment startup work: schema-drift
    # reconciliation, superadmin/data seeding, external cache pre-warming, and
    # the cron scheduler. It is ALL skipped under TESTING. The pytest fixtures
    # build a fresh in-memory DB from the current models (so there is no drift to
    # heal) and override every route onto that DB, so none of this is exercised
    # by tests. Running it on every function-scoped test's lifespan added roughly
    # 25s/test (~32 minutes across the CI suite).
    if not settings.TESTING:
        # Auto-reconcile schema drift. create_all only creates missing TABLES;
        # it never adds columns to a pre-existing table. On the long-lived prod
        # SQLite, any column added to a model after its table was first created
        # is missing, and every query that selects it 500s (this is what broke
        # ALL logins via user_profiles.gender). Introspect every mapped table and
        # ADD any column the live DB is missing.
        try:
            from sqlalchemy import inspect as _sa_inspect, text as _sql_text
            insp = _sa_inspect(engine)
            live_tables = set(insp.get_table_names())
            added = []
            for table_name, table in Base.metadata.tables.items():
                # Per-table guard: a failure inspecting/altering ONE table must
                # not abort the whole reconcile (that previously left later
                # tables like cricket_balls undrifted -> scoring 500s).
                try:
                    if table_name not in live_tables:
                        continue  # brand-new table — create_all already made it
                    live_cols = {c["name"] for c in insp.get_columns(table_name)}
                    for col in table.columns:
                        if col.name in live_cols:
                            continue
                        try:
                            coltype = col.type.compile(dialect=engine.dialect)
                        except Exception:
                            coltype = "VARCHAR"
                        ddl = f'ALTER TABLE {table_name} ADD COLUMN {col.name} {coltype}'
                        # Carry a server default ONLY when it is a simple constant
                        # literal; SQLite rejects function/expression defaults on
                        # ADD COLUMN. Such columns are added nullable instead.
                        sd = getattr(col.server_default, "arg", None)
                        if sd is not None and isinstance(sd, (str, int, float)):
                            ddl += f" DEFAULT {sd}"
                        for attempt in range(3):
                            try:
                                with engine.begin() as conn:
                                    conn.execute(_sql_text(ddl))
                                added.append(f"{table_name}.{col.name}")
                                break
                            except Exception as _e:
                                m = str(_e).lower()
                                if "duplicate column" in m or "already exists" in m:
                                    break
                                if "locked" in m and attempt < 2:
                                    continue  # retry SQLite write-lock
                                logger.warning(f"[schema-reconcile] {table_name}.{col.name}: {_e}")
                                break
                except Exception as _te:
                    logger.warning(f"[schema-reconcile] table {table_name} skipped: {_te}")
                    continue
            if added:
                logger.info(f"[schema-reconcile] added {len(added)} missing column(s): {added}")
            else:
                logger.info("[schema-reconcile] no drift — all model columns present")
        except Exception as _me:
            logger.warning(f"[schema-reconcile] block failed: {_me}")

        # Reconcile TimestampMixin drift: deleted_at / metadata_json were added
        # AFTER several tables were created; backfill every nullable, non-FK model
        # column missing from its table.
        try:
            from sqlalchemy import inspect as _sa_inspect, text as _drift_text
            insp = _sa_inspect(engine)
            with engine.begin() as conn:
                for table in Base.metadata.sorted_tables:
                    if not insp.has_table(table.name):
                        continue
                    existing = {c["name"] for c in insp.get_columns(table.name)}
                    for col in table.columns:
                        if col.name in existing or col.foreign_keys or not col.nullable:
                            continue
                        coltype = col.type.compile(dialect=engine.dialect)
                        try:
                            conn.execute(_drift_text(
                                f'ALTER TABLE "{table.name}" ADD COLUMN "{col.name}" {coltype}'
                            ))
                            logger.info(f"[schema-drift] added {table.name}.{col.name} ({coltype})")
                        except Exception as _ce:
                            logger.warning(f"[schema-drift] could not add {table.name}.{col.name}: {_ce}")
        except Exception as _de:
            logger.warning(f"[schema-drift] reconciliation block: {_de}")

        # Idempotency unique indexes. create_all only adds these to brand-new
        # tables, so the long-lived prod posts/comments tables need them created
        # explicitly. Partial (WHERE key IS NOT NULL) so historical NULL-key rows
        # are unconstrained. Best-effort: if pre-existing duplicate keys make the
        # unique index fail, log and continue rather than blocking startup.
        try:
            from sqlalchemy import text as _idx_text
            _idem_indexes = [
                'CREATE UNIQUE INDEX IF NOT EXISTS uq_post_idempotency '
                'ON posts (organization_id, author_id, idempotency_key) '
                'WHERE idempotency_key IS NOT NULL',
                'CREATE UNIQUE INDEX IF NOT EXISTS uq_comment_idempotency '
                'ON comments (organization_id, author_id, entity_id, idempotency_key) '
                'WHERE idempotency_key IS NOT NULL',
            ]
            with engine.begin() as conn:
                for _ddl in _idem_indexes:
                    try:
                        conn.execute(_idx_text(_ddl))
                    except Exception as _ie:
                        logger.warning(f"[idempotency-index] could not create: {_ie}")
        except Exception as _ide:
            logger.warning(f"[idempotency-index] block failed: {_ide}")

        _seed_database()

        # Pre-warm external API caches in a background thread so slow RSS feeds
        # don't delay the server becoming ready.
        import threading as _threading
        def _prewarm():
            try:
                from app.services.weather import get_weather
                from app.services.gold_price import get_gold_price
                from app.services import news as _news_svc
                get_weather(8.1833, 77.4119)
                get_gold_price()
                _news_svc.get_top_tamil_news()
                _news_svc.get_india_news()
                _news_svc.get_kanyakumari_news()
                _news_svc.get_tn_jobs_news()
                _news_svc.get_central_jobs_news()
                logger.info("[startup] All caches pre-warmed (weather, gold, news×5)")
            except Exception as _e:
                logger.warning(f"[startup] Cache pre-warm failed: {_e}")
        _threading.Thread(target=_prewarm, daemon=True).start()

        # Schedulers — birthday always on; morning broadcast requires the flag.
        from apscheduler.schedulers.asyncio import AsyncIOScheduler
        from app.services.birthdays import run_birthday_notifications
        scheduler = AsyncIOScheduler()
        scheduler.add_job(run_birthday_notifications, "cron", hour=0, minute=31, timezone="UTC",
                          id="birthday_notifications", replace_existing=True)

        from app.services.daily_digest import run_morning_digest, run_evening_digest
        scheduler.add_job(run_morning_digest, "cron", hour=2, minute=30, timezone="UTC",  # 8:00 AM IST
                          id="morning_digest", replace_existing=True)
        scheduler.add_job(run_evening_digest, "cron", hour=14, minute=30, timezone="UTC",  # 8:00 PM IST
                          id="evening_digest", replace_existing=True)

        if settings.MORNING_BROADCAST_ENABLED:
            from app.services.whatsapp_broadcast import run_morning_broadcast
            scheduler.add_job(run_morning_broadcast, "cron", hour=0, minute=30, timezone="UTC",
                              id="morning_broadcast", replace_existing=True)
            logger.info("[scheduler] Morning broadcast scheduled at 00:30 UTC (6:00 AM IST)")

        async def _keepalive():
            try:
                import httpx
                async with httpx.AsyncClient(timeout=5) as c:
                    await c.get("http://localhost:8000/api/health")
            except Exception as exc:
                logger.debug("[scheduler] keepalive ping failed: %s", exc)

        scheduler.add_job(_keepalive, "interval", minutes=4, id="keepalive", replace_existing=True)
        scheduler.start()
        logger.info("[scheduler] Birthday notifications scheduled at 00:31 UTC (6:01 AM IST)")
        logger.info("[scheduler] Keepalive ping every 4 minutes to prevent Fly.io cold start")

    yield

    if scheduler is not None and scheduler.running:
        scheduler.shutdown(wait=False)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Backend API Gateway for FYC Connect Multi-Platform System",
    lifespan=lifespan,
)

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS. A literal "*" origin is INVALID together with allow_credentials=True —
# browsers reject the response, surfacing as "Failed to fetch" on any preflighted
# (POST/JSON) request such as Google sign-in. We therefore always use
# allow_origin_regex (which REFLECTS the matched Origin — valid with credentials)
# and ALWAYS allow the app's own first-party frontends + localhost dev, regardless
# of how ALLOWED_ORIGINS is configured, so the web/admin clients can never be
# CORS-blocked by a misconfigured env var.
import re as _re

_first_party = [
    r"https://fyc-web\.fly\.dev",
    r"https://fyc-admin\.fly\.dev",
    r"https?://localhost(:\d+)?",
    r"https?://127\.0\.0\.1(:\d+)?",
]
if settings.allowed_origins_list == ["*"]:
    _cors_regex = ".*"
else:
    _cors_regex = "^(" + "|".join(
        _first_party + [_re.escape(o) for o in settings.allowed_origins_list]
    ) + ")$"

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=_cors_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Multi-Tenant Middleware
app.add_middleware(TenantMiddleware)

# Compress list/feed responses (posts, events, tournaments, ...) — the single
# biggest bandwidth win for users on slow/expensive connections. Small
# responses (health checks, single-record reads) are left uncompressed via
# minimum_size so gzip's own overhead never makes a tiny response bigger.
app.add_middleware(GZipMiddleware, minimum_size=500)


@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception):
    """Catch-all for bugs that aren't an intentional HTTPException (which
    FastAPI already handles with its own status/detail). Logs the real
    traceback server-side and returns one clean, human message client-side —
    never a raw 500/traceback, matching the mobile app's error-mapping
    ("Something went wrong on our end. Please try again.")."""
    logger.exception(f"Unhandled exception on {request.method} {request.url.path}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong on our end. Please try again."},
    )

# Routers
from app.routers import (
    users, auth, directory,
    news, announcements, gallery,
    events, issues, club_requests,
    opportunities, community, blood_donors,
    geography, green_fyc, instagram, sports, chess,
    search, follows, comments, attachments, system
)
app.include_router(auth.router, prefix="/api/v1")
app.include_router(system.router, prefix="/api/v1")
app.include_router(organizations.router, prefix="/api/v1")
app.include_router(geography.router, prefix="/api/v1")
app.include_router(blood_donors.router, prefix="/api/v1")
app.include_router(issues.router, prefix="/api/v1")
app.include_router(events.router, prefix="/api/v1")
app.include_router(membership.router, prefix="/api/v1")
app.include_router(community_router.router, prefix="/api/v1")
app.include_router(search.router, prefix="/api/v1")
app.include_router(follows.router, prefix="/api/v1")
app.include_router(comments.router, prefix="/api/v1")
app.include_router(attachments.router, prefix="/api/v1")
app.include_router(sports_router.router, prefix="/api/v1")
app.include_router(cricket_router.router, prefix="/api/v1")
app.include_router(users_router.router, prefix="/api/v1")
app.include_router(media_router.router, prefix="/api/v1")
app.include_router(posts_router.router, prefix="/api/v1")
app.include_router(chess_tournaments_router.router, prefix="/api/v1")
app.include_router(directory_router.router, prefix="/api/v1")
app.include_router(announcements_router.router, prefix="/api/v1")
app.include_router(gallery_router.router, prefix="/api/v1")
app.include_router(green_router.router, prefix="/api/v1")
app.include_router(volunteers_router.router, prefix="/api/v1")
app.include_router(thirukkural_router.router, prefix="/api/v1")
app.include_router(news_router.router, prefix="/api/v1")
app.include_router(opportunities_router.router, prefix="/api/v1")
app.include_router(audit_router.router, prefix="/api/v1")
app.include_router(club_requests_router.router, prefix="/api/v1")
app.include_router(utilities_router.router, prefix="/api/v1")
app.include_router(instagram_router.router, prefix="/api/v1")
app.include_router(broadcasts_router.router, prefix="/api/v1")
app.include_router(app_meta_router.router, prefix="/api/v1")
app.include_router(chess_router.router, prefix="/api/v1")
app.include_router(awards_router.router, prefix="/api/v1")
app.include_router(weekly_games_router.router, prefix="/api/v1")

from app.routers import notifications as notifications_router
app.include_router(notifications_router.router, prefix="/api/v1")

# Serve uploaded files (swap for S3 CDN URL in production)
from pathlib import Path as FilePath
FilePath("uploads").mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.get("/api/health", tags=["System"])
def health_check():
    """Liveness probe: confirms the process is up and serving. Intentionally does
    NOT touch the database, so it stays cheap and never flaps on transient DB load.
    Use /api/health/ready for deploy gating."""
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "version": "1.0.0"
    }


@app.get("/api/health/ready", tags=["System"])
def readiness_check():
    """Readiness probe: verifies the DB is reachable AND its schema matches the ORM.

    The shallow /api/health stayed 200 throughout the login outage caused by
    schema drift (`organizations.deleted_at` missing -> every query 500s), so a
    Fly check against it would have let a broken release go green. This probe runs
    a real ORM query against a core table, so connection loss or column drift makes
    it return 503 -> the deploy fails its health check instead of going green.
    """
    from fastapi.responses import JSONResponse

    db = SessionLocal()
    try:
        db.query(Organization).first()
        return {"status": "ready"}
    except Exception as e:  # noqa: BLE001 - any DB failure must fail the probe
        logger.error(f"[readiness] DB check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={"status": "unready", "detail": str(e)[:200]},
        )
    finally:
        db.close()
