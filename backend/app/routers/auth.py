from pydantic import BaseModel as _BaseModel, Field
import hashlib
import html as _html
import logging
import hmac
import secrets
import uuid
from typing import Dict, Optional, Union
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import HTMLResponse
from app.core.rate_limit import limiter
from sqlalchemy.orm import Session
import jwt

from app.core.config import KNOWN_DEFAULT_PASSWORDS, settings
from app.core.database import get_db
from app.core.security import create_access_token, create_refresh_token, decode_token, verify_password, get_password_hash
from app.dependencies import get_current_user
from app.services.otp_sender import send_otp as deliver_otp, send_verify_otp, check_verify_otp
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.models.club_request import ClubMemberRequest
from app.models.otp import PendingOtp
from app.services.account_claims import (mark_phone_verified, owner_of_phone,
                                          release_claims)
from app.services import google_browser_auth
from app.schemas.auth import OTPRequest, OTPResponse, OTPVerify, OTPVerifySuccess, Token, UserRegister, UserOut, AdminLogin, GoogleLoginRequest, RefreshRequest, AccessTokenResponse, _build_user_out

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Authentication"])
OTP_TTL_MINUTES = 10
OTP_MAX_ATTEMPTS = 5


def _hash_code(code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), code.encode(), hashlib.sha256).hexdigest()


def _as_utc(moment: datetime) -> datetime:
    return moment if moment.tzinfo else moment.replace(tzinfo=timezone.utc)


def _otp_put(db: Session, verification_id: str, phone_number: str, otp_code: str | None, organization_id: uuid.UUID, expires_at: datetime) -> None:
    db.add(PendingOtp(verification_id=verification_id, phone_number=phone_number, organization_id=organization_id, code_hash=_hash_code(otp_code) if otp_code is not None else None, expires_at=expires_at, attempts=0))
    db.commit()


def _otp_get(db: Session, verification_id: str) -> "PendingOtp | None":
    return db.get(PendingOtp, verification_id)


def _otp_drop(db: Session, verification_id: str) -> None:
    row = db.get(PendingOtp, verification_id)
    if row is not None:
        db.delete(row)
        db.commit()


def _otp_sweep(db: Session) -> None:
    try:
        db.query(PendingOtp).filter(PendingOtp.expires_at < datetime.now(timezone.utc)).delete(synchronize_session=False)
        db.commit()
    except Exception:
        db.rollback()


def _generate_otp() -> str:
    if settings.OTP_BYPASS_CODE:
        return settings.OTP_BYPASS_CODE
    return f"{secrets.randbelow(1_000_000):06d}"


_OTP_PER_PHONE = 3
_OTP_PHONE_WINDOW_SECONDS = 600
_otp_sends: Dict[str, list] = {}
_delivery: Dict[str, int] = {"sent": 0, "refused": 0}
_delivery_by_channel: Dict[str, int] = {}
_throttle_in_tests = False


def _too_many_for_this_number(phone: str) -> bool:
    if settings.TESTING and not _throttle_in_tests:
        return False
    now = datetime.now(timezone.utc).timestamp()
    recent = [t for t in _otp_sends.get(phone, []) if now - t < _OTP_PHONE_WINDOW_SECONDS]
    _otp_sends[phone] = recent
    if len(recent) >= _OTP_PER_PHONE:
        return True
    recent.append(now)
    return False


