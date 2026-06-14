import uuid
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import Base, engine, SessionLocal
from app.middleware.tenant import TenantMiddleware
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.core.security import get_password_hash
from app.routers import auth

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Backend API Gateway for FYC Connect Multi-Platform System"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific domains (Astro & Next.js)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Multi-Tenant Middleware (enforces X-Organization-ID scoping)
app.add_middleware(TenantMiddleware)

# Include Routers
app.include_router(auth.router, prefix="/api/v1")

@app.on_event("startup")
def startup_event():
    """
    On startup, automatically create database tables (for local SQLite simplicity)
    and seed default organization and superadmin credentials if missing.
    """
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    try:
        # Check if any organization exists
        org = db.query(Organization).first()
        if not org:
            # Seed default Organization (Friends Youth Club)
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
            
            # Seed default Super Administrator user
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
    finally:
        db.close()

@app.get("/api/health", tags=["System"])
def health_check():
    """Health check endpoint to verify API server is operational."""
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "version": "1.0.0"
    }
