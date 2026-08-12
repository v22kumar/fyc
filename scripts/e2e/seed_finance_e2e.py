"""Seed the people the finance end-to-end test needs, and print their tokens.

The browser test drives the real pages against a real backend, so it needs what
the real thing needs: an organisation, a club official who can create a
collection and verify money, and an ordinary member who is nobody until an
official appoints them.

That second account is the point. The whole permission model turns on a
treasurer being an ordinary member with one appointment — seeding them as an
admin would make the test pass while proving nothing.

Usage (backend importable, DATABASE_URL pointing at a scratch database):

    python scripts/e2e/seed_finance_e2e.py

Prints one JSON object on stdout; everything else goes to stderr.
"""
import json
import os
import sys
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "backend"))

from app.core.database import Base, SessionLocal, engine  # noqa: E402
from app.core.security import create_access_token, get_password_hash  # noqa: E402
from app.models.tenant import Organization  # noqa: E402
from app.models.user import User, UserProfile  # noqa: E402

ADMIN_PHONE = "+919770000101"
TREASURER_PHONE = "+919770000102"


def _person(db, org, name, phone, role):
    # Scoped to the organisation. Matching on the phone alone would adopt a
    # user from another org and never correct it, and the token then carries an
    # organisation the campaign does not belong to — every call 403s.
    user = (db.query(User)
              .filter(User.phone_number == phone, User.organization_id == org.id)
              .first())
    if user is None:
        user = User(
            id=uuid.uuid4(),
            organization_id=org.id,
            phone_number=phone,
            password_hash=get_password_hash("e2e-not-a-real-password"),
            role=role,
            is_verified=True,
        )
        db.add(user)
        db.flush()
        db.add(UserProfile(user_id=user.id, full_name_en=name, full_name_ta=name))
        db.flush()
    return user


def main() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # By slug, not "whichever is first". The backend runs its own startup
        # seed before this script does, and adopting that organisation would
        # point PUBLIC_DEFAULT_ORG_ID somewhere this test never built.
        org = db.query(Organization).filter(Organization.slug == "fyc-e2e").first()
        if org is None:
            org = Organization(id=uuid.uuid4(), slug="fyc-e2e",
                               name_en="Friends Youth Club", name_ta="அ")
            db.add(org)
            db.flush()

        admin = _person(db, org, "Kumar Official", ADMIN_PHONE, "ADMIN")
        # An ordinary member. Everything they can do in this test, they can do
        # only because an official appointed them.
        treasurer = _person(db, org, "Arun Treasurer", TREASURER_PHONE, "CLUB_MEMBER")
        db.commit()

        print(json.dumps({
            "org_id": str(org.id),
            "admin": {
                "id": str(admin.id),
                "name": "Kumar Official",
                "role": admin.role,
                "token": create_access_token(subject=admin.id, role=admin.role,
                                             organization_id=str(org.id)),
            },
            "treasurer": {
                "id": str(treasurer.id),
                "name": "Arun Treasurer",
                "role": treasurer.role,
                "token": create_access_token(subject=treasurer.id, role=treasurer.role,
                                             organization_id=str(org.id)),
            },
        }))
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
