import sys
import os

# Ensure the app module is in the path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal
from app.models.tenant import Organization

def inject_token(token: str):
    db = SessionLocal()
    try:
        org = db.query(Organization).first()
        if not org:
            print("Error: No organization found in the database.")
            return

        org.facebook_access_token = token
        
        # Reset the page ID so the router fetches it again based on the new token
        org.facebook_page_id = None
        
        db.commit()
        print("SUCCESS! Facebook Page token has been securely injected into the database.")
        print("The backend will automatically resolve the correct Page ID on the first post.")
    except Exception as e:
        print(f"Error injecting token: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inject_facebook_token.py <ACCESS_TOKEN>")
        sys.exit(1)
        
    token = sys.argv[1]
    inject_token(token)
