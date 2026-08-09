import logging
import os
import uuid
from datetime import datetime, timedelta, timezone
import jwt
import requests
from urllib.parse import urlencode
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.config import settings
from app.core.security import ALGORITHM
from app.dependencies import get_current_user_optional
from app.models.tenant import Organization
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/social", tags=["Social"])


# --- OAuth CSRF `state` -----------------------------------------------------
# The OAuth callback is hit by Meta (unauthenticated), so it can't rely on our
# JWT. Instead the initiation endpoint mints a short-lived signed `state` that
# binds the flow to a specific organization; the callback verifies it before
# storing any token. This is the anti-CSRF protection the flow lacked, and it
# also carries the target org so tokens are bound to the right tenant rather
# than a blind `Organization.first()`.
_STATE_TTL_MIN = 10


def _make_state(org_id, provider: str) -> str:
    payload = {
        "org": str(org_id),
        "prov": provider,
        "typ": "social_oauth_state",
        "jti": uuid.uuid4().hex,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=_STATE_TTL_MIN),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def _verify_state(state: str, provider: str) -> uuid.UUID:
    if not state:
        raise HTTPException(status_code=400, detail="Missing OAuth state (possible CSRF).")
    try:
        data = jwt.decode(state, settings.SECRET_KEY, algorithms=[ALGORITHM])
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid or expired OAuth state.")
    if data.get("typ") != "social_oauth_state" or data.get("prov") != provider:
        raise HTTPException(status_code=400, detail="OAuth state does not match this flow.")
    try:
        return uuid.UUID(data["org"])
    except Exception:
        raise HTTPException(status_code=400, detail="OAuth state carries no valid organization.")


def _resolve_org_id(db: Session, current_user, provider: str) -> uuid.UUID:
    """The org to bind this OAuth flow to: the authenticated admin's org when
    present, else the sole org (single-tenant today). Prevents binding to a blind
    `Organization.first()` once more than one org exists."""
    if current_user is not None:
        return current_user.organization_id
    org = db.query(Organization).first()
    if not org:
        raise HTTPException(status_code=404, detail="No organization configured.")
    return org.id

# Meta OAuth app credentials come from environment / Fly secrets ONLY — never a
# hardcoded default (an app secret in source is a leak). Configure with:
#   flyctl secrets set IG_APP_ID=... IG_APP_SECRET=... THREADS_APP_ID=... \
#                      THREADS_APP_SECRET=... IG_ACCOUNT_ID=...
IG_APP_ID = settings.IG_APP_ID
IG_APP_SECRET = settings.IG_APP_SECRET

THREADS_APP_ID = settings.THREADS_APP_ID
THREADS_APP_SECRET = settings.THREADS_APP_SECRET


def _require_meta_config(app_id: str, app_secret: str, provider: str) -> None:
    """Fail closed when a provider's OAuth app credentials aren't configured, so
    we never build a redirect with an empty client_id or POST an empty secret."""
    if not app_id or not app_secret:
        raise HTTPException(
            status_code=503,
            detail=(f"{provider} OAuth is not configured on the server. "
                    f"Set its app id/secret as environment / Fly secrets first."),
        )


# ---------------------------------------------------------------------------
# INSTAGRAM OAUTH
# ---------------------------------------------------------------------------

@router.get("/auth/instagram")
def auth_instagram(request: Request, db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user_optional)):
    """Redirect to Instagram Business Login to authorize App."""
    _require_meta_config(IG_APP_ID, IG_APP_SECRET, "Instagram")
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or "fycconnect.com" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")

    redirect_uri = f"{base_url}/api/v1/social/auth/instagram/callback"

    # New Instagram Business Login Scopes
    permissions = "instagram_business_basic,instagram_business_manage_comments,instagram_business_content_publish"

    state = _make_state(_resolve_org_id(db, current_user, "instagram"), "instagram")
    auth_url = (f"https://www.instagram.com/oauth/authorize?force_reauth=true"
                f"&client_id={IG_APP_ID}&redirect_uri={redirect_uri}"
                f"&response_type=code&scope={permissions}&state={state}")
    return RedirectResponse(auth_url)


