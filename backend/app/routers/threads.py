from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
import requests
import logging

from sqlalchemy.orm import Session
from app.core.database import get_db
from app.dependencies import get_current_user, RoleChecker
from app.models.user import User
from app.models.tenant import Organization
from app.models.post import Post

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/threads", tags=["Threads"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER", "CLUB_MEMBER"])

class ThreadsPostCreate(BaseModel):
    text: str = Field(..., max_length=500)
    image_url: Optional[str] = None


@router.post(
    "/post",
    status_code=status.HTTP_201_CREATED,
)
def create_threads_post(
    payload: ThreadsPostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Publish a post directly to the organization's Threads account.
    """
    org = db.query(Organization).filter(Organization.id == current_user.organization_id).first()
    if not org or not org.threads_access_token or not org.threads_account_id:
        raise HTTPException(
            status_code=400,
            detail="Threads is not configured for this organization."
        )

    # 1. Create a Threads Media Container
    container_url = f"https://graph.threads.net/v1.0/{org.threads_account_id}/threads"
    container_params = {
        "access_token": org.threads_access_token,
        "text": payload.text
    }
    
    if payload.image_url:
        container_params["media_type"] = "IMAGE"
        container_params["image_url"] = payload.image_url
    else:
        container_params["media_type"] = "TEXT"

    res = requests.post(container_url, data=container_params)
    if res.status_code != 200:
        logger.error(f"Failed to create Threads container: {res.text}")
        raise HTTPException(status_code=400, detail=f"Failed to publish to Threads: {res.json().get('error', {}).get('message')}")
        
    creation_id = res.json().get("id")

    # 2. Publish the Container
    publish_url = f"https://graph.threads.net/v1.0/{org.threads_account_id}/threads_publish"
    publish_params = {
        "access_token": org.threads_access_token,
        "creation_id": creation_id
    }
    pub_res = requests.post(publish_url, data=publish_params)
    if pub_res.status_code != 200:
        logger.error(f"Failed to publish Threads container: {pub_res.text}")
        raise HTTPException(status_code=400, detail=f"Failed to finalize Threads post: {pub_res.json().get('error', {}).get('message')}")

    media_id = pub_res.json().get("id")
    idem_key = f"threads_{media_id}"

    # 3. Save to local posts feed so it shows up instantly
    post = Post(
        organization_id=org.id,
        author_id=current_user.id,
        content=f"{payload.text}",
        image_urls=[payload.image_url] if payload.image_url else [],
        category="Announcement",
        source="threads",
        idempotency_key=idem_key
    )
    db.add(post)
    db.commit()
    db.refresh(post)

    return {"status": "success", "message": "Successfully posted to Threads!", "media_id": media_id, "post_id": post.id}