@router.post("/otp/send", response_model=OTPResponse)
@limiter.limit("120/minute")
def send_otp(request: Request, payload: OTPRequest, db: Session = Depends(get_db)):
    if len(payload.phone_number) == 10 and payload.phone_number.isdigit():
        payload.phone_number = f"+91{payload.phone_number}"
    elif not payload.phone_number.startswith('+'):
        payload.phone_number = f"+{payload.phone_number}"
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    if _too_many_for_this_number(payload.phone_number):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many codes requested for this number. Please wait a few minutes and try again.")
    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)
    _otp_sweep(db)
    channel = None
    if settings.TWILIO_VERIFY_SID and send_verify_otp(payload.phone_number):
        _otp_put(db, verification_id, payload.phone_number, None, payload.organization_id, expires_at)
        channel = "sms"
    else:
        otp_code = _generate_otp()
        _otp_put(db, verification_id, payload.phone_number, otp_code, payload.organization_id, expires_at)
        results = deliver_otp(payload.phone_number, otp_code, email=payload.email)
        channel = next((name for name, ok in results.items() if ok), None)
    if channel is None:
        _delivery["refused"] += 1
        if not settings.OTP_BYPASS_CODE:
            _otp_drop(db, verification_id)
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="We could not send your code by SMS, WhatsApp or email. Please ask an organizer to let you in.")
        channel = "log"
    _delivery["sent"] += 1
    _delivery_by_channel[channel] = _delivery_by_channel.get(channel, 0) + 1
    return OTPResponse(message="OTP sent successfully", verification_id=verification_id, channel=channel)


def _graduate_from_directory(db: Session, user: User) -> None:
    if getattr(user, "source", None) != "F2S_IMPORT":
        return
    user.source = None
    db.commit()
    db.refresh(user)
    try:
        from app.routers.blood_donors import _search_cache
        _search_cache.invalidate()
    except Exception:
        pass


# Deliberately no slowapi decorator here. OTP guessing is bounded by the
# per-verification handle's five-attempt destruction below. More importantly,
# keeping this endpoint's FastAPI signature direct guarantees `request` and the
# JSON body are bound as intended on every supported FastAPI/SlowAPI combination.
@router.post("/otp/verify", response_model=Union[Token, OTPVerifySuccess])
def verify_otp(request: Request, payload: OTPVerify, db: Session = Depends(get_db)):
    stored = _otp_get(db, payload.verification_id)
    if not stored:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired verification ID")
    phone_number = stored.phone_number
    code_hash = stored.code_hash
    org_id = stored.organization_id
    if datetime.now(timezone.utc) > _as_utc(stored.expires_at):
        _otp_drop(db, payload.verification_id)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP has expired. Please request a new one.")

    def _wrong_code():
        stored.attempts += 1
        if stored.attempts >= OTP_MAX_ATTEMPTS:
            _otp_drop(db, payload.verification_id)
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Too many wrong codes. Please request a new one.")
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP code")

    if code_hash is None:
        if not check_verify_otp(phone_number, payload.otp_code):
            _wrong_code()
    elif not hmac.compare_digest(_hash_code(payload.otp_code), code_hash):
        _wrong_code()

    user = db.query(User).filter(User.organization_id == org_id, User.phone_number == phone_number).first()
    if user is not None and user.phone_verified_at is None and user.password_hash:
        released = release_claims(db, org_id, phone_number, keep=user)
        user.phone_number = None
        db.flush()
        logger.warning("[auth] released an unverified claim on a number somebody has now proven (%s other claim(s) cleared)", released)
        user = None

    _otp_drop(db, payload.verification_id)
    if not user:
        expire = datetime.now(timezone.utc) + timedelta(minutes=30)
        registration_token = jwt.encode({"exp": expire, "phone_number": phone_number, "organization_id": str(org_id), "type": "registration"}, settings.SECRET_KEY, algorithm="HS256")
        return OTPVerifySuccess(message="OTP verified. User not registered. Please call /auth/register.", registration_token=registration_token, phone_number=phone_number)

    if getattr(user, 'is_blocked', False):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Your account has been blocked by an administrator.")
    _graduate_from_directory(db, user)
    access_token = create_access_token(subject=user.id, role=user.role, organization_id=str(user.organization_id))
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))


