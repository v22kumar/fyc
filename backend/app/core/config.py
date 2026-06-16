import os
from pathlib import Path
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
    FCM_SERVER_KEY: str = ""

    # Twilio WhatsApp OTP
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_WHATSAPP_FROM: str = "whatsapp:+14155238886"  # Twilio sandbox default

    # Google OAuth
    GOOGLE_CLIENT_ID: str = ""  # Web/Android OAuth 2.0 client ID from Google Cloud Console


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
