"""Google sign-in through the browser, for builds Google will not recognise.

The native plugin authenticates with the pair (package name, signing
certificate). Google re-signs anything uploaded to Play with its own key, so the
Play copy and the sideloaded copy present *different* certificates, and either
can be missing from the Firebase console while the other is fine. When it is
missing the plugin answers `DEVELOPER_ERROR` (code 10) and the member is simply
stuck: nothing in the app can fix a fingerprint that lives in a console.

This path does not involve the certificate at all. It is ordinary web OAuth
against the web client id, run in the system browser, which is the same thing
the club's website already does successfully.

Getting the answer back is the only interesting part. A custom URL scheme would
be one more per-build thing that can be wrong — exactly what we are escaping —
so instead the app keeps a secret handle: it starts the flow, opens the browser,
and polls. Google redirects to this backend, the backend finishes the exchange,
and the finished session waits in `pending_browser_logins` until the app
collects it, once.
"""
from __future__ import annotations

import json
import logging
import secrets
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.browser_login import PendingBrowserLogin

logger = logging.getLogger(__name__)

AUTHORIZE_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

# Long enough for a member to find their Google password, short enough that an
# abandoned handle is not a standing invitation.
SESSION_TTL = timedelta(minutes=10)


def redirect_uri() -> str:
    """The exact string Google must have on file for the web client."""
    if settings.GOOGLE_OAUTH_REDIRECT_URI:
        return settings.GOOGLE_OAUTH_REDIRECT_URI
    base = (settings.API_PUBLIC_BASE_URL or "").rstrip("/")
    return f"{base}/api/v1/auth/google/browser/callback"


def is_configured() -> bool:
    """Can this actually complete, or would the button be a trap?

    The app asks before offering the fallback, because a member who has already
    hit one failure should not be handed a second one.
    """
    return bool(settings.GOOGLE_WEB_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET
                and redirect_uri().startswith("http"))


def missing_configuration() -> list[str]:
    """Which settings are absent, named so an admin can act on the answer."""
    missing = []
    if not settings.GOOGLE_WEB_CLIENT_ID:
        missing.append("GOOGLE_WEB_CLIENT_ID")
    if not settings.GOOGLE_CLIENT_SECRET:
        missing.append("GOOGLE_CLIENT_SECRET")
    if not redirect_uri().startswith("http"):
        missing.append("GOOGLE_OAUTH_REDIRECT_URI or API_PUBLIC_BASE_URL")
    return missing


def _now() -> datetime:
    return datetime.now(timezone.utc)


def sweep(db: Session) -> int:
    """Delete handles nobody came back for. Cheap, and keeps the table small."""
    n = (db.query(PendingBrowserLogin)
           .filter(PendingBrowserLogin.expires_at < _now())
           .delete(synchronize_session=False))
    if n:
        db.commit()
    return n


def start(db: Session, organization_id) -> tuple[str, str]:
    """Open a session and return (session_id, authorization_url).

    The session id doubles as the OAuth `state`. That is what binds the callback
    Google sends to the app that asked for it: a callback carrying a state we
    never issued has nowhere to land.
    """
    sweep(db)
    session_id = secrets.token_urlsafe(32)[:64]
    db.add(PendingBrowserLogin(
        session_id=session_id,
        organization_id=organization_id,
        status="pending",
        expires_at=_now() + SESSION_TTL,
    ))
    db.commit()

    params = {
        "client_id": settings.GOOGLE_WEB_CLIENT_ID,
        "redirect_uri": redirect_uri(),
        "response_type": "code",
        "scope": "openid email profile",
        "state": session_id,
        # Ask every time. A member reaching for this fallback is usually
        # switching accounts or recovering from a failure, and a silent
        # auto-pick of the wrong Google account looks like another bug.
        "prompt": "select_account",
    }
    return session_id, f"{AUTHORIZE_ENDPOINT}?{urlencode(params)}"


def load(db: Session, session_id: str) -> PendingBrowserLogin | None:
    """The session behind this handle, if it exists and has not expired."""
    row = (db.query(PendingBrowserLogin)
             .filter(PendingBrowserLogin.session_id == session_id)
             .first())
    if row is None:
        return None
    expires = row.expires_at
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires is not None and expires < _now():
        db.delete(row)
        db.commit()
        return None
    return row


async def exchange_code_for_id_token(code: str) -> str:
    """Trade the one-time code for an ID token.

    Raises ValueError with a sentence worth showing, because this is the step
    that fails when the redirect URI in the console does not match ours
    character for character — a mistake that is invisible until it happens.
    """
    data = {
        "code": code,
        "client_id": settings.GOOGLE_WEB_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "redirect_uri": redirect_uri(),
        "grant_type": "authorization_code",
    }
    async with httpx.AsyncClient() as client:
        r = await client.post(TOKEN_ENDPOINT, data=data, timeout=12.0)
    if r.status_code != 200:
        detail = ""
        try:
            body = r.json()
            detail = body.get("error_description") or body.get("error") or ""
        except Exception:
            detail = r.text[:160]
        logger.warning("[google-browser] token exchange failed: %s", detail)
        raise ValueError(f"Google refused the sign-in ({detail or r.status_code}).")

    id_tok = r.json().get("id_token")
    if not id_tok:
        raise ValueError("Google returned no identity for this account.")
    return id_tok


def finish(db: Session, row: PendingBrowserLogin, result: dict) -> None:
    """Park the finished answer for the app to collect."""
    row.status = "ready"
    row.result_json = json.dumps(result)
    db.commit()


def fail(db: Session, row: PendingBrowserLogin, message: str) -> None:
    row.status = "failed"
    row.error = message[:300]
    db.commit()


def claim(db: Session, row: PendingBrowserLogin) -> dict | None:
    """Hand the answer over exactly once, then delete the handle.

    Single use is the point: the handle is the only credential guarding a
    finished session, so it stops being useful the moment it is spent.
    """
    if row.status != "ready" or not row.result_json:
        return None
    try:
        result = json.loads(row.result_json)
    except Exception:
        result = None
    db.delete(row)
    db.commit()
    return result
