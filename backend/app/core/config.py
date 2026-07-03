import os
from pathlib import Path
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Base directory of the backend project
BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "FYC Connect"

    # "development" | "staging" | "production" — gates the startup secret checks below.
    ENVIRONMENT: str = "development"

    SECRET_KEY: str = "supersecretdevkeyforfycconnect2026jwtencryptionkeys"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    DATABASE_URL: str = "sqlite:////app/data/fyc_connect.db"

    FIRST_SUPERADMIN_PHONE: str = "+919876543210"
    FIRST_SUPERADMIN_PASSWORD: str = "supersecureadminpassword123"

    # Comma-separated list of allowed CORS origins, e.g. "https://fycconnect.org,https://admin.fycconnect.org"
    ALLOWED_ORIGINS: str = "*"

    # Set to a fixed value in tests/dev to skip random OTP generation.
    # Leave unset in production so real random OTPs are generated.
    OTP_BYPASS_CODE: str = ""

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


_DEFAULT_SECRET_KEY = "supersecretdevkeyforfycconnect2026jwtencryptionkeys"
_DEFAULT_SUPERADMIN_PASSWORD = "supersecureadminpassword123"


def _validate_production_secrets(s: "Settings") -> None:
    """
    Refuse to boot with known-insecure defaults when ENVIRONMENT=production.
    Dev/staging are left untouched — OTP_BYPASS_CODE remains usable there
    until real OTP delivery is wired up.
    """
    if not s.is_production:
        return

    errors = []
    if s.SECRET_KEY == _DEFAULT_SECRET_KEY:
        errors.append("SECRET_KEY is still the insecure default")
    if s.FIRST_SUPERADMIN_PASSWORD == _DEFAULT_SUPERADMIN_PASSWORD:
        errors.append("FIRST_SUPERADMIN_PASSWORD is still the insecure default")
    if s.OTP_BYPASS_CODE:
        errors.append("OTP_BYPASS_CODE must be unset in production")
    if s.ALLOWED_ORIGINS == "*":
        errors.append("ALLOWED_ORIGINS must not be '*' in production")

    if errors:
        raise RuntimeError(
            "Refusing to start with ENVIRONMENT=production: " + "; ".join(errors)
        )


settings = Settings()
_validate_production_secrets(settings)
