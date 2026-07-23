import logging
import requests
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.tenant import Organization
from app.models.post import Post
from app.models.user import User

logger = logging.getLogger(__name__)

def sync_social_feeds():
    """
    Background job to pull new posts from Instagram and Threads,
    inserting them into the community feed (posts table).
    """
    logger.info("Starting background sync for social feeds...")
    db: Session = SessionLocal()
    try:
        orgs = db.query(Organization).filter(Organization.is_active == True).all()
        for org in orgs:
            admin_user = db.query(User).filter(
                User.organization_id == org.id,
                User.role == "SUPER_ADMIN"
            ).first()
            
            if not admin_user:
                continue
                
            if org.instagram_access_token and org.instagram_account_id:
                _sync_instagram(db, org, admin_user)
                
            if org.threads_access_token and org.threads_account_id:
                _sync_threads(db, org, admin_user)
    except Exception as e:
        logger.error(f"Error during social feed sync: {e}")
    finally:
        db.close()


def _sync_instagram(db: Session, org: Organization, admin_user: User):
    try:
        url = f"https://graph.facebook.com/v19.0/{org.instagram_account_id}/media"
        params = {
            "fields": "id,caption,media_type,media_url,timestamp,permalink",
            "access_token": org.instagram_access_token,
            "limit": 10
        }
        res = requests.get(url, params=params)
        if res.status_code != 200:
            logger.error(f"Failed to fetch Instagram feed: {res.text}")
            return
            
        data = res.json().get("data", [])
        for item in data:
            media_id = item.get("id")
            idem_key = f"ig_{media_id}"
            
            # Check if post already exists
            existing = db.query(Post).filter(
                Post.organization_id == org.id,
                Post.idempotency_key == idem_key
            ).first()
            
            if not existing:
                caption = item.get("caption", "")
                media_url = item.get("media_url")
                
                post = Post(
                    organization_id=org.id,
                    author_id=admin_user.id,
                    content=f"{caption}\n\n[Original Instagram Post]({item.get('permalink')})",
                    image_urls=[media_url] if media_url and item.get("media_type") in ["IMAGE", "CAROUSEL_ALBUM"] else [],
                    category="Announcement",
                    source="instagram",
                    idempotency_key=idem_key
                )
                db.add(post)
                
        db.commit()
    except Exception as e:
        logger.error(f"Exception syncing Instagram for org {org.id}: {e}")


def _sync_threads(db: Session, org: Organization, admin_user: User):
    try:
        # Note: Threads API uses graph.threads.net
        url = f"https://graph.threads.net/v1.0/me/threads"
        params = {
            "fields": "id,media_product_type,media_type,media_url,permalink,text,timestamp,username",
            "access_token": org.threads_access_token,
            "limit": 10
        }
        res = requests.get(url, params=params)
        if res.status_code != 200:
            logger.error(f"Failed to fetch Threads feed: {res.text}")
            return
            
        data = res.json().get("data", [])
        for item in data:
            media_id = item.get("id")
            idem_key = f"threads_{media_id}"
            
            existing = db.query(Post).filter(
                Post.organization_id == org.id,
                Post.idempotency_key == idem_key
            ).first()
            
            if not existing:
                text_content = item.get("text", "")
                media_url = item.get("media_url")
                
                post = Post(
                    organization_id=org.id,
                    author_id=admin_user.id,
                    content=f"{text_content}\n\n[Original Threads Post]({item.get('permalink')})",
                    image_urls=[media_url] if media_url and item.get("media_type") == "IMAGE" else [],
                    category="Announcement",
                    source="threads",
                    idempotency_key=idem_key
                )
                db.add(post)
                
        db.commit()
    except Exception as e:
        logger.error(f"Exception syncing Threads for org {org.id}: {e}")
