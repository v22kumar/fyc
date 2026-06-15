#!/usr/bin/env python3
"""
First-run database initialisation script.
Run once after deploying: docker compose exec api python scripts/init_db.py

Environment variables read from .env / container env:
  DATABASE_URL, SECRET_KEY, FIRST_SUPERADMIN_PHONE,
  FIRST_SUPERADMIN_PASSWORD, FIRST_SUPERADMIN_NAME_EN, FIRST_SUPERADMIN_NAME_TA,
  PUBLIC_DEFAULT_ORG_ID
"""
import os, sys, uuid
from pathlib import Path

# Allow running from project root or backend/
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import engine, SessionLocal, Base
from app.core.security import get_password_hash
from app.models import user as user_models, tenant, geography, blood_donor, event, issue, audit

ORG_ID = uuid.UUID(os.environ.get("PUBLIC_DEFAULT_ORG_ID", "8f8b80b7-4b71-4770-b183-5c5f49e49a1d"))
PHONE  = os.environ.get("FIRST_SUPERADMIN_PHONE", "+919876543210")
PASSW  = os.environ.get("FIRST_SUPERADMIN_PASSWORD", "")
NAME_EN = os.environ.get("FIRST_SUPERADMIN_NAME_EN", "Super Admin")
NAME_TA = os.environ.get("FIRST_SUPERADMIN_NAME_TA", "மேல் நிர்வாகி")

if not PASSW:
    print("❌  FIRST_SUPERADMIN_PASSWORD is not set. Aborting.")
    sys.exit(1)

print("Creating tables…")
Base.metadata.create_all(bind=engine)
print("✅  Tables ready.")

db = SessionLocal()
try:
    from app.models.tenant import Organization
    from app.models.user import User, UserProfile

    org = db.query(Organization).filter(Organization.id == ORG_ID).first()
    if not org:
        org = Organization(
            id=ORG_ID,
            slug="fyc-nagercoil",
            name_ta="நண்பர்கள் இளைஞர் மன்றம் நாகர்கோவில்",
            name_en="Friends Youth Club Nagercoil",
        )
        db.add(org)
        db.commit()
        print(f"✅  Organisation created: {org.name_en}")
    else:
        print(f"ℹ️   Organisation already exists: {org.name_en}")

    admin = db.query(User).filter(User.phone_number == PHONE).first()
    if not admin:
        admin = User(
            id=uuid.uuid4(),
            organization_id=ORG_ID,
            phone_number=PHONE,
            password_hash=get_password_hash(PASSW),
            role="SUPER_ADMIN",
            is_verified=True,
        )
        db.add(admin)
        db.flush()
        db.add(UserProfile(user_id=admin.id, full_name_ta=NAME_TA, full_name_en=NAME_EN))
        db.commit()
        print(f"✅  Super Admin created: {PHONE}")
    else:
        print(f"ℹ️   Super Admin already exists: {PHONE}")

    print("\n🚀  FYC Connect database initialised successfully.")
    print(f"    Admin login  →  phone: {PHONE}")
    print(f"    Org ID       →  {ORG_ID}")
finally:
    db.close()