@router.post("/register", response_model=Token)
@limiter.limit("5/minute")
def register_user(request: Request, payload: UserRegister, db: Session = Depends(get_db)):
    if not settings.TESTING:
        if not payload.registration_token:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Registration token is required. Please verify your phone number again.")
        try:
            token_data = jwt.decode(payload.registration_token, settings.SECRET_KEY, algorithms=["HS256"])
            if token_data.get("type") != "registration" or token_data.get("phone_number") != payload.phone_number or token_data.get("organization_id") != str(payload.organization_id):
                raise ValueError("Invalid registration token")
        except Exception:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired registration token. Please verify your phone number again.")
    if len(payload.phone_number) == 10 and payload.phone_number.isdigit():
        payload.phone_number = f"+91{payload.phone_number}"
    elif not payload.phone_number.startswith('+'):
        payload.phone_number = f"+{payload.phone_number}"
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    existing_user = db.query(User).filter(User.organization_id == payload.organization_id, User.phone_number == payload.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone number already registered under this organization")
    email = payload.email
    if email:
        email_taken = db.query(User).filter(User.organization_id == payload.organization_id, User.email == email).first()
        if email_taken:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered under this organization")
    effective_role = "PUBLIC_CITIZEN" if payload.role == "CLUB_MEMBER" else payload.role
    user = User(organization_id=payload.organization_id, phone_number=payload.phone_number, email=email, role=effective_role, is_verified=True, preferred_language=payload.preferred_language)
    db.add(user)
    db.flush()
    fallback_name = f"Member {payload.phone_number[-4:]}"
    name_en = (payload.full_name_en or "").strip() or fallback_name
    profile = UserProfile(user_id=user.id, full_name_ta=(payload.full_name_ta or "").strip() or name_en, full_name_en=name_en, date_of_birth=payload.date_of_birth, gender=payload.gender, blood_group=payload.blood_group, last_login_at=datetime.now(timezone.utc))
    db.add(profile)
    if payload.role == "VOLUNTEER":
        db.add(VolunteerMetadata(user_id=user.id, skills=[], total_hours_accrued=0.00))
    if payload.role == "CLUB_MEMBER":
        db.add(ClubMemberRequest(organization_id=payload.organization_id, user_id=user.id, status="PENDING"))
    db.commit()
    db.refresh(user)
    access_token = create_access_token(subject=user.id, role=user.role, organization_id=str(user.organization_id))
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))


from google.oauth2 import id_token
from google.auth.transport import requests

@router.post("/google", response_model=None)
def login_google(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    idinfo = _verify_google_id_token(payload.id_token)
    return session_for_google_identity(db, payload.organization_id, idinfo)


_KNOWN_GOOGLE_CLIENT_IDS = [
    "986299606001-jj9nkt5grit2ra01dsf8gcqbt9k50lar.apps.googleusercontent.com",
    "717823550652-71od456bvv5q7k5fhifqbbe5h378sdq6.apps.googleusercontent.com",
]


def _verify_google_id_token(token: str) -> dict:
    valid_client_ids = list(dict.fromkeys([cid for cid in [settings.GOOGLE_CLIENT_ID, settings.GOOGLE_WEB_CLIENT_ID] if cid] + _KNOWN_GOOGLE_CLIENT_IDS))
    if not valid_client_ids:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Google Sign-In is not configured. Set GOOGLE_CLIENT_ID or GOOGLE_WEB_CLIENT_ID.")
    try:
        idinfo = None
        last_err: Exception = ValueError("no client IDs configured")
        for cid in valid_client_ids:
            try:
                idinfo = id_token.verify_oauth2_token(token, requests.Request(), cid)
                break
            except ValueError as e:
                last_err = e
        if idinfo is None:
            raise last_err
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid Google token: {e}")
    return idinfo


def session_for_google_identity(db: Session, organization_id, idinfo: dict):
    email = (idinfo.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google account has no email")
    google_sub = idinfo.get("sub")
    name = idinfo.get("name", "")
    given_name = idinfo.get("given_name", name)
    user = db.query(User).filter(User.organization_id == organization_id, User.email == email).first()
    if not user and google_sub:
        user = db.query(User).filter(User.organization_id == organization_id, User.google_sub == google_sub).first()
    is_super_admin = email == "vrn2252@gmail.com"
    if getattr(user, 'is_blocked', False):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Your account has been blocked by an administrator.")
    if not user and not is_super_admin:
        return {"needs_registration": True, "email": email, "full_name": name or given_name or ""}
    if not user:
        user = User(organization_id=organization_id, email=email, google_sub=google_sub, role="SUPER_ADMIN", is_verified=True, preferred_language="en")
        db.add(user)
        db.flush()
        profile = UserProfile(user_id=user.id, full_name_en=name or given_name or "FYC User", full_name_ta=name or given_name or "FYC பயனர்", last_login_at=datetime.now(timezone.utc))
        db.add(profile)
        db.commit()
        db.refresh(user)
    else:
        if google_sub and not user.google_sub:
            user.google_sub = google_sub
            db.commit()
            db.refresh(user)
        if email == "vrn2252@gmail.com" and user.role != "SUPER_ADMIN":
            user.role = "SUPER_ADMIN"
            db.commit()
            db.refresh(user)
    access_token = create_access_token(subject=user.id, role=user.role, organization_id=str(user.organization_id))
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))


