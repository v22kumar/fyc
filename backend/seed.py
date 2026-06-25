import uuid
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.models.user import User, Organization
from app.core.security import get_password_hash

def seed_production():
    db = SessionLocal()
    
    # 1. Create Default Organization
    org = db.query(Organization).filter(Organization.slug == "fyc-connect").first()
    if not org:
        org = Organization(
            id=uuid.uuid4(),
            name="Friends Youth Club",
            slug="fyc-connect"
        )
        db.add(org)
        db.commit()
        db.refresh(org)

    # 2. Create Super Admin
    super_admin_email = "vrn2252@gmail.com"
    user = db.query(User).filter(User.email == super_admin_email).first()
    if not user:
        user = User(
            id=uuid.uuid4(),
            organization_id=org.id,
            email=super_admin_email,
            phone_number="+910000000000",
            hashed_password=get_password_hash("SuperSecureAdmin123!"),
            role="SUPER_ADMIN",
            is_verified=True,
            is_active=True
        )
        db.add(user)
        db.commit()
        print(f"✅ Successfully seeded Super Admin: {super_admin_email}")
    else:
        print("Super Admin already exists.")
        
    db.close()

if __name__ == "__main__":
    seed_production()
