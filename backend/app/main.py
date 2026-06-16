import os
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI
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
from app.routers import community as community_router, sports as sports_router
from app.routers import directory as directory_router, announcements as announcements_router
from app.routers import gallery as gallery_router, green_fyc as green_router
from app.routers import volunteers as volunteers_router
from app.routers import thirukkural as thirukkural_router
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
                name_ta="பிரண்ட்ஸ் யூத் கிளப் (நாகர்கோவில்)",
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

        # Check if blood donors table is empty, and seed them if so
        from sqlalchemy import text
        donor_count = db.execute(text("SELECT COUNT(*) FROM blood_donors")).scalar() or 0
        if donor_count == 0:
            import subprocess
            import sys
            print("Seeding blood donors from CSV...")
            csv_path = "scripts/friends2support_donors.csv"
            script_path = "scripts/import_donors_csv.py"
            if os.path.exists(csv_path) and os.path.exists(script_path):
                subprocess.run([sys.executable, script_path, "--csv", csv_path])
            else:
                print("CSV or script not found, skipping blood donor seeding.")
    except Exception as e:
        print(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    _seed_database()
    yield


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

# CORS — restrict via ALLOWED_ORIGINS env var in staging/production
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Multi-Tenant Middleware
app.add_middleware(TenantMiddleware)

# Routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(organizations.router, prefix="/api/v1")
app.include_router(geography.router, prefix="/api/v1")
app.include_router(blood_donors.router, prefix="/api/v1")
app.include_router(issues.router, prefix="/api/v1")
app.include_router(events.router, prefix="/api/v1")
app.include_router(membership.router, prefix="/api/v1")
app.include_router(community_router.router, prefix="/api/v1")
app.include_router(sports_router.router, prefix="/api/v1")
app.include_router(users_router.router, prefix="/api/v1")
app.include_router(media_router.router, prefix="/api/v1")
app.include_router(directory_router.router, prefix="/api/v1")
app.include_router(announcements_router.router, prefix="/api/v1")
app.include_router(gallery_router.router, prefix="/api/v1")
app.include_router(green_router.router, prefix="/api/v1")
app.include_router(volunteers_router.router, prefix="/api/v1")
app.include_router(thirukkural_router.router, prefix="/api/v1")

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
