import sys
import os

# Ensure the app module is in the path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal
from app.routers.facebook import publish_to_facebook, FacebookPostRequest
from app.models.tenant import Organization

def test_facebook_posting():
    db = SessionLocal()
    org = db.query(Organization).first()
    
    if not org or not org.facebook_access_token:
        print("Error: Facebook token not found in database.")
        print("Please inject a Facebook Page token first.")
        return

    print("--- Testing Facebook Page Posting ---")
    payload = FacebookPostRequest(
        message="Hello from FYC Connect API! 🚀 Testing Facebook Page integration.",
        image_url="https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?w=800"
    )
    
    try:
        res = publish_to_facebook(payload, db)
        print("SUCCESS! Post was published to Facebook Page.")
        print(f"Facebook Post ID: {res['post_id']}")
    except Exception as e:
        print(f"Failed to post to Facebook: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    test_facebook_posting()