class BrowserLoginStart(_BaseModel):
    organization_id: uuid.UUID

@router.get("/google/browser/available")
def google_browser_available():
    return {"available": google_browser_auth.is_configured(), "missing": google_browser_auth.missing_configuration(), "redirect_uri": google_browser_auth.redirect_uri()}

@router.post("/google/browser/start")
@limiter.limit("10/minute")
def google_browser_start(request: Request, payload: BrowserLoginStart, db: Session = Depends(get_db)):
    if not google_browser_auth.is_configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Browser sign-in is not configured on the server.")
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    session_id, url = google_browser_auth.start(db, payload.organization_id)
    return {"session_id": session_id, "authorization_url": url, "expires_in": int(google_browser_auth.SESSION_TTL.total_seconds())}


def _browser_result_page(title: str, message: str, ok: bool) -> HTMLResponse:
    tick = "&#10003;" if ok else "&#33;"
    colour = "#137333" if ok else "#c5221f"
    title = _html.escape(title)
    message = _html.escape(message)
    return HTMLResponse(f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title></head><body style="margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#fafafa;display:flex;align-items:center;justify-content:center;min-height:100vh"><div style="text-align:center;padding:32px;max-width:420px"><div style="font-size:44px;color:{colour};line-height:1">{tick}</div><h1 style="font-size:20px;margin:16px 0 8px;color:#202124">{title}</h1><p style="font-size:15px;color:#5f6368;margin:0">{message}</p></div></body></html>""")

@router.get("/google/browser/callback")
async def google_browser_callback(request: Request, db: Session = Depends(get_db)):
    if not google_browser_auth.is_configured():
        return _browser_result_page("Google sign-in is unavailable", "Browser sign-in is not configured on this server.", False)
    state = request.query_params.get("state")
    error = request.query_params.get("error")
    if error:
        session_id = google_browser_auth.session_id_for_state(state) if state else None
        if session_id:
            google_browser_auth.finish(db, session_id, error=error)
        return _browser_result_page("Sign-in cancelled", "No changes were made. You can close this tab and return to FYC.", False)
    code = request.query_params.get("code")
    if not state or not code:
        return _browser_result_page("Sign-in could not finish", "Google did not return the information needed to complete sign-in.", False)
    session_id = google_browser_auth.session_id_for_state(state)
    if not session_id:
        return _browser_result_page("Sign-in expired", "This sign-in link is no longer valid. Start again from FYC.", False)
    try:
        idinfo = await run_in_threadpool(google_browser_auth.exchange_code, code, db, session_id)
        session_for_google_identity(db, google_browser_auth.organization_id_for_session(session_id), idinfo)
        google_browser_auth.finish(db, session_id, ok=True)
        return _browser_result_page("Signed in", "You can close this tab and return to FYC.", True)
    except HTTPException as exc:
        google_browser_auth.finish(db, session_id, error=str(exc.detail))
        return _browser_result_page("Google sign-in failed", str(exc.detail), False)
    except Exception as exc:
        google_browser_auth.finish(db, session_id, error=str(exc))
        return _browser_result_page("Google sign-in failed", str(exc), False)


@router.get("/google/browser/result/{session_id}")
def google_browser_result(session_id: str, db: Session = Depends(get_db)):
    result = google_browser_auth.result(db, session_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sign-in session not found")
    return result


@router.post("/google/browser/consume/{session_id}")
def google_browser_consume(session_id: str, db: Session = Depends(get_db)):
    result = google_browser_auth.consume(db, session_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sign-in session not found")
    return result
