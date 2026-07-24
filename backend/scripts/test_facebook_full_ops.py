import sys
import os
import time

# Ensure the app module is in the path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import SessionLocal
from app.routers.facebook import publish_to_facebook, FacebookPostRequest
from app.models.tenant import Organization
from app.services.social_sync import sync_social_feeds
from app.models.post import Post

def test_full_ops():
    db = SessionLocal()
    org = db.query(Organization).first()
    
    if not org or not org.facebook_access_token:
        print("❌ Error: Facebook token not found in database.")
        print("Please run the inject_facebook_token.py script first.")
        return

    print("========================================")
    print("🚀 TESTING FULL FACEBOOK OPERATIONS")
    print("========================================\n")
    
    # --- PHASE 1: PUBLISH ---
    print("1️⃣ PHASE 1: Publishing out to Facebook Page...")
    payload = FacebookPostRequest(
        message="Hello from FYC Connect API! 🚀 Testing Full Operations for FYC Feed sync.",
        image_url="https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?w=800"
    )
    
    post_id = None
    try:
        res = publish_to_facebook(payload, db)
        post_id = res['post_id']
        print(f"✅ SUCCESS! Post was published to Facebook Page.")
        print(f"   Facebook Post ID: {post_id}\n")
    except Exception as e:
        print(f"❌ Failed to post to Facebook: {e}")
        db.close()
        return

    # --- PHASE 2: SYNC PULL ---
    print("2️⃣ PHASE 2: Running background feed sync job...")
    
    # Wait a few seconds to let Facebook's API index the new post
    time.sleep(3)
    
    try:
        sync_social_feeds()
        print("✅ SUCCESS! Background sync job completed.\n")
    except Exception as e:
        print(f"❌ Failed to run sync job: {e}")
        db.close()
        return
        
    # --- PHASE 3: VERIFY DB ---
    print("3️⃣ PHASE 3: Verifying FYC Connect Database...")
    db.commit() # Refresh session
    
    # Check if the post was pulled into the FYC Feed
    synced_post = db.query(Post).filter(
        Post.organization_id == org.id,
        Post.source == "facebook"
    ).order_by(Post.created_at.desc()).first()
    
    if synced_post and f"fb_{post_id}" == synced_post.idempotency_key:
        print(f"✅ SUCCESS! The Facebook post was successfully pulled into the native FYC Feed!")
        print(f"   Post Content: {synced_post.content[:50]}...")
    elif synced_post:
        print(f"⚠️ WARNING: Found a recent Facebook post, but the ID didn't perfectly match.")
        print(f"   Found: {synced_post.idempotency_key}, Expected: fb_{post_id}")
    else:
        print("❌ FAILED: The post was published to Facebook, but the sync job didn't pull it into the FYC database.")

    print("\n========================================")
    print("🎉 FULL OPS TEST COMPLETE 🎉")
    print("========================================")
        
    db.close()

if __name__ == "__main__":
    test_full_ops()
