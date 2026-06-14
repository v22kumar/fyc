import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import Base, engine, SessionLocal
from app.middleware.tenant import TenantMiddleware
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash
from app.routers import auth
from app.routers import organizations, geography, blood_donors, issues, events, membership

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
    lifespan=lifespan
)

# CORS — in production, restrict to specific domains (Astro & Next.js)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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


@app.get("/api/health", tags=["System"])
def health_check():
    """Health check endpoint to verify API server is operational."""
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "version": "1.0.0"
    }
