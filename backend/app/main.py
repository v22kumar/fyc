import logging
import os
import pathlib
import uuid
from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.core.rate_limit import limiter
from app.core.config import settings
from sqlalchemy.orm import Session
from app.core.database import Base, engine, SessionLocal, get_db
from app.middleware.tenant import TenantMiddleware
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash
from fastapi.staticfiles import StaticFiles
from app.routers import auth
from app.routers import organizations, geography, blood_donors, issues, events, membership
from app.routers import issues_workflow
from app.routers import civic as civic_router
from app.routers import complaint_box as complaint_box_router
from app.routers import work as work_router
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
from app.routers import social_auth as social_auth_router
from app.routers import safety as safety_router
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

        # Rotate a superadmin still holding a published default.
        #
        # FIRST_SUPERADMIN_PASSWORD reads like "the superadmin's password", but
        # it only ever applied on the *first* boot, when the database was empty.
        # On any established database the account kept whatever it was seeded
        # with — so setting the secret satisfied the production guard while the
        # publicly-documented credential stayed live. That gap is the whole
        # problem: the fix looked done and was not.
        #
        # Now the secret means what its name says. If a SUPER_ADMIN still
        # authenticates with a known default and a real password has been
        # supplied, it is replaced on boot. Idempotent: once rotated, no default
        # matches and this does nothing.
        try:
            from app.core.config import KNOWN_DEFAULT_PASSWORDS
            from app.core.security import verify_password
            desired = settings.FIRST_SUPERADMIN_PASSWORD.strip()
            if desired and desired.lower() not in KNOWN_DEFAULT_PASSWORDS:
                for admin in db.query(User).filter(
                        User.role == "SUPER_ADMIN").all():
                    if not admin.password_hash:
                        continue
                    if any(verify_password(default, admin.password_hash)
                           for default in KNOWN_DEFAULT_PASSWORDS):
                        admin.password_hash = get_password_hash(desired)
                        db.commit()
                        logger.warning(
                            "[security] rotated a SUPER_ADMIN password that was "
                            "still a published default")
        except Exception as _re:
            logger.error("[security] superadmin rotation failed: %s", _re)

        # Always ensure default contacts are seeded (idempotent)
        seed_default_contacts(db, uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d"))

        # The civic department directory and the escalation ladders (idempotent).
        #
        # Seeded early, before anything reads it, because the slow part of this
        # subsystem is not code — it is somebody ringing offices to find out who
        # the Assistant Engineer is. The directory exists from today with every
        # office listed and every contact blank, so that work can start now.
        # Nothing user-facing changes until the routing is wired up.
        try:
            from seeds.civic_directory import seed as _seed_civic
            _made = _seed_civic(db, uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d"))
            if any(_made.values()):
                logger.info("[civic] directory seeded: %s", _made)
            # The contacts somebody actually collected, applied on deploy.
            #
            # Without this the directory is forty offices with every phone
            # number blank, which renders as a ladder where no rung can be
            # rung — the exact screen a member sees when they open the
            # Complaint Box asking who to call. The worksheet was parsed,
            # validated and committed weeks before it was ever applied to a
            # running database; nobody noticed, because a dry run and a deploy
            # look identical in a terminal.
            #
            # Idempotent: it only fills contacts that are still blank, and
            # never overwrites an edit an organiser made by hand.
            from scripts.import_civic_contacts import apply_worksheet as _apply
            _applied = _apply(
                db,
                uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d"),
                pathlib.Path(__file__).resolve().parents[1]
                / "seeds" / "civic_contacts.worksheet.json",
            )
            if _applied:
                logger.info("[civic] contacts applied: %s offices", _applied)
        except Exception as _ce:
            # A directory that fails to seed must never stop the app booting.
            logger.warning("[civic] directory seeding skipped: %s", _ce)

        # A few example work listings, so the index is not empty on day one.
        #
        # Somebody who opens a category and finds nothing concludes the whole
        # app is empty and does not come back — a directory has to look like
        # one before anybody adds themselves to it. These are flagged as
        # samples, carry an unusable number, and the app refuses to dial them;
        # putting a stranger's real phone in front of members to make the list
        # look fuller would be worse than an empty list.
        #
        # Off by default. Turn WORK_SAMPLES_ENABLED off — or call
        # seeds.work_samples.remove — once real listings outnumber them.
        try:
            if getattr(settings, "WORK_SAMPLES_ENABLED", False):
                from seeds.work_samples import seed as _seed_work
                _org = uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d")
                _owner = db.query(User).filter(
                    User.organization_id == _org).order_by(
                    User.created_at.asc()).first()
                if _owner is not None:
                    _n = _seed_work(db, _org, _owner.id)
                    if _n:
                        logger.info("[work] %s sample listings seeded", _n)
        except Exception as _we:
            logger.warning("[work] sample seeding skipped: %s", _we)

        # Seed blood donors from CSV if fewer than expected (seeder is idempotent)
        from sqlalchemy import text
        donor_count = db.execute(text("SELECT COUNT(*) FROM blood_donors")).scalar() or 0
        # SKIP_BULK_SEED lets a throwaway boot (end-to-end tests, a scratch
        # database) start clean: the import writes thousands of rows and holds a
        # write lock the whole time, which is enough to make a fresh SQLite file
        # unusable for the first minute of its life.
        _skip_bulk = os.environ.get("SKIP_BULK_SEED", "").strip().lower() in ("1", "true", "yes")
        if (donor_count < 1000
                and os.environ.get("DATABASE_URL") != "sqlite:///:memory:"
                and not _skip_bulk):
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
            # Idempotency: one row per client-generated ball id (multiple NULLs are
            # allowed by both SQLite and Postgres), so an offline retry can't
            # insert a duplicate ball even under a race.
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_cb_client_ball_id ON cricket_balls (client_ball_id)",
            "CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_notifications_user_created ON notifications (user_id, created_at)",
            # Community feed: order by newest within a tenant, and the batched
            # like/repost/comment count lookups the feed does per page.
            "CREATE INDEX IF NOT EXISTS ix_posts_org_created ON posts (organization_id, created_at)",
            "CREATE INDEX IF NOT EXISTS ix_posts_author_id ON posts (author_id)",
            "CREATE INDEX IF NOT EXISTS ix_post_likes_post_id ON post_likes (post_id)",
            "CREATE INDEX IF NOT EXISTS ix_post_reposts_post_id ON post_reposts (post_id)",
            "CREATE INDEX IF NOT EXISTS ix_comments_entity ON comments (entity_type, entity_id)",
            # The 15-second SOS sweep filters on status alone (it serves every
            # org); ix_sos_open leads with organization_id, so the sweep was a
            # full scan every 15 seconds, forever.
            "CREATE INDEX IF NOT EXISTS ix_sos_incidents_status ON sos_incidents (status)",
        ]
        for _stmt in _perf_indexes:
            try:
                db.execute(text(_stmt))
            except Exception as _ie:
                logger.warning(f"[perf-index] skipped ({_ie}): {_stmt}")
        db.commit()

        # Add new columns to existing DB if not present (idempotent). Uses
        # inspect() rather than SQLite-only `PRAGMA table_info`, so it works on
        # Postgres (Supabase) too — the PRAGMA form errored there and silently
        # skipped this whole block via the surrounding try/except.
        from sqlalchemy import inspect as _mig_inspect
        _mig_insp = _mig_inspect(engine)
        for table, col, sql in [
            ("user_profiles", "date_of_birth", "ALTER TABLE user_profiles ADD COLUMN date_of_birth DATE"),
            ("users", "fcm_token", "ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255)"),
            # Celebrations. Added explicitly here — not left to the generic
            # reconcile — because these two missing columns 500'd EVERY query
            # that selects a user profile (/users/me, login, the member card),
            # which shows up as the app opening with "?" where the name goes.
            # BOOLEAN with no default: a plain add Postgres accepts (an integer
            # default on a boolean is what broke it the first time).
            ("user_profiles", "wedding_anniversary", "ALTER TABLE user_profiles ADD COLUMN wedding_anniversary DATE"),
            # What kind of gathering an event is — a competition, a blood camp,
            # a wedding — as opposed to how people register for it. The generic
            # reconcile above adds these too; listed explicitly because the feed
            # and the events list both read them on every request.
            ("events", "event_kind", "ALTER TABLE events ADD COLUMN event_kind VARCHAR(30)"),
            ("events", "venue", "ALTER TABLE events ADD COLUMN venue VARCHAR(200)"),
            # Verification is per channel. A NULL here is not a smaller truth
            # than a date — it is the difference between a number somebody
            # typed and a number somebody answered.
            ("users", "phone_verified_at", "ALTER TABLE users ADD COLUMN phone_verified_at TIMESTAMP"),
            ("users", "email_verified_at", "ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMP"),
            ("user_profiles", "celebrate_publicly", "ALTER TABLE user_profiles ADD COLUMN celebrate_publicly BOOLEAN"),
        ]:
            try:
                existing = {c["name"] for c in _mig_insp.get_columns(table)}
                if col not in existing:
                    db.execute(text(sql))
                    db.commit()
                    print(f"[migration] Added column {table}.{col}")
            except Exception as _me:
                logger.warning(f"[migration] {table}.{col} skipped: {_me}")

        # Ensure the owner account is SUPER_ADMIN. Email + bootstrap password are
        # env-overridable so the credential is not pinned in source; the literal
        # fallback preserves the existing login until BOOTSTRAP_ADMIN_PASSWORD is set.
        # Read via Settings (honours backend/.env locally and Fly/OS env in prod).
        # No hardcoded password — the existing admin already exists in prod, so
        # this only gates first-time bootstrap.
        bootstrap_email = settings.BOOTSTRAP_ADMIN_EMAIL
        bootstrap_password = settings.BOOTSTRAP_ADMIN_PASSWORD
        admin_user = db.query(User).filter(User.email == bootstrap_email).first()
        if not admin_user and not bootstrap_password:
            print("BOOTSTRAP_ADMIN_PASSWORD not set — skipping SUPER_ADMIN bootstrap.")
        elif not admin_user:
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
        # Say once, at boot, whether photos uploaded today will still exist
        # next week. Not a boot failure — a club with no image host should
        # still be able to run everything else — but not silent either, which
        # is how a gallery got emptied by a deploy with nobody noticing.
        from app.routers.media import storage_status

        _media = storage_status()
        if settings.is_production and not _media["survives_a_deploy"]:
            logger.error(
                "[media] uploads are NOT durable: writing to container disk, "
                "which every deploy discards. library_installed=%s "
                "credentials_set=%s — see GET /api/health/media",
                _media["library_installed"],
                _media["credentials_set"],
            )
        else:
            logger.info("[media] storage backend: %s", _media["backend"])

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
                            # Postgres rejects integer defaults on BOOLEAN
                            # ('DEFAULT 1'); translate to true/false first.
                            from sqlalchemy import Boolean as _Bool
                            if isinstance(col.type, _Bool) and str(sd) in ("0", "1"):
                                sd = "true" if str(sd) == "1" else "false"
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

        # Backfill short public share codes for events + tournaments created
        # before the feature existed, then enforce uniqueness. The column itself
        # is added by the schema-reconcile above; here we fill NULLs and add the
        # unique index (create_all only indexes brand-new tables). Best-effort.
        try:
            from app.core.short_code import generate_unique_short_code
            from app.models.event import Event as _Ev
            from app.models.sports import Tournament as _Tn
            from app.models.chess_tournament import ChessTournament as _Ct
            from sqlalchemy import text as _sc_text
            with SessionLocal() as _s:
                _filled = 0
                for _model in (_Ev, _Tn, _Ct):
                    for _row in _s.query(_model).filter(_model.short_code.is_(None)).all():
                        _row.short_code = generate_unique_short_code(_s, _model)
                        _filled += 1
                    _s.commit()
                if _filled:
                    logger.info(f"[short-code] backfilled {_filled} share code(s)")
            for _tbl in ("events", "tournaments", "chess_tournaments"):
                try:
                    with engine.begin() as conn:
                        conn.execute(_sc_text(
                            f"CREATE UNIQUE INDEX IF NOT EXISTS ux_{_tbl}_short_code "
                            f"ON {_tbl} (short_code) WHERE short_code IS NOT NULL"
                        ))
                except Exception as _sie:
                    logger.warning(f"[short-code] index {_tbl}: {_sie}")
        except Exception as _sce:
            logger.warning(f"[short-code] backfill block failed: {_sce}")

        # Chess hot-path indexes + move uniqueness (CRITICAL#3). create_all only
        # indexes brand-new tables, so the long-lived prod chess tables need these
        # created explicitly. Best-effort: a pre-existing duplicate (game_id, ply)
        # would make the unique index fail — logged, not fatal.
        try:
            from sqlalchemy import text as _cx_text
            _chess_ddl = [
                "CREATE INDEX IF NOT EXISTS ix_chess_games_org_status ON chess_games (organization_id, status)",
                "CREATE INDEX IF NOT EXISTS ix_ctm_tournament_id ON chess_tournament_matches (tournament_id)",
                "CREATE INDEX IF NOT EXISTS ix_ctm_game_id ON chess_tournament_matches (game_id)",
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_chess_move_game_ply ON chess_moves (game_id, ply)",
            ]
            for _ddl in _chess_ddl:
                try:
                    with engine.begin() as conn:
                        conn.execute(_cx_text(_ddl))
                except Exception as _ce:
                    logger.warning(f"[chess-index] failed ({_ddl.split(' ON ')[-1]}): {_ce}")
        except Exception as _cie:
            logger.warning(f"[chess-index] block failed: {_cie}")

        # Repair the cricket_balls FK: the live prod table was created with player
        # FKs pointing at the since-removed cricket_players table, so with FK
        # enforcement on, every ball insert fails ("Unable to record this ball").
        try:
            from app.db_repairs import repair_cricket_balls_fk
            repair_cricket_balls_fk(engine)
        except Exception as _cbe:
            logger.warning(f"[schema-repair] cricket_balls rebuild skipped: {_cbe}")

        # Retrofit FK constraints added to the models after the prod tables were
        # first created (user_profiles.geography_id, opportunities/opportunity_
        # applications). Best-effort + idempotent; Postgres-only.
        try:
            from app.db_repairs import add_missing_foreign_keys_postgres
            add_missing_foreign_keys_postgres(engine)
        except Exception as _fke:
            logger.warning(f"[schema-repair] FK retrofit skipped: {_fke}")

        # Backfill: events created before the registration_enabled column
        # existed carry NULL, which the register gate and the app both read as
        # "registration closed" — hiding the Register button on legacy events.
        # Unset means enabled (the column's insert default).
        try:
            from sqlalchemy import text as _bf_text
            with engine.begin() as conn:
                # TRUE (not integer 1) so it's valid for a Postgres boolean
                # column as well as SQLite.
                conn.execute(_bf_text(
                    "UPDATE events SET registration_enabled = TRUE "
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

        # REMOVED: a start-up backfill that tagged every donor-linked
        # PUBLIC_CITIZEN as source='F2S_IMPORT'.
        #
        # It read as a one-off — "self-clears, re-running matches nothing new" —
        # and it was, exactly once. PUBLIC_CITIZEN is not a marker of an import;
        # it is the ordinary role every app member gets, including through
        # /auth/register. So from the moment a real member registered as a blood
        # donor, the next deploy stamped them a Friends2Support contact: out of
        # the club list, off the map, into the cold-call directory, with no
        # record that it had happened.
        #
        # The importer tags its own rows at import time, which is where that
        # belongs. Nothing needs to infer it afterwards from a role that cannot
        # carry the distinction.
        #
        # Repairing what it already did, precisely. A date of birth is the one
        # thing the directory import never supplies and registration always
        # requires — the onboarding gate will not let an account through
        # without it. So a tagged user who has one registered in this app, and
        # the tag is wrong. No role is read and nothing is guessed; the reverse
        # direction (moving somebody *into* the cold-call list) never happens
        # here. Self-clearing: once repaired, it matches nothing.
        try:
            from sqlalchemy import text as _f2s_text
            with engine.begin() as conn:
                _fixed = conn.execute(_f2s_text(
                    "UPDATE users SET source = NULL "
                    "WHERE source = 'F2S_IMPORT' "
                    "AND id IN (SELECT user_id FROM user_profiles "
                    "           WHERE date_of_birth IS NOT NULL)"))
                if getattr(_fixed, "rowcount", 0):
                    logger.info(
                        f"[data-backfill] restored {_fixed.rowcount} member(s) "
                        "wrongly filed as Friends2Support imports")
        except Exception as _f2se:
            logger.warning(f"[data-backfill] restore mislabelled members: {_f2se}")

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

        # One-off: fix cricket tournament points (2 per win) and NRR match_config
        try:
            from app.core.database import SessionLocal as _FixSession
            from app.models.sports import Tournament as _T, Fixture as _F, Team as _Tm
            _db = _FixSession()
            try:
                _t = _db.query(_T).filter(_T.sport == "cricket").first()
                if _t and _t.match_config == "9 Overs":
                    _t.match_config = "10 Overs"
                
                for _team in _db.query(_Tm).all():
                    _team.points = 0
                    _team.wins = 0
                    _team.losses = 0
                    _team.ties = 0

                for _f in _db.query(_F).filter(_F.status == "COMPLETED").all():
                    if _f.winner_id:
                        _wt = _db.query(_Tm).filter(_Tm.id == _f.winner_id).first()
                        _lt_id = _f.team_b_id if str(_f.team_a_id) == str(_f.winner_id) else _f.team_a_id
                        _lt = _db.query(_Tm).filter(_Tm.id == _lt_id).first()
                        
                        if _wt:
                            _wt.wins = (_wt.wins or 0) + 1
                            _wt.points = (_wt.points or 0) + 2
                        if _lt:
                            _lt.losses = (_lt.losses or 0) + 1
                    else:
                        _ta = _db.query(_Tm).filter(_Tm.id == _f.team_a_id).first()
                        _tb = _db.query(_Tm).filter(_Tm.id == _f.team_b_id).first()
                        if _ta:
                            _ta.ties = (_ta.ties or 0) + 1
                            _ta.points = (_ta.points or 0) + 1
                        if _tb:
                            _tb.ties = (_tb.ties or 0) + 1
                            _tb.points = (_tb.points or 0) + 1
                
                _db.commit()
                logger.info("[data-backfill] Re-calculated tournament points (2 per win) and NRR match config")
            finally:
                _db.close()
        except Exception as _fe:
            logger.warning(f"[data-backfill] tournament fix failed: {_fe}")

        _seed_database()

        # Pre-warm external API caches in a background thread so slow RSS feeds
        # don't delay the server becoming ready.
        import threading as _threading
        import asyncio as _asyncio
        def _prewarm():
            try:
                from app.services.weather import get_weather
                from app.services.gold_price import get_gold_price
                from app.services import news as _news_svc
                # These services are async (httpx). This runs in a fresh thread
                # with no event loop, so drive the coroutines with asyncio.run —
                # calling them bare returned un-awaited coroutines, making the
                # whole pre-warm a silent no-op.
                async def _warm():
                    await get_weather(8.1833, 77.4119)
                    await get_gold_price()
                    await _news_svc.get_top_tamil_news()
                    await _news_svc.get_india_news()
                    await _news_svc.get_kanyakumari_news()
                    await _news_svc.get_tn_jobs_news()
                    await _news_svc.get_central_jobs_news()
                _asyncio.run(_warm())
                logger.info("[startup] All caches pre-warmed (weather, gold, news×5)")
            except Exception as _e:
                logger.warning(f"[startup] Cache pre-warm failed: {_e}")
            # Generate today's AI digest + news summary now (idempotent — cached
            # per day), so the Home AI cards are populated immediately on deploy
            # instead of waiting for the morning cron. No-op without a Gemini key.
            if settings.GEMINI_API_KEY:
                from app.services.daily_digest import (
                    run_ai_daily_digest_job, run_ai_news_summary_job,
                )
                # Run the two jobs independently so one failing doesn't skip the other.
                for _label, _job in (("daily digest", run_ai_daily_digest_job),
                                     ("news summary", run_ai_news_summary_job)):
                    try:
                        _job()
                    except Exception as _aie:
                        logger.warning(f"[startup] AI {_label} generation failed: {_aie}")
                logger.info("[startup] AI content generation attempted")
        _threading.Thread(target=_prewarm, daemon=True).start()


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
        
        # Every daily cron carries an hour of misfire grace: APScheduler's
        # default is ONE second, so a redeploy or cold start straddling the
        # trigger minute silently skipped that day's run.
        scheduler.add_job(run_birthday_notifications, "cron", hour=0, minute=31, timezone="UTC",
                          id="birthday_notifications", replace_existing=True, misfire_grace_time=3600)

        from app.services.daily_digest import (
            run_thirukkural_digest, 
            run_news_digest, 
            run_evening_digest,
            run_ai_daily_digest_job,
            run_ai_news_summary_job,
            run_notification_cleanup
        )
        scheduler.add_job(run_thirukkural_digest, "cron", hour=3, minute=30, timezone="UTC",  # 9:00 AM IST
                          id="thirukkural_digest", replace_existing=True, misfire_grace_time=3600)
        scheduler.add_job(run_news_digest, "cron", hour=4, minute=30, timezone="UTC",  # 10:00 AM IST
                          id="news_digest", replace_existing=True, misfire_grace_time=3600)
        scheduler.add_job(run_evening_digest, "cron", hour=14, minute=30, timezone="UTC",  # 8:00 PM IST
                          id="evening_digest", replace_existing=True, misfire_grace_time=3600)
                          
        # Nightly database cleanup
        scheduler.add_job(run_notification_cleanup, "cron", hour=2, minute=0, timezone="UTC",  # 7:30 AM IST
                          id="notification_cleanup", replace_existing=True, misfire_grace_time=3600)

        # AI pre-cache jobs — populate the Home AI cards ahead of peak hours.
        # Only scheduled when a Gemini key is configured (the jobs no-op without
        # it, but skipping keeps the scheduler clean).
        if settings.GEMINI_API_KEY:
            scheduler.add_job(run_ai_daily_digest_job, "cron", hour=2, minute=45, timezone="UTC",  # 8:15 AM IST
                              id="ai_daily_digest", replace_existing=True, misfire_grace_time=3600)
            scheduler.add_job(run_ai_news_summary_job, "cron", hour=4, minute=45, timezone="UTC",  # 10:15 AM IST
                              id="ai_news_summary", replace_existing=True, misfire_grace_time=3600)
            logger.info("[scheduler] AI digest + news summary jobs scheduled")

        # Social feed sync — pulls Instagram/Facebook/Threads posts into the
        # community feed hourly. Runs independently of the WhatsApp morning
        # broadcast (it was previously trapped behind that unrelated flag, so the
        # feed never synced). The job itself no-ops for any org without tokens.
        from app.services.social_sync import sync_social_feeds
        scheduler.add_job(sync_social_feeds, "interval", hours=1,
                          id="social_media_sync", replace_existing=True,
                          max_instances=1, coalesce=True)

        # SOS escalation — the thing that notices nobody answered.
        #
        # Fifteen seconds is frequent for a cron job and cheap in practice: the
        # query is an indexed `status IN (RAISED, WIDENING)` and in a club this
        # size it almost always returns nothing. It is deliberately the only
        # timer in the feature, and it can only ever *widen* a ring — marking
        # somebody safe is a thing only a person knows.
        from app.services.sos_escalation import sweep_escalations
        scheduler.add_job(sweep_escalations, "interval", seconds=15,
                          id="sos_escalation", replace_existing=True,
                          max_instances=1, coalesce=True)

        if settings.MORNING_BROADCAST_ENABLED:
            from app.services.whatsapp_broadcast import daily_broadcast
            scheduler.add_job(
                daily_broadcast,
                'cron',
                hour=0,
                minute=30,
                id='whatsapp_daily_broadcast',
                replace_existing=True,
                misfire_grace_time=3600
            )
            logger.info("[scheduler] Morning broadcast scheduled at 00:30 UTC (6:00 AM IST)")

        from app.services.keepalive import run_keepalive
        scheduler.add_job(run_keepalive, "interval", minutes=4, id="keepalive", replace_existing=True, coalesce=True)

        # Safety net for live chess: adjudicates games whose clock expired while
        # nobody was connected, closes out abandoned boards, advances any
        # tournament bracket left waiting on them, and evicts idle sessions.
        # Without this a single stalled board blocks an entire knockout round.
        from app.services.chess_reaper import run_chess_reaper
        scheduler.add_job(run_chess_reaper, "interval", minutes=2,
                          id="chess_reaper", replace_existing=True,
                          max_instances=1, coalesce=True)
        # Only ONE instance may actually run the scheduler — otherwise every Fly
        # machine fires the same cron jobs (duplicate pushes / WhatsApp blasts to
        # the whole member base). Jobs are still persisted to the shared jobstore
        # above; the non-leader simply never .start()s, so it never executes them.
        from app.core.scheduler_lock import should_run_scheduler
        if should_run_scheduler():
            scheduler.start()
            logger.info("[scheduler] Birthday notifications scheduled at 00:31 UTC (6:01 AM IST)")
            logger.info("[scheduler] Keepalive ping every 4 minutes to prevent Fly.io cold start")
        else:
            logger.info("[scheduler] standing down — another instance owns the cron leader lock")


    yield

    if scheduler is not None and scheduler.running:
        scheduler.shutdown(wait=False)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Backend API Gateway for FYC Connect Multi-Platform System",
    lifespan=lifespan,
)

# Rate limiting. Every router shares this one limiter; app.core.rate_limit
# explains why get_remote_address was counting the whole club as one caller.
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
    opportunities, community, blood_donors, blood_requests,
    geography, green_fyc, instagram, sports, chess,
    search, follows, comments, attachments, system, share, theme
)
app.include_router(auth.router, prefix="/api/v1")
app.include_router(theme.router, prefix="/api/v1")
app.include_router(system.router, prefix="/api/v1")
app.include_router(organizations.router, prefix="/api/v1")
app.include_router(geography.router, prefix="/api/v1")
app.include_router(blood_donors.router, prefix="/api/v1")
app.include_router(blood_requests.router, prefix="/api/v1")
# Before the legacy issues router, not after: FastAPI matches in declaration
# order, and `/issues/queue` would otherwise be swallowed by that router's
# earlier `/issues/{issue_id}` and 422 on parsing "queue" as a UUID.
app.include_router(issues_workflow.router, prefix="/api/v1")
app.include_router(civic_router.router, prefix="/api/v1")
app.include_router(complaint_box_router.router, prefix="/api/v1")
app.include_router(work_router.router, prefix="/api/v1")
app.include_router(issues.router, prefix="/api/v1")
app.include_router(events.router, prefix="/api/v1")
app.include_router(share.router, prefix="/api/v1")
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
app.include_router(social_auth_router.router, prefix="/api/v1")
from app.routers import threads as threads_router
app.include_router(threads_router.router, prefix="/api/v1")

from app.routers import facebook as facebook_router
app.include_router(facebook_router.router, prefix="/api/v1/facebook")


from app.routers import notifications as notifications_router
app.include_router(notifications_router.router, prefix="/api/v1")
app.include_router(safety_router.router, prefix="/api/v1")
from app.routers import diagnostics as diagnostics_router
app.include_router(diagnostics_router.router, prefix="/api/v1")

from app.routers import profile_prompts as profile_prompts_router
app.include_router(profile_prompts_router.router, prefix="/api/v1")

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


@app.get("/api/health/auth", tags=["System"])
def auth_channels_check(db: Session = Depends(get_db)):
    """Which ways into this app are actually configured right now.

    Written after a deploy where OTP and Google sign-in both stopped working and
    there was no way to tell, from outside, whether the cause was a missing
    secret, an expired credential, a bad client id or the code itself. Every
    answer required someone with dashboard access to go looking, and the only
    signal the app gave was "couldn't send the OTP".

    Reports configuration, never values. Knowing that TWILIO_AUTH_TOKEN is set
    is the diagnosis; knowing what it is would be a leak. Deliberately
    unauthenticated for the same reason a health check is: the moment you need
    it most is the moment nobody can sign in.
    """
    from app.services import google_browser_auth

    google_ids = [
        cid for cid in (settings.GOOGLE_CLIENT_ID, settings.GOOGLE_WEB_CLIENT_ID)
        if cid
    ]
    channels = {
        "sms_twilio_verify": bool(
            settings.TWILIO_ACCOUNT_SID
            and settings.TWILIO_AUTH_TOKEN
            and settings.TWILIO_VERIFY_SID
        ),
        "whatsapp_twilio": bool(
            settings.TWILIO_ACCOUNT_SID
            and settings.TWILIO_AUTH_TOKEN
            and settings.TWILIO_WHATSAPP_FROM
        ),
        "email_smtp": bool(settings.SMTP_USER and settings.SMTP_PASSWORD),
        "otp_bypass": bool(settings.OTP_BYPASS_CODE),
    }
    return {
        # If every one of these is false, nobody can sign in and the app will
        # say so at /auth/otp/send. That is the single most useful line here.
        "can_deliver_a_code": any(
            v for k, v in channels.items() if k != "otp_bypass"
        ) or channels["otp_bypass"],
        "channels": channels,
        "google_sign_in": {
            # The router also accepts two well-known first-party client ids, so
            # Google can work with none configured here — this reports whether
            # anything was set deliberately.
            "configured_client_ids": len(google_ids),
            "accepts_first_party_defaults": True,
            # The road that does not depend on how the APK was signed. The
            # native plugin matches on (package name, signing certificate), and
            # Play re-signs uploaded bundles with its own key — so a build can
            # be refused with DEVELOPER_ERROR while every other check passes.
            # When this is true the app falls back to browser OAuth instead of
            # telling the member to use their phone number.
            "browser_fallback": {
                "available": google_browser_auth.is_configured(),
                "missing": google_browser_auth.missing_configuration(),
                # Must match an authorised redirect URI on the web client,
                # character for character. That mismatch is the one mistake
                # here that is invisible until somebody tries to sign in.
                "redirect_uri": google_browser_auth.redirect_uri(),
            },
        },
        "environment": settings.ENVIRONMENT,
        "allowed_origins": settings.allowed_origins_list,
        "session_store": _session_store_report(db),
        # Whether codes are actually reaching phones. A request can succeed
        # while the message never arrives — that failure is invisible unless
        # it is counted.
        "delivery": __import__(
            "app.routers.auth", fromlist=["delivery_report"]).delivery_report(),
    }


def _session_store_report(db: Session) -> dict:
    """Where a half-finished sign-in is kept, and who is keeping it.

    "The code arrived, and then the server said the handle was invalid" has
    several causes that look identical from a phone, and each needs a different
    fix:

    * the store is not the database at all, so a restart loses it;
    * the store is the database, but the table was never created;
    * more than one instance is answering, and send/verify landed on different
      ones — which only matters if the store is per-process.

    Load this twice, a few seconds apart. **If `instance` changes between the
    two loads, more than one machine is serving.** `pending_sign_ins` counts
    rows and never reads them, so it says whether `/otp/send` is actually
    writing anything without exposing a phone number or a code.
    """
    report = {
        # Dialect name only — the URL carries a password.
        "database": engine.dialect.name,
        # Fly gives every machine its own id. Two different values across two
        # loads is the entire diagnosis for "it works every other time".
        "instance": (os.getenv("FLY_MACHINE_ID")
                     or os.getenv("FLY_ALLOC_ID", "")[:8]
                     or "single"),
        "otp_store": "database",
        "table_present": False,
        "pending_sign_ins": None,
    }
    try:
        from app.models.otp import PendingOtp
        report["pending_sign_ins"] = db.query(PendingOtp).count()
        report["table_present"] = True
    except Exception as exc:  # noqa: BLE001 — the failure IS the finding
        report["error"] = type(exc).__name__
    return report


def _recent_image_hosts(db: Session) -> dict:
    """Where the photos people have actually uploaded are being served from.

    `storage_status()` below reports what the *configuration* says. This
    reports what the *data* says, and they are not the same claim: a correctly
    configured Cloudinary tells you nothing about the rows written before it
    was switched on, and those are the ones that will 404 after the next
    deploy.

    So this is the end-to-end test, readable in one page load: upload a photo,
    reload, and see which host it landed on. `res.cloudinary.com` means the CDN
    is carrying it. Anything pointing back at this API means local disk, and
    that file dies with the next deploy.

    Hosts and counts only — never a URL, never who posted it.
    """
    from urllib.parse import urlparse
    from collections import Counter

    hosts: Counter = Counter()
    newest = None
    try:
        from app.models.post import Post
        rows = (db.query(Post.image_urls, Post.created_at)
                .filter(Post.image_urls.isnot(None))
                .order_by(Post.created_at.desc()).limit(25).all())
        for urls, created in rows:
            for url in (urls or []):
                host = urlparse(str(url)).hostname or "relative-path"
                hosts[host] += 1
                if newest is None:
                    newest = host
    except Exception as exc:  # noqa: BLE001 — the failure IS the finding
        return {"error": type(exc).__name__}

    return {
        # The single most useful line: where the last photo posted went.
        "most_recent_image_host": newest,
        "recent_image_hosts": dict(hosts),
        "images_examined": sum(hosts.values()),
    }


@app.get("/api/health/production", tags=["System"])
def production_readiness_check():
    """Whether this deployment could run as ENVIRONMENT=production.

    Flipping that switch is otherwise a coin toss. The app *refuses to boot*
    with known-insecure defaults — a dev SECRET_KEY, an OTP bypass code left
    on, a wildcard CORS origin, the default superadmin password, a SQLite
    database — and if any of those are wrong the club goes offline until
    somebody works out why from a crash log they cannot reach.

    So the same list that would refuse the boot is reported here first, without
    raising. Reasons only, never values: "SECRET_KEY must be set to a real
    secret" names the problem without disclosing the secret, and an empty list
    means the flip is safe.
    """
    from app.core.config import production_blockers
    blockers = production_blockers(settings)
    return {
        "environment": settings.ENVIRONMENT,
        "can_run_as_production": not blockers,
        "blockers": blockers,
    }


@app.get("/api/health/news", tags=["System"])
def news_images_check():
    """Whether the news headlines are getting their pictures.

    The first attempt at this shipped and produced nothing — every item came
    back without an image, and from outside there was no way to tell whether
    the cause was a warm cache, a blocked fetch, or Google handing us its own
    interstitial instead of the publisher's page. Counts, per feed, so the
    answer is one page load rather than another guess.

    `publisher_url_resolved` is the decisive number: an RSS <link> points at
    news.google.com, not the newspaper, and a picture can only be found once
    that has been unwrapped.
    """
    from app.services.news import image_report
    return image_report()


@app.get("/api/health/search", tags=["System"])
def search_sources_check(db: Session = Depends(get_db)):
    """Which of search's sources can actually be queried.

    Search fans out across a dozen tables in one request, and `db.query(Model)`
    is `SELECT *` — so a single column that has drifted out of step with its
    model takes down every result. That is exactly what shipped: a search box
    answering "Failed to load results" for every query, because of one table.

    Each source is now isolated, so a broken one costs only its own results.
    This says *which* one, in one page load, without anybody reading a log or
    having production access. Names and exception classes only — never a row,
    never a value. Unauthenticated for the same reason as the other health
    endpoints: the moment you need it is the moment things are broken.
    """
    from app.services.search import probe
    report = probe(db)
    return {
        "all_sources_healthy": all(v == "ok" for v in report.values()),
        "broken": [k for k, v in report.items() if v != "ok"],
        "sources": report,
    }


@app.get("/api/health/media", tags=["System"])
def media_storage_check(db: Session = Depends(get_db)):
    """Where uploaded photos go, and whether they survive a deploy.

    Same reasoning as /api/health/auth: the interesting failures here are
    invisible from the outside. An upload to the container filesystem succeeds,
    returns a URL, and displays perfectly — until the next deploy replaces the
    container and every one of those URLs 404s. Nothing links the two events,
    which are usually weeks apart.

    Configuration, never values. Reports that the Cloudinary secrets are set,
    not what they are.
    """
    from app.routers.media import storage_status

    return {
        **storage_status(),
        # What the configuration says, and what the data says, are two
        # different claims. Photos written before Cloudinary was switched on
        # are still on a disk the next deploy throws away.
        **_recent_image_hosts(db),
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
    except Exception as e:
        logger.error(f"[readiness] DB check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={"status": "unready", "detail": str(e)[:200]},
        )
    finally:
        db.close()