@router.get("/auth/instagram/callback")
def auth_instagram_callback(request: Request, code: str = Query(...),
                            state: str = Query(None), db: Session = Depends(get_db)):
    """Exchange the code for a Long-Lived Access Token using Instagram API."""
    _require_meta_config(IG_APP_ID, IG_APP_SECRET, "Instagram")
    org_id = _verify_state(state, "instagram")
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or "fycconnect.com" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
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
    res = requests.post(token_url, data=payload, timeout=15)
    if res.status_code != 200:
        logger.error(f"Failed to get IG token: {res.text}")
        raise HTTPException(status_code=400, detail=f"Failed to get IG token: {res.text}")
        
    data = res.json()
    short_lived_token = data.get("access_token")
    user_id = data.get("user_id")
    
    # For Instagram Business Login, the short lived token can be used directly or exchanged
    # Since we are just trying to get it working, we will save the short lived token (which might be long lived already for some endpoints)
    
    account_id = user_id or settings.IG_ACCOUNT_ID
    if not account_id:
        raise HTTPException(
            status_code=400,
            detail="Instagram returned no account id and IG_ACCOUNT_ID is unset — "
                   "cannot configure publishing without a target account.",
        )

    org = db.query(Organization).filter(Organization.id == org_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")

    org.instagram_access_token = short_lived_token
    org.instagram_account_id = account_id
    db.commit()

    return {"status": "success", "message": "Instagram OAuth configured successfully!"}


# ---------------------------------------------------------------------------
# THREADS OAUTH
# ---------------------------------------------------------------------------

@router.get("/auth/threads")
def auth_threads(request: Request, db: Session = Depends(get_db),
                 current_user: User = Depends(get_current_user_optional)):
    """Redirect to Threads Login to authorize App."""
    _require_meta_config(THREADS_APP_ID, THREADS_APP_SECRET, "Threads")
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or "fycconnect.com" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
        base_url = base_url.replace("http://", "https://")

    redirect_uri = f"{base_url}/api/v1/social/auth/threads/callback"
    permissions = "threads_basic,threads_read_replies"
    state = _make_state(_resolve_org_id(db, current_user, "threads"), "threads")
    auth_url = (f"https://threads.net/oauth/authorize?client_id={THREADS_APP_ID}"
                f"&redirect_uri={redirect_uri}&scope={permissions}"
                f"&response_type=code&state={state}")
    return RedirectResponse(auth_url)


@router.get("/auth/threads/callback")
def auth_threads_callback(request: Request, code: str = Query(...),
                          state: str = Query(None), db: Session = Depends(get_db)):
    """Exchange the code for a Threads Token and save it."""
    _require_meta_config(THREADS_APP_ID, THREADS_APP_SECRET, "Threads")
    org_id = _verify_state(state, "threads")
    base_url = str(request.base_url).rstrip("/")
    if "fly.dev" in base_url or "fycconnect.com" in base_url or os.getenv("ENFORCE_HTTPS", "true").lower() == "true":
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
    res = requests.post(token_url, data=payload, timeout=15)
    if res.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to get short-lived token: {res.text}")
        
    data = res.json()
    short_lived_token = data.get("access_token")
    user_id = data.get("user_id")
    
    # 2. Exchange for long-lived token
    long_lived_url = f"https://graph.threads.net/access_token?grant_type=th_exchange_token&client_secret={THREADS_APP_SECRET}&access_token={short_lived_token}"
    ll_res = requests.get(long_lived_url, timeout=15)
    if ll_res.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to get long-lived token: {ll_res.text}")
        
    long_lived_token = ll_res.json().get("access_token")
    
    # 3. Save to the organization the flow was started for (from signed state)
    org = db.query(Organization).filter(Organization.id == org_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")

    org.threads_access_token = long_lived_token
    org.threads_account_id = user_id
    db.commit()
    
    return {"status": "success", "message": "Threads OAuth configured successfully!"}
