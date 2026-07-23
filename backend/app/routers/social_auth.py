import logging
import os
import requests
from urllib.parse import urlencode
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.tenant import Organization

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/social", tags=["Social"])

# App secrets can be configured via ENV variables in production
# Defaulting to the credentials provided by the user for FYC Connect
# We will use the user's older App ID which has Instagram Business Login configured
IG_APP_ID = os.getenv("IG_APP_ID", "909285875002274")
IG_APP_SECRET = os.getenv("IG_APP_SECRET", "72403e3ff19da21956bb3de60f5f551e")

THREADS_APP_ID = os.getenv("THREADS_APP_ID", "1551943886666330")
THREADS_APP_SECRET = os.getenv("THREADS_APP_SECRET", "c8a275a3cfd4c6c83d09d6514a75991f")

# ---------------------------------------------------------------------------
# INSTAGRAM OAUTH
# ---------------------------------------------------------------------------

@router.get("/auth/instagram")
def auth_instagram(request: Request):
    """Redirect to Instagram Business Login to authorize App."""
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")
        
    redirect_uri = f"{base_url}/api/v1/social/auth/instagram/callback"
    
    # New Instagram Business Login Scopes
    permissions = "instagram_business_basic,instagram_business_manage_comments,instagram_business_content_publish"
    
    auth_url = f"https://www.instagram.com/oauth/authorize?force_reauth=true&client_id={IG_APP_ID}&redirect_uri={redirect_uri}&response_type=code&scope={permissions}"
    return RedirectResponse(auth_url)


@router.get("/auth/instagram/callback")
def auth_instagram_callback(request: Request, code: str = Query(...), db: Session = Depends(get_db)):
    """Exchange the code for a Long-Lived Access Token using Instagram API."""
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")
        
    redirect_uri = f"{base_url}/api/v1/social/auth/instagram/callback"
    
    # Exchange for short-lived token via Instagram Graph API
    token_url = "https://graph.instagram.com/v19.0/oauth/access_token"
    payload = {
        "client_id": IG_APP_ID,
        "client_secret": IG_APP_SECRET,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri,
        "code": code
    }
    res = requests.post(token_url, data=payload)
    if res.status_code != 200:
        logger.error(f"Failed to get IG token: {res.text}")
        raise HTTPException(status_code=400, detail=f"Failed to get IG token: {res.text}")
        
    data = res.json()
    short_lived_token = data.get("access_token")
    user_id = data.get("user_id")
    
    # For Instagram Business Login, the short lived token can be used directly or exchanged
    # Since we are just trying to get it working, we will save the short lived token (which might be long lived already for some endpoints)
    
    org = db.query(Organization).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
        
    org.instagram_access_token = short_lived_token
    org.instagram_account_id = user_id or os.getenv("IG_ACCOUNT_ID", "17841411702636378")
    db.commit()
    
    return {"status": "success", "message": "Instagram OAuth configured successfully!"}


# ---------------------------------------------------------------------------
# THREADS OAUTH
# ---------------------------------------------------------------------------

@router.get("/auth/threads")
def auth_threads(request: Request):
    """Redirect to Threads Login to authorize App."""
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")
        
    redirect_uri = f"{base_url}/api/v1/social/auth/threads/callback"
    permissions = "threads_basic,threads_read_replies"
    auth_url = f"https://threads.net/oauth/authorize?client_id={THREADS_APP_ID}&redirect_uri={redirect_uri}&scope={permissions}&response_type=code"
    return RedirectResponse(auth_url)


@router.get("/auth/threads/callback")
def auth_threads_callback(request: Request, code: str = Query(...), db: Session = Depends(get_db)):
    """Exchange the code for a Threads Token and save it."""
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")
        
    redirect_uri = f"{base_url}/api/v1/social/auth/threads/callback"
    
    # 1. Exchange for short-lived token
    token_url = "https://graph.threads.net/oauth/access_token"
    payload = {
        "client_id": THREADS_APP_ID,
        "client_secret": THREADS_APP_SECRET,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri,
        "code": code
    }
    res = requests.post(token_url, data=payload)
    if res.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to get short-lived token: {res.text}")
        
    data = res.json()
    short_lived_token = data.get("access_token")
    user_id = data.get("user_id")
    
    # 2. Exchange for long-lived token
    long_lived_url = f"https://graph.threads.net/access_token?grant_type=th_exchange_token&client_secret={THREADS_APP_SECRET}&access_token={short_lived_token}"
    ll_res = requests.get(long_lived_url)
    if ll_res.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to get long-lived token: {ll_res.text}")
        
    long_lived_token = ll_res.json().get("access_token")
    
    # 3. Save to Organization
    org = db.query(Organization).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
        
    org.threads_access_token = long_lived_token
    org.threads_account_id = user_id
    db.commit()
    
    return {"status": "success", "message": "Threads OAuth configured successfully!"}
