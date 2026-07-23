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
IG_APP_ID = os.getenv("IG_APP_ID", "1797067354995679")
IG_APP_SECRET = os.getenv("IG_APP_SECRET", "140500a7cf07d2091c17e9b97e2a65c7")

THREADS_APP_ID = os.getenv("THREADS_APP_ID", "1797067354995679")
THREADS_APP_SECRET = os.getenv("THREADS_APP_SECRET", "140500a7cf07d2091c17e9b97e2a65c7")

# ---------------------------------------------------------------------------
# INSTAGRAM OAUTH
# ---------------------------------------------------------------------------

@router.get("/auth/instagram")
def auth_instagram(request: Request):
    """Redirect to Facebook Login to authorize Instagram App."""
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")
        
    redirect_uri = f"{base_url}/api/v1/social/auth/instagram/callback"
    
    # We request pages permissions to fetch the Instagram Business Account
    permissions = "instagram_basic,instagram_manage_comments,pages_show_list,pages_read_engagement"
    
    auth_url = f"https://www.facebook.com/v19.0/dialog/oauth?client_id={IG_APP_ID}&redirect_uri={redirect_uri}&scope={permissions}"
    return RedirectResponse(auth_url)


@router.get("/auth/instagram/callback")
def auth_instagram_callback(request: Request, code: str = Query(...), db: Session = Depends(get_db)):
    """Exchange the code for a Long-Lived Access Token and save it."""
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")
        
    redirect_uri = f"{base_url}/api/v1/social/auth/instagram/callback"
    
    # 1. Exchange for short-lived token
    token_url = "https://graph.facebook.com/v19.0/oauth/access_token"
    params = {
        "client_id": IG_APP_ID,
        "redirect_uri": redirect_uri,
        "client_secret": IG_APP_SECRET,
        "code": code
    }
    res = requests.get(token_url, params=params)
    if res.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to get short-lived token: {res.text}")
        
    short_lived_token = res.json().get("access_token")
    
    # 2. Exchange for long-lived token
    long_lived_url = "https://graph.facebook.com/v19.0/oauth/access_token"
    ll_params = {
        "grant_type": "fb_exchange_token",
        "client_id": IG_APP_ID,
        "client_secret": IG_APP_SECRET,
        "fb_exchange_token": short_lived_token
    }
    res = requests.get(long_lived_url, params=ll_params)
    if res.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to get long-lived token: {res.text}")
        
    long_lived_token = res.json().get("access_token")
    
    # 3. Retrieve the Instagram Account ID by querying pages
    accounts_url = f"https://graph.facebook.com/v19.0/me/accounts?access_token={long_lived_token}"
    acc_res = requests.get(accounts_url).json()
    
    instagram_account_id = None
    if 'data' in acc_res:
        for page in acc_res['data']:
            page_id = page['id']
            page_token = page['access_token']
            ig_res = requests.get(f"https://graph.facebook.com/v19.0/{page_id}?fields=instagram_business_account&access_token={page_token}").json()
            if 'instagram_business_account' in ig_res:
                instagram_account_id = ig_res['instagram_business_account']['id']
                break
                
    if not instagram_account_id:
        # Fallback to the known FYC Connect Instagram Account ID
        instagram_account_id = os.getenv("IG_ACCOUNT_ID", "17841411702636378")
        logger.warning(f"Auto-discovery failed. Falling back to default Instagram Account ID: {instagram_account_id}")
    
    # 4. Save to Organization (assuming single tenant setup for now, or fetch default org)
    org = db.query(Organization).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
        
    org.instagram_access_token = long_lived_token
    org.instagram_account_id = instagram_account_id
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
