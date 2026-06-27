"""Standalone production seeder for the default organization + super admin.

NOTE: Day-to-day seeding happens automatically in app.main._seed_database() at
startup. This script is a manual convenience for fresh environments. Credentials
come from settings (env), never hardcoded.
"""
import uuid

from app.core.database import SessionLocal
from app.core.config import settings
from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def seed_production():
    db = SessionLocal()
    try:
        # 1. Default Organization
        org = db.query(Organization).filter(Organization.slug == "fyc-connect").first()
        if not org:
            org = Organization(
                id=uuid.uuid4(),
                slug="fyc-connect",
                name_ta="பிரண்ட்ஸ் யூத் கிளப்",
                name_en="Friends Youth Club",
            )
            db.add(org)
            db.commit()
            db.refresh(org)

        # 2. Super Admin (credentials from env/settings)
        super_admin_email = "admin@fycconnect.org"
        user = db.query(User).filter(User.email == super_admin_email).first()
        if not user:
            user = User(
                id=uuid.uuid4(),
                organization_id=org.id,
                email=super_admin_email,
                phone_number=settings.FIRST_SUPERADMIN_PHONE,
                password_hash=get_password_hash(settings.FIRST_SUPERADMIN_PASSWORD),
                role="SUPER_ADMIN",
                is_verified=True,
            )
            db.add(user)
            db.flush()
            db.add(UserProfile(
                user_id=user.id,
                full_name_ta="சூப்பர் அட்மின்",
                full_name_en="Super Administrator",
            ))
            db.commit()
            print(f"Seeded Super Admin: {super_admin_email}")
        else:
            print("Super Admin already exists.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_production()
