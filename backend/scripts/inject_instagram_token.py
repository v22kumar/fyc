import os
import sys
from app.core.database import SessionLocal
from app.models.tenant import Organization

def inject_token(token: str, account_id: str):
    db = SessionLocal()
    org = db.query(Organization).first()
    if not org:
        print("Error: No Organization found.")
        return

    org.instagram_access_token = token
    if account_id:
        org.instagram_account_id = account_id
    db.commit()
    print("SUCCESS! Instagram token has been securely injected into the database.")
    print("You can now test posting using the test_social_posting.py script!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inject_instagram_token.py <LONG_TOKEN> [ACCOUNT_ID]")
        print("  ACCOUNT_ID may also be supplied via the IG_ACCOUNT_ID env var.")
        sys.exit(1)

    account_id = sys.argv[2] if len(sys.argv) > 2 else os.getenv("IG_ACCOUNT_ID", "")
    inject_token(sys.argv[1], account_id)
