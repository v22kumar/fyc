import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

# Base directory of the backend project
BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "FYC Connect"
    SECRET_KEY: str = "supersecretdevkeyforfycconnect2026jwtencryptionkeys"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    DATABASE_URL: str = "sqlite:///./fyc_connect.db"

    FIRST_SUPERADMIN_PHONE: str = "+919876543210"
    FIRST_SUPERADMIN_PASSWORD: str = "supersecureadminpassword123"

    # Set to a fixed value in tests/dev to skip random OTP generation.
    # Leave unset in production so real random OTPs are generated.
    OTP_BYPASS_CODE: str = ""

    # Firebase Cloud Messaging — set in production .env to enable push notifications
    FCM_SERVER_KEY: str = ""

    # Twilio WhatsApp OTP
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_WHATSAPP_FROM: str = "whatsapp:+14155238886"  # Twilio sandbox default

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

settings = Settings()
