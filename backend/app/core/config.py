import os
from pathlib import Path
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Base directory of the backend project
BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    #: Example work listings, so the index is not empty on the first day.
    #: They are flagged, marked in the UI and cannot be dialled. Turn off once
    #: real listings outnumber them.
    WORK_SAMPLES_ENABLED: bool = True

    #: Where a member's blind copy goes, so the club learns a letter was
    #: actually sent without having to ask. Disclosed to the member on the
    #: draft screen with a switch — never a silent copy. Empty disables it.
    CLUB_COMPLAINT_BCC: str = ""

    PROJECT_NAME: str = "FYC Connect"
    GEMINI_API_KEY: str = ""

    # "development" | "staging" | "production" — gates the startup secret checks below.
    ENVIRONMENT: str = "development"

    # Set by tests/conftest.py before app import. Gates the background cron
    # scheduler (birthday/digest/broadcast/keepalive jobs) and the external
    # cache pre-warm thread (weather/gold/news) out of the startup lifespan —
    # tests should never spawn a live scheduler or make real external HTTP
    # calls. The `client` pytest fixture is function-scoped, so every single
    # test re-enters this lifespan; leaving these enabled meant every test
    # function created and tore down its own AsyncIOScheduler (tied to a
    # fresh event loop each time) and spawned a new outbound-network thread —
    # a real, unbounded source of slowness/hangs across a full test run that
    # a locally blocked-egress sandbox happened not to surface.
    TESTING: bool = False

    # Dev-safe placeholder default so the app (and the Fly release command, and
    # CI/seed scripts) can always boot. Production is protected at runtime by
    # _validate_production_secrets(), which REFUSES to start with this default
    # when ENVIRONMENT=production — set a real secret via `flyctl secrets set`.
    # A required-with-no-default field instead crashed boot everywhere with an
    # opaque pydantic error, even in dev.
    SECRET_KEY: str = "dev-insecure-secret-change-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    # Long-lived refresh token: the app silently mints new access tokens with it,
    # so users stay signed in until they log out (default 60 days).
    REFRESH_TOKEN_EXPIRE_DAYS: int = 60

    # In-app notification history is pruned nightly to this many days. A
    # notification row is just a "was sent" record — the real event/post/match
    # lives in its own table — so old rows can be dropped without losing data.
    NOTIFICATION_RETENTION_DAYS: int = 7
    # By default, we use local SQLite to remain 100% free and avoid $38/mo cluster fees.
    # The app is fully compatible with PostgreSQL if you ever decide to upgrade.
    DATABASE_URL: str = "sqlite:////app/data/fyc_connect.db"

    # Public base URL of the Astro web app — used to build absolute short share
    # links (…/e/K7P2) and the QR codes that encode them.
    WEB_BASE_URL: str = "https://fycconnect.com"

    # Chess tournament no-show policy: minutes a present, ready player must wait
    # after their round is activated before they may claim a walkover against an
    # opponent who never marked ready. Keeps one absent player from stalling the
    # whole bracket.
    CHESS_READY_TIMEOUT_MINUTES: int = 10

    # Connection-pool sizing for a REMOTE Postgres (e.g. Supabase). Ignored for
    # SQLite. Each threadpooled sync request checks out one connection, so the
    # pool should be sized against FastAPI's threadpool (~40) AND your Postgres
    # plan's connection limit. Prefer the Supabase *pooler* (pgbouncer, port
    # 6543) for the DATABASE_URL so many app connections multiplex onto few DB
    # ones. pool_recycle guards against the provider dropping idle connections.
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20
    DB_POOL_RECYCLE: int = 1800  # seconds
    
    # Valkey (Redis-compatible) cache/session store
    VALKEY_URL: str = "redis://localhost:6379/0"

    FIRST_SUPERADMIN_PHONE: str = "+919876543210"
    # Same pattern as SECRET_KEY: dev-safe default, rejected in production below.
    FIRST_SUPERADMIN_PASSWORD: str = "changeme_admin_password"

    # Owner-account bootstrap (main.py). No password default — first-time
    # SUPER_ADMIN bootstrap is skipped unless BOOTSTRAP_ADMIN_PASSWORD is set.
    # Read via Settings so a value in backend/.env is honoured locally too.
    BOOTSTRAP_ADMIN_EMAIL: str = "vrn2252@gmail.com"
    BOOTSTRAP_ADMIN_PASSWORD: str = ""

    # Comma-separated list of allowed CORS origins, e.g. "https://fycconnect.org,https://admin.fycconnect.org"
    ALLOWED_ORIGINS: str = "https://fycconnect.com,https://www.fycconnect.com,https://admin.fycconnect.com,https://fyc-web.fly.dev,https://fyc-admin.fly.dev"

    # Set to a fixed value in tests/dev to skip random OTP generation.
    # Leave unset in production so real random OTPs are generated.
    OTP_BYPASS_CODE: str | None = None

    # Firebase Cloud Messaging — set in production .env to enable push notifications
    FCM_SERVER_KEY: str = ""  # legacy HTTP API (decommissioned) — do not use

    # Firebase Admin (FCM HTTP v1) — the modern push path. Provide EITHER a path
    # to a service-account JSON file, OR the JSON itself (handy on Fly.io where
    # secrets are env vars). Generate at Firebase Console → Project Settings →
    # Service accounts → "Generate new private key" for project fyc-connect-25ab0.
    # When neither is set, push is silently disabled (in-app notifications still
    # work). On Fly:  flyctl secrets set FIREBASE_CREDENTIALS_JSON="$(cat key.json)"
    FIREBASE_CREDENTIALS_PATH: str = ""
    FIREBASE_CREDENTIALS_JSON: str = ""

    # Twilio — OTP delivery
    # Verify (SMS, recommended): set TWILIO_VERIFY_SID to use Twilio Verify service
    # WhatsApp (sandbox/fallback): set TWILIO_WHATSAPP_FROM
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_VERIFY_SID: str = ""              # e.g. VA2b65749ba818b322b7e071963388cd06
    TWILIO_WHATSAPP_FROM: str = "whatsapp:+14155238886"  # Twilio sandbox default

    # Google OAuth — create two separate OAuth 2.0 client IDs in Google Cloud Console:
    #   Android type → used by the Flutter mobile app
    #   Web application type → used by the Astro web app (set authorized JS origin to fly.dev domain)
    GOOGLE_CLIENT_ID: str = ""      # Android / Flutter client ID
    GOOGLE_WEB_CLIENT_ID: str = ""  # Web browser client ID

    # Cloudinary — image hosting (replaces local disk uploads)
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # Instagram Content Publishing API
    # Set after creating a Business account and getting Meta App Review approval
    INSTAGRAM_ACCOUNT_ID: str = ""    # numeric IG business account ID
    INSTAGRAM_ACCESS_TOKEN: str = ""  # long-lived page access token

    # Meta OAuth app credentials for Instagram Business Login / Threads.
    # Set via `flyctl secrets set IG_APP_SECRET=...` etc. NEVER hardcode these —
    # an app secret in the repo is a credential leak and must be rotated.
    IG_APP_ID: str = ""
    IG_APP_SECRET: str = ""
    IG_ACCOUNT_ID: str = ""            # fallback IG business account id
    THREADS_APP_ID: str = ""
    THREADS_APP_SECRET: str = ""

    # Weather via Open-Meteo (free, no key needed); this var kept for compat only
    OPENWEATHER_API_KEY: str = ""

    # Metal / Gold price API (https://www.goldapi.io — free tier)
    # Set via env / flyctl secrets set GOLD_API_KEY=... — never commit a real key.
    GOLD_API_KEY: str = ""

    # ── Daily WhatsApp Morning Broadcast ────────────────────────────────────
    # Set MORNING_BROADCAST_ENABLED=true in Fly.io env to activate (no redeploy needed)
    MORNING_BROADCAST_ENABLED: bool = False

    # Meta WhatsApp Cloud API — for posting to the FYC WhatsApp group
    # 1. Create Meta Business App → WhatsApp → get phone number ID + permanent token
    # 2. Add the Meta phone number to your WhatsApp group as admin
    # 3. Get the group JID (ends in @g.us) from a webhook message event
    META_WA_TOKEN: str = ""              # permanent page access token
    META_WA_PHONE_NUMBER_ID: str = ""    # e.g. "123456789012345"
    META_WA_GROUP_ID: str = ""           # e.g. "120363xxxxxxxxxx@g.us"

    # Individual sends use the existing TWILIO_* vars above

    # ── App Download ──────────────────────────────────────────────────────────
    # URL served by GET /api/v1/app/download  (302 redirect).
    # Set to wherever the APK lives, e.g.:
    #   flyctl secrets set APP_APK_URL=https://fyc-backend.fly.dev/uploads/fyc-connect-latest.apk
    APP_APK_URL: str = ""

    # In-app updater: latest published Android build. Set by the flutter-build CI
    # on every release so the app can detect a newer version and offer to update.
    APP_LATEST_VERSION_CODE: int = 0          # numeric build number (must increase)
    APP_LATEST_VERSION_NAME: str = ""         # display version, e.g. "1.0.42"
    APP_UPDATE_MANDATORY: bool = False        # force update (block "Later")
    APP_UPDATE_NOTES: str = ""                # short "what's new" text

    # SMTP Email OTP
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""  # Gmail: use App Password, not account password
    SMTP_FROM_EMAIL: str = "noreply@fycconnect.org"

    # Load environment variables from backend/.env if it exists
    model_config = SettingsConfigDict(
        env_file=os.path.join(BASE_DIR, ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @field_validator("APP_UPDATE_MANDATORY", "MORNING_BROADCAST_ENABLED", mode="before")
    @classmethod
    def _lenient_bool(cls, v):
        """Never let a malformed boolean env var crash app startup.

        A mistyped secret (e.g. two key=value pairs collapsed into one value)
        previously raised a ValidationError at import and took the whole backend
        down. Here we coerce defensively: read the first token and treat common
        truthy strings as True, everything else as False.
        """
        if isinstance(v, bool):
            return v
        s = str(v or "").strip()
        if not s:
            return False
        token = s.split()[0].strip("\"'").lower()
        return token in {"1", "true", "yes", "on", "y", "t"}

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() == "production"

    @property
    def allowed_origins_list(self) -> list[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]


def _validate_production_secrets(s: "Settings") -> None:
    """
    Refuse to boot with known-insecure defaults when ENVIRONMENT=production.
    Dev/staging are left untouched — OTP_BYPASS_CODE remains usable there
    until real OTP delivery is wired up.
    """
    if not s.is_production:
        return

    errors = []
    if s.OTP_BYPASS_CODE:
        errors.append("OTP_BYPASS_CODE must be unset in production")
    if s.SECRET_KEY.strip() in ("", "dev-insecure-secret-change-in-production", "changeme"):
        errors.append("SECRET_KEY must be set to a real secret in production")
    if any(origin == "*" for origin in s.allowed_origins_list):
        errors.append("ALLOWED_ORIGINS must not be '*' in production")
    if s.FIRST_SUPERADMIN_PASSWORD.strip().lower() in ("changeme", "changeme_admin_password", "test-superadmin-password"):
        errors.append("FIRST_SUPERADMIN_PASSWORD must be changed from the default in production")
    # A single-file SQLite DB cannot be shared across Fly instances — if the
    # Postgres/Supabase secret is ever missing, the app would silently fall back
    # to a per-machine SQLite file and split-brain writes across instances. Fail
    # loudly instead so production always runs on the shared Postgres.
    if s.DATABASE_URL.strip().lower().startswith("sqlite"):
        errors.append("DATABASE_URL must point to Postgres in production (not SQLite)")

    if errors:
        raise RuntimeError(
            "Refusing to start with ENVIRONMENT=production: " + "; ".join(errors)
        )


settings = Settings()
_validate_production_secrets(settings)
