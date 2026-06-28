import logging
import os
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI

logger = logging.getLogger(__name__)
from fastapi.middleware.cors import CORSMiddleware
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
        if donor_count < 1000:
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

    # Safe column migrations — idempotent; try/except handles "duplicate column
    # name" on SQLite (which does NOT support ALTER TABLE ... IF NOT EXISTS
    # before version 3.37.0).
    try:
        from sqlalchemy import text as _sql_text
        _migrations = [
            "ALTER TABLE public_issues ADD COLUMN is_emergency BOOLEAN DEFAULT FALSE",
            "ALTER TABLE tournaments ADD COLUMN num_teams INTEGER",
            "ALTER TABLE tournaments ADD COLUMN match_config VARCHAR(60)",
            "ALTER TABLE tournaments ADD COLUMN registration_mode VARCHAR(20) DEFAULT 'MANUAL_APPROVAL'",
            "ALTER TABLE tournaments ADD COLUMN start_date TIMESTAMPTZ",
            "ALTER TABLE tournaments ADD COLUMN end_date TIMESTAMPTZ",
            "ALTER TABLE tournaments ADD COLUMN venue VARCHAR(200)",
            "ALTER TABLE tournaments ADD COLUMN show_points_table BOOLEAN DEFAULT TRUE",
            "ALTER TABLE tournaments ADD COLUMN show_live_scores BOOLEAN DEFAULT TRUE",
            "ALTER TABLE tournaments ADD COLUMN show_prize_details BOOLEAN DEFAULT FALSE",
            "ALTER TABLE tournaments ADD COLUMN prize_details TEXT",
            "ALTER TABLE events ADD COLUMN is_published BOOLEAN DEFAULT FALSE",
            "ALTER TABLE events ADD COLUMN registration_deadline TIMESTAMPTZ",
            "ALTER TABLE events ADD COLUMN max_participants INTEGER",
            "ALTER TABLE events ADD COLUMN competition_categories JSON",
            "ALTER TABLE teams ADD COLUMN status VARCHAR(20) DEFAULT 'PENDING'",
            # Auth-critical: these UserProfile/User columns are read while building
            # UserOut on every login/OTP/me call. create_all never adds columns to a
            # pre-existing table, so on a long-lived DB their absence 500s ALL auth.
            "ALTER TABLE user_profiles ADD COLUMN gender VARCHAR(20)",
            "ALTER TABLE user_profiles ADD COLUMN date_of_birth DATE",
            "ALTER TABLE user_profiles ADD COLUMN address_line_ta VARCHAR(255)",
            "ALTER TABLE user_profiles ADD COLUMN address_line_en VARCHAR(255)",
            "ALTER TABLE user_profiles ADD COLUMN geography_id CHAR(32)",
            "ALTER TABLE user_profiles ADD COLUMN profile_image_url VARCHAR(255)",
            "ALTER TABLE user_profiles ADD COLUMN last_login_at TIMESTAMP",
            "ALTER TABLE users ADD COLUMN google_sub VARCHAR(100)",
            "ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255)",
            "ALTER TABLE users ADD COLUMN email VARCHAR(100)",
        ]
        with engine.connect() as conn:
            for stmt in _migrations:
                try:
                    conn.execute(_sql_text(stmt))
                except Exception as _se:
                    logger.warning(f"[migration] skipped: {_se}")
            conn.commit()
    except Exception as _me:
        logger.warning(f"[migration] column migration block: {_me}")

    _seed_database()

    # Pre-warm external API caches — run in a background thread so slow RSS
    # feeds don't delay the server becoming ready to accept requests.
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

    # Schedulers — birthday always on; morning broadcast requires MORNING_BROADCAST_ENABLED
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from app.services.birthdays import run_birthday_notifications
    scheduler = AsyncIOScheduler()
    scheduler.add_job(run_birthday_notifications, "cron", hour=0, minute=31, timezone="UTC",
                      id="birthday_notifications", replace_existing=True)
    
    from app.services.daily_digest import run_morning_digest, run_evening_digest
    scheduler.add_job(run_morning_digest, "cron", hour=2, minute=30, timezone="UTC", # 8:00 AM IST
                      id="morning_digest", replace_existing=True)
    scheduler.add_job(run_evening_digest, "cron", hour=14, minute=30, timezone="UTC", # 8:00 PM IST
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
        except Exception:
            pass

    scheduler.add_job(_keepalive, "interval", minutes=4, id="keepalive", replace_existing=True)
    scheduler.start()
    logger.info("[scheduler] Birthday notifications scheduled at 00:31 UTC (6:01 AM IST)")
    logger.info("[scheduler] Keepalive ping every 4 minutes to prevent Fly.io cold start")

    yield

    if scheduler.running:
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

from app.routers import notifications as notifications_router
app.include_router(notifications_router.router, prefix="/api/v1")

# Serve uploaded files (swap for S3 CDN URL in production)
from pathlib import Path as FilePath
FilePath("uploads").mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


@app.get("/api/health", tags=["System"])
def health_check():
    """Health check endpoint to verify API server is operational."""
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "version": "1.0.0"
    }
