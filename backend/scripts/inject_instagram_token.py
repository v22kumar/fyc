import os
import sys
from app.core.database import SessionLocal
from app.models.tenant import Organization

def inject_token(token: str, account_id: str) -> bool:
    """Inject an IG token into the org. Returns True on success, False if there
    was no organization to attach it to. Always closes the session."""
    db = SessionLocal()
    try:
        org = db.query(Organization).first()
        if not org:
            print("Error: No Organization found.")
            return False

        org.instagram_access_token = token
        if account_id:
            org.instagram_account_id = account_id
        db.commit()
        print("SUCCESS! Instagram token has been injected into the database.")
        print("You can now test posting using the test_social_posting.py script!")
        return True
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inject_instagram_token.py <LONG_TOKEN> [ACCOUNT_ID]")
        print("  ACCOUNT_ID may also be supplied via the IG_ACCOUNT_ID env var.")
        sys.exit(1)

    account_id = sys.argv[2] if len(sys.argv) > 2 else os.getenv("IG_ACCOUNT_ID", "")
    ok = inject_token(sys.argv[1], account_id)
    sys.exit(0 if ok else 1)
