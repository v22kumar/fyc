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

    # Load environment variables from backend/.env if it exists
    model_config = SettingsConfigDict(
        env_file=os.path.join(BASE_DIR, ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
