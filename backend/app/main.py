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
from app.routers import ai as ai_router
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
            print(f"Blood donors count is {donor_count} — seeding from friends2support CSV in background...")
            # The CSV import is the single heaviest boot task (thousands of rows).
            # Run it in a daemon thread with its own DB session so the app starts
            # serving immediately instead of blocking the first request behind it.
            # It's idempotent, so a partial run is safe to resume next boot.
            def _seed_donors_bg():
                try:
                    import sys as _sys
                    _sys.path.insert(0, ".")
                    from seeds.import_donors import main as _seed_donors
                    _seed_donors()
                    logger.info("[startup] Blood-donor CSV import finished (background).")
                except Exception as _e:
                    logger.warning(f"[startup] Blood donor seeding failed: {_e}")
            import threading as _threading
            _threading.Thread(target=_seed_donors_bg, daemon=True).start()

        # Ensure performance indexes exist (idempotent — IF NOT EXISTS)
        db.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_bd_org_bg_avail "
            "ON blood_donors (organization_id, blood_group, is_available)"
        ))
        db.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_bd_geography ON blood_donors (geography_id)"
        ))
        db.commit()

        # Performance indexes for the hot sports/cricket/notification read paths.
        # These columns are filtered on every standings/fixtures/live/notifications
        # query; without an index each was a full table scan. Idempotent, and the
        # single-column names match SQLAlchemy's index=True defaults so a freshly
        # created DB (which already has them) skips these no-ops. (See the lag
        # investigation: un-indexed FKs were a top cause of "feels laggy".)
        _perf_indexes = [
            "CREATE INDEX IF NOT EXISTS ix_teams_tournament_id ON teams (tournament_id)",
            "CREATE INDEX IF NOT EXISTS ix_players_team_id ON players (team_id)",
            "CREATE INDEX IF NOT EXISTS ix_players_user_id ON players (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_fixtures_tournament_id ON fixtures (tournament_id)",
            "CREATE INDEX IF NOT EXISTS ix_fixtures_team_a_id ON fixtures (team_a_id)",
            "CREATE INDEX IF NOT EXISTS ix_fixtures_team_b_id ON fixtures (team_b_id)",
            "CREATE INDEX IF NOT EXISTS ix_fixtures_org_status ON fixtures (organization_id, status)",
            "CREATE INDEX IF NOT EXISTS ix_cricket_balls_match_id ON cricket_balls (match_id)",
            "CREATE INDEX IF NOT EXISTS ix_cb_match_innings_ball ON cricket_balls (match_id, innings_number, ball_index)",
            "CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_notifications_user_created ON notifications (user_id, created_at)",
            # Community feed: order by newest within a tenant, and the batched
            # like/repost/comment count lookups the feed does per page.
            "CREATE INDEX IF NOT EXISTS ix_posts_org_created ON posts (organization_id, created_at)",
            "CREATE INDEX IF NOT EXISTS ix_posts_author_id ON posts (author_id)",
            "CREATE INDEX IF NOT EXISTS ix_post_likes_post_id ON post_likes (post_id)",
            "CREATE INDEX IF NOT EXISTS ix_post_reposts_post_id ON post_reposts (post_id)",
            "CREATE INDEX IF NOT EXISTS ix_comments_entity ON comments (entity_type, entity_id)",
        ]
        for _stmt in _perf_indexes:
            try:
                db.execute(text(_stmt))
            except Exception as _ie:
                logger.warning(f"[perf-index] skipped ({_ie}): {_stmt}")
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

        # Repair the cricket_balls FK: the live prod table was created with player
        # FKs pointing at the since-removed cricket_players table, so with FK
        # enforcement on, every ball insert fails ("Unable to record this ball").
        try:
            from app.db_repairs import repair_cricket_balls_fk
            repair_cricket_balls_fk(engine)
        except Exception as _cbe:
            logger.warning(f"[schema-repair] cricket_balls rebuild skipped: {_cbe}")

        # Backfill: events created before the registration_enabled column
        # existed carry NULL, which the register gate and the app both read as
        # "registration closed" — hiding the Register button on legacy events.
        # Unset means enabled (the column's insert default).
        try:
            from sqlalchemy import text as _bf_text
            with engine.begin() as conn:
                conn.execute(_bf_text(
                    "UPDATE events SET registration_enabled = 1 "
                    "WHERE registration_enabled IS NULL"))
        except Exception as _bfe:
            logger.warning(f"[data-backfill] events.registration_enabled: {_bfe}")

        # One-off: finalize cricket fixtures left with the old "Completed"
        # placeholder score (from before real scores/standings were written on
        # completion). Recalculating writes the true innings scores + result and
        # applies the standings exactly once. Guarded by the placeholder itself
        # (self-clears after finalize), and by resetting status first so the
        # completion path treats it as a fresh finalize — never double-counts.
        try:
            from app.models.cricket import CricketMatch as _CM
            from app.models.sports import Fixture as _BfFx
            from app.routers.cricket import recalculate_match_state as _bf_recalc
            from app.core.database import SessionLocal as _BfSession
            _bdb = _BfSession()
            try:
                _stuck = (
                    _bdb.query(_CM)
                    .join(_BfFx, _CM.fixture_id == _BfFx.id)
                    .filter(_BfFx.team_a_score == "Completed")
                    .all()
                )
                for _m in _stuck:
                    _m.fixture.status = "IN_PROGRESS"
                    _bf_recalc(_bdb, _m)
                if _stuck:
                    logger.info(f"[data-backfill] finalized {len(_stuck)} cricket fixture(s) with real scores + standings")
            finally:
                _bdb.close()
        except Exception as _bfc:
            logger.warning(f"[data-backfill] cricket completion finalize: {_bfc}")

        # One-off: tag existing Friends2Support directory contacts (imported as
        # donor-only PUBLIC_CITIZEN accounts) with source='F2S_IMPORT', so they
        # stay out of member/opponent lists (e.g. the chess members list). Only
        # touches donor-linked public citizens not already tagged — a real
        # member/admin who is also a donor keeps source NULL and still appears
        # everywhere. Self-clears (re-running matches nothing new).
        try:
            from sqlalchemy import text as _f2s_text
            with engine.begin() as conn:
                conn.execute(_f2s_text(
                    "UPDATE users SET source = 'F2S_IMPORT' "
                    "WHERE role = 'PUBLIC_CITIZEN' "
                    "AND (source IS NULL OR source = '') "
                    "AND id IN (SELECT user_id FROM blood_donors)"))
        except Exception as _f2se:
            logger.warning(f"[data-backfill] tag F2S donor contacts: {_f2se}")

        # One-time backfill of the FYC LEAGUE 2026 knockout round, gated by a
        # secret so it only runs when an operator opts in (set SEED_FYC_LEAGUE_2026=1
        # in the Fly dashboard → Secrets, which triggers a redeploy). The seed is
        # idempotent, so leaving the flag set is harmless; remove the secret (and
        # this block, in a follow-up) once the data is confirmed live.
        if os.getenv("SEED_FYC_LEAGUE_2026", "").strip().lower() in ("1", "true", "yes"):
            try:
                from scripts.seed_tournament_results import seed_round, _find_tournament
                from app.core.database import SessionLocal as _SeedSession
                _sdb = _SeedSession()
                try:
                    _target = os.getenv("SEED_FYC_LEAGUE_2026_TOURNAMENT") or None
                    _t = _find_tournament(_sdb, _target)
                    logger.info("[seed-fyc-league] running one-time knockout backfill…")
                    _res = seed_round(_sdb, _t, commit=True, log=logger.info)
                    logger.info(f"[seed-fyc-league] done: {_res}")
                finally:
                    _sdb.close()
            except SystemExit as _se:
                logger.warning(f"[seed-fyc-league] skipped: {_se}")
            except Exception as _sfe:
                logger.warning(f"[seed-fyc-league] failed: {_sfe}")

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

        # Drop corrupted scheduler state before starting (hotfix for unpickling crash)
        try:
            with engine.begin() as conn:
                from sqlalchemy import text
                conn.execute(text("DROP TABLE IF EXISTS apscheduler_jobs;"))
                logger.info("[scheduler] Dropped old apscheduler_jobs table to fix unpickling crash")
        except Exception as _ae:
            logger.warning(f"[scheduler] Could not drop apscheduler_jobs: {_ae}")

        # Schedulers — birthday always on; morning broadcast requires the flag.
        from apscheduler.schedulers.asyncio import AsyncIOScheduler
        from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore
        from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore
        from app.services.birthdays import run_birthday_notifications
        
        # Use SQLAlchemyJobStore to ensure jobs only run once across multiple instances
        jobstores = {
            'default': SQLAlchemyJobStore(engine=engine, tablename='apscheduler_jobs')
        }
        scheduler = AsyncIOScheduler(jobstores=jobstores)
        
        scheduler.add_job(run_birthday_notifications, "cron", hour=0, minute=31, timezone="UTC",
                          id="birthday_notifications", replace_existing=True)

        from app.services.daily_digest import (
            run_thirukkural_digest, 
            run_news_digest, 
            run_evening_digest,
            run_ai_daily_digest_job,
            run_ai_news_summary_job
        )
        scheduler.add_job(run_thirukkural_digest, "cron", hour=3, minute=30, timezone="UTC",  # 9:00 AM IST
                          id="thirukkural_digest", replace_existing=True)
        scheduler.add_job(run_news_digest, "cron", hour=4, minute=30, timezone="UTC",  # 10:00 AM IST
                          id="news_digest", replace_existing=True)
        scheduler.add_job(run_evening_digest, "cron", hour=14, minute=30, timezone="UTC",  # 8:00 PM IST
                          id="evening_digest", replace_existing=True)

        if settings.MORNING_BROADCAST_ENABLED:
            from app.services.whatsapp_broadcast import run_morning_broadcast
            scheduler.add_job(run_morning_broadcast, "cron", hour=0, minute=30, timezone="UTC",
                              id="morning_broadcast", replace_existing=True)
            logger.info("[scheduler] Morning broadcast scheduled at 00:30 UTC (6:00 AM IST)")

        from app.services.keepalive import run_keepalive
        scheduler.add_job(run_keepalive, "interval", minutes=4, id="keepalive", replace_existing=True)
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
app.include_router(ai_router.router, prefix="/api/v1")

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
