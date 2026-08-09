import os
import requests
import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional, List
from pydantic import BaseModel

from app.core.database import get_db
from app.dependencies import RoleChecker
from app.models.tenant import Organization
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()

# Publishing to the org's Facebook Page is an admin action — it was previously
# unauthenticated, letting anyone post with the stored Page token.
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])

class FacebookPostRequest(BaseModel):
    message: str
    image_url: Optional[str] = None
    link: Optional[str] = None

@router.post("/publish")
def publish_to_facebook(
    payload: FacebookPostRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Publish a text, link, or photo post to the connected Facebook Page.
    """
    # Scope to the caller's own organization (not Organization.first(), which
    # would leak the first tenant's Page token to any other tenant's admin).
    org = db.query(Organization).filter(
        Organization.id == current_user.organization_id
    ).first()
    if not org or not org.facebook_access_token:
        raise HTTPException(status_code=400, detail="Facebook Page Access Token not configured for this organization.")

    page_id = org.facebook_page_id
    if not page_id:
        # If page_id is not set, we can query /me to get it, assuming the token is a Page token
        try:
            me_res = requests.get(f"https://graph.facebook.com/v19.0/me?access_token={org.facebook_access_token}", timeout=15).json()
            if 'id' in me_res:
                page_id = me_res['id']
                org.facebook_page_id = page_id
                db.commit()
            else:
                raise ValueError("Could not resolve Page ID from token.")
        except Exception as e:
            logger.error(f"Failed to fetch Page ID: {e}")
            raise HTTPException(status_code=400, detail="Could not resolve Facebook Page ID. Make sure it's a valid Page token.")

    # Determine endpoint based on content
    if payload.image_url:
        url = f"https://graph.facebook.com/v19.0/{page_id}/photos"
        data = {
            "url": payload.image_url,
            "message": payload.message,
            "access_token": org.facebook_access_token
        }
    else:
        url = f"https://graph.facebook.com/v19.0/{page_id}/feed"
        data = {
            "message": payload.message,
            "access_token": org.facebook_access_token
        }
        if payload.link:
            data["link"] = payload.link

    res = requests.post(url, data=data, timeout=15)
    
    if res.status_code != 200:
        logger.error(f"Failed to post to Facebook: {res.text}")
        raise HTTPException(status_code=400, detail=f"Failed to post to Facebook: {res.text}")

    result = res.json()
    return {
        "status": "success",
        "post_id": result.get("id"),
        "message": "Successfully published to Facebook Page."
    }
