import sys
from app.core.database import SessionLocal
from app.models.tenant import Organization

def inject_token(token: str):
    db = SessionLocal()
    org = db.query(Organization).first()
    if not org:
        print("Error: No Organization found.")
        return
        
    org.instagram_access_token = token
    # We use the hardcoded FYC Connect Instagram account ID as fallback if we don't look it up
    org.instagram_account_id = "17841411702636378"
    db.commit()
    print("SUCCESS! Instagram token has been securely injected into the database.")
    print("You can now test posting using the test_social_posting.py script!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inject_instagram_token.py <YOUR_LONG_TOKEN_HERE>")
        sys.exit(1)
        
    inject_token(sys.argv[1])
