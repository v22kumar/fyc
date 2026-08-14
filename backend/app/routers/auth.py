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
from app.dependencies import get_current_user
from app.models.tenant import Organization
from app.models.user import User, UserProfile, VolunteerMetadata
from app.models.club_request import ClubMemberRequest
from app.models.otp import PendingOtp
from app.services.account_claims import (mark_phone_verified, owner_of_phone,
                                          release_claims)
from app.services import google_browser_auth, firebase_phone_auth
from app.schemas.auth import (
    OTPRequest, OTPResponse, OTPVerify, OTPVerifySuccess, Token, UserRegister,
    UserOut, AdminLogin, GoogleLoginRequest, RefreshRequest, AccessTokenResponse,
    PhoneClaimRequest, PhoneClaimResponse, PhoneClaimVerifyRequest,
    FirebasePhoneVerifyRequest, _build_user_out,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Authentication"])

OTP_TTL_MINUTES = 10

# A 6-digit code has a million possibilities and a 10-minute lifetime. The two
# defences that make that safe are here: the code comes from a CSPRNG, and a
# verification_id dies after a handful of wrong guesses instead of surviving
# the whole TTL as a stable target to grind against.
OTP_MAX_ATTEMPTS = 5


# ── Where a half-finished sign-in lives ──────────────────────────────────────
#
# This was a module-level dict. On one machine with one worker that looks
# correct, and it is — until the process restarts. A deploy, a crash, an OOM
# kill, a host migration: any of them empties the dict, and every member
# holding an SMS they have not typed yet is told "Invalid or expired
# verification ID".
#
# That message is the damaging part. It is indistinguishable from mistyping the
# code, so nobody reports a server fault: they assume they fumbled it, ask for
# another code, and hit the same wall. Across a run of frequent deploys it
# reads exactly like "login has been down for days and we don't know why".
#
# A row costs one insert and one delete per sign-in, outlives every restart,
# and lets a second instance answer /otp/verify if this ever grows past one
# machine. See app/models/otp.py.


def _hash_code(code: str) -> str:
    """HMAC the code under the app secret — the code itself is never stored.

    A six-digit code is trivially brute-forced from a plain hash, so this is
    keyed rather than bare SHA-256: without SECRET_KEY a leaked table is inert
    for the ten minutes the row exists.
    """
    return hmac.new(
        settings.SECRET_KEY.encode(), code.encode(), hashlib.sha256
    ).hexdigest()


def _as_utc(moment: datetime) -> datetime:
    """SQLite hands back naive datetimes; Postgres hands back aware ones.

    Comparing the two raises TypeError, which would turn every verification on
    SQLite into a 500. Stored values are always UTC, so an absent tzinfo simply
    means "nobody wrote it down".
    """
    return moment if moment.tzinfo else moment.replace(tzinfo=timezone.utc)


def _otp_put(db: Session, verification_id: str, phone_number: str,
             otp_code: str | None, organization_id: uuid.UUID,
             expires_at: datetime) -> None:
    db.add(PendingOtp(
        verification_id=verification_id,
        phone_number=phone_number,
        organization_id=organization_id,
        code_hash=_hash_code(otp_code) if otp_code is not None else None,
        expires_at=expires_at,
        attempts=0,
    ))
    db.commit()


def _otp_get(db: Session, verification_id: str) -> "PendingOtp | None":
    return db.get(PendingOtp, verification_id)


def _otp_drop(db: Session, verification_id: str) -> None:
    row = db.get(PendingOtp, verification_id)
    if row is not None:
        db.delete(row)
        db.commit()


def _otp_sweep(db: Session) -> None:
    """Delete rows nobody can use any more.

    Best-effort housekeeping on the send path: a member who never types the
    code leaves a row behind, and without this the table only grows. A failure
    here must never stop somebody signing in, so it is swallowed.
    """
    try:
        db.query(PendingOtp).filter(
            PendingOtp.expires_at < datetime.now(timezone.utc)
        ).delete(synchronize_session=False)
        db.commit()
    except Exception:
        db.rollback()


def delivery_report() -> dict:
    """How many codes actually went out, and how many nobody could carry.

    Counts only — never a number, never a code. `refused` climbing while `sent`
    stays flat is one specific thing: the SMS provider is rejecting numbers it
    has not been told about, which is what a trial plan does.
    """
    return {
        "sent": _delivery["sent"],
        "refused": _delivery["refused"],
        "by_channel": dict(_delivery_by_channel),
    }


def _generate_otp() -> str:
    """Return a fixed bypass code in test/dev, or a random 6-digit code otherwise."""
    if settings.OTP_BYPASS_CODE:
        return settings.OTP_BYPASS_CODE
    # secrets, not random: Mersenne Twister output is reconstructible from
    # observed values, and an attacker can observe codes sent to numbers they
    # control.
    return f"{secrets.randbelow(1_000_000):06d}"



# One phone, a few codes. One hall, sixty phones.
#
# The per-IP limit on /otp/send was 5/minute, and slowapi keys on the caller's
# address. At a venue every player is behind the same NAT, so sixty people
# signing in on the hall's wifi are one bucket: five get a code each minute and
# the rest get 429s that look, from a phone, exactly like the app being broken.
# A registration desk would take a quarter of an hour to get through the room,
# and nobody would understand why.
#
# The limit belongs on the *number*, which is what a code is actually sent to
# and what an abuser would have to cycle. The IP limit stays as a backstop
# against a script, set high enough that a crowded hall never reaches it.
_OTP_PER_PHONE = 3
_OTP_PHONE_WINDOW_SECONDS = 600
_otp_sends: Dict[str, list] = {}

# Delivery outcomes, so "nobody can sign in" is answerable without a log.
#
# A code that never arrives is invisible from the server's side: the request
# succeeded, the member simply never got a message. On a trial SMS account
# every number except the ones verified in the provider's console is refused —
# which looks exactly like "it works for me and not for them", and is
# catastrophic the morning sixty players try at once.
_delivery: Dict[str, int] = {"sent": 0, "refused": 0}
_delivery_by_channel: Dict[str, int] = {}

# Flipped on by the throttle's own tests, which need the real behaviour.
_throttle_in_tests = False


def _too_many_for_this_number(phone: str) -> bool:
    # Off under test for the same reason the IP limiter is: the store is
    # process-global, so one test's retries would otherwise refuse another
    # test's first attempt. The throttle has its own tests, which clear it.
    if settings.TESTING and not _throttle_in_tests:
        return False
    now = datetime.now(timezone.utc).timestamp()
    recent = [t for t in _otp_sends.get(phone, [])
              if now - t < _OTP_PHONE_WINDOW_SECONDS]
    _otp_sends[phone] = recent
    if len(recent) >= _OTP_PER_PHONE:
        return True
    recent.append(now)
    return False


@router.post("/otp/send", response_model=OTPResponse)
# Generous on purpose: sixty players on one hall wifi share this bucket. The
# real guard is per-number, below.
@limiter.limit("120/minute")
def send_otp(request: Request, payload: OTPRequest, db: Session = Depends(get_db)):
    """
    Initiate authentication by sending a 6-digit OTP to the phone number.
    Rate-limited to 5 requests per minute per IP.
    """
    # Ensure phone number is E.164 formatted (default to +91 for India)
    if len(payload.phone_number) == 10 and payload.phone_number.isdigit():
        payload.phone_number = f"+91{payload.phone_number}"
    elif not payload.phone_number.startswith('+'):
        payload.phone_number = f"+{payload.phone_number}"

    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    if _too_many_for_this_number(payload.phone_number):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many codes requested for this number. "
                   "Please wait a few minutes and try again.",
        )

    verification_id = f"v_{uuid.uuid4().hex[:12]}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)

    # Codes nobody came back for. Cheap, and it keeps the table the size of
    # "sign-ins in progress" rather than "sign-ins ever started".
    _otp_sweep(db)

    # A ladder, not a single rung.
    #
    # This used to be an if/else: with TWILIO_VERIFY_SID configured, a failed
    # send raised 502 and stopped. The WhatsApp and email senders sitting in
    # otp_sender.py were only reachable when Verify was *not configured at all*
    # — so on the one day Twilio has an outage, a trial balance runs out, or a
    # number is unverified, every single member is locked out of the app and the
    # fallbacks that exist for exactly that moment are unreachable code.
    #
    # Now each channel is tried in turn until one accepts the message. Which one
    # carried it is reported back, because "check WhatsApp" and "check your
    # messages" send a member to different places, and being told the wrong one
    # looks identical to nothing arriving.
    channel = None

    if settings.TWILIO_VERIFY_SID and send_verify_otp(payload.phone_number):
        # Twilio Verify manages the code itself; we only remember phone + org.
        _otp_put(db, verification_id, payload.phone_number, None,
                 payload.organization_id, expires_at)
        channel = "sms"
    else:
        # Every remaining channel needs a code we generated ourselves.
        otp_code = _generate_otp()
        _otp_put(db, verification_id, payload.phone_number, otp_code,
                 payload.organization_id, expires_at)
        results = deliver_otp(payload.phone_number, otp_code, email=payload.email)
        channel = next((name for name, ok in results.items() if ok), None)

    if channel is None:
        _delivery["refused"] += 1
        logger.warning(
            "[otp] every channel refused this number — check the SMS provider "
            "is not on a trial plan that only allows verified numbers")
        # Nothing carried it. A bypass code means this is dev or staging, where
        # a log line is the delivery channel.
        if not settings.OTP_BYPASS_CODE:
            _otp_drop(db, verification_id)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="We could not send your code by SMS, WhatsApp or email. "
                       "Please ask an organizer to let you in.",
            )
        channel = "log"

    _delivery["sent"] += 1
    _delivery_by_channel[channel] = _delivery_by_channel.get(channel, 0) + 1
    return OTPResponse(
        message="OTP sent successfully",
        verification_id=verification_id,
        channel=channel,
    )


def _graduate_from_directory(db: Session, user: User) -> None:
    """A Friends2Support contact who signs in has just joined FYC.

    The directory is a list of phone numbers the club collected from a public
    source. When one of those people downloads the app and proves the number is
    theirs, they stop being a cold call and become a member — reachable in the
    app, notifiable, and on the map if they choose to share a location.

    Leaving the marker on would file them as a stranger forever: out of the club
    list, absent from the nearby ranking, and offered to anyone in an emergency
    to ring out of the blue — which is the exact thing a separate directory
    exists to avoid.

    Only the import marker is cleared. No role change and no privilege granted:
    PUBLIC_CITIZEN is already what an ordinary registration produces.
    """
    if getattr(user, "source", None) != "F2S_IMPORT":
        return
    user.source = None
    db.commit()
    db.refresh(user)
    # They have just moved between two cached lists. Without this the directory
    # keeps offering them as a stranger to call for the rest of the cache
    # window, which is the one moment it must not.
    try:
        from app.routers.blood_donors import _search_cache
        _search_cache.invalidate()
    except Exception:
        pass


@router.post("/otp/verify", response_model=Union[Token, OTPVerifySuccess])
# Also per-IP, and also shared by a whole hall. Guessing is already bounded by
# OTP_MAX_ATTEMPTS, which destroys the handle after five wrong codes — that is
# the limit that matters, and it is per sign-in rather than per building.
@limiter.limit("120/minute")
def verify_otp(request: Request, payload: OTPVerify, db: Session = Depends(get_db)):
    """
    Verify OTP. Returns JWT on success; or OTPVerifySuccess with a registration_token if user not yet registered.
    """
    stored = _otp_get(db, payload.verification_id)
    if not stored:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification ID",
        )

    phone_number = stored.phone_number
    code_hash = stored.code_hash
    org_id = stored.organization_id

    if datetime.now(timezone.utc) > _as_utc(stored.expires_at):
        _otp_drop(db, payload.verification_id)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired. Please request a new one.",
        )

    def _wrong_code():
        # Every wrong guess burns one of a small number of attempts; when they
        # run out the verification_id itself is destroyed, so a fresh /otp/send
        # (itself rate-limited, with a fresh random code) is the only way on.
        stored.attempts += 1
        if stored.attempts >= OTP_MAX_ATTEMPTS:
            _otp_drop(db, payload.verification_id)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many wrong codes. Please request a new one.",
            )
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP code")

    if code_hash is None:
        # Twilio Verify flow — delegate check to Twilio
        if not check_verify_otp(phone_number, payload.otp_code):
            _wrong_code()
    # compare_digest, not `!=`: the comparison runs against attacker-supplied
    # input, and both sides are fixed-length hex here.
    elif not hmac.compare_digest(_hash_code(payload.otp_code), code_hash):
        _wrong_code()

    user = db.query(User).filter(
        User.organization_id == org_id,
        User.phone_number == phone_number,
    ).first()

    # Answering a code on a number is proof of owning it. Holding a row that
    # merely *contains* the number is not.
    #
    # Password sign-up lets somebody type any number they like, so a row can
    # hold a number nobody proved. Logging this person into that row would hand
    # the account of whoever typed it to whoever owns the phone — or, read the
    # other way, let anyone claim a number and inherit the member who later
    # verifies it. Account takeover needing nothing but a keyboard.
    #
    # So an unproven claim is released here and the code-answerer continues as
    # a new member. The claimant keeps their account, their password and their
    # name; they lose only a number that was never theirs, and can still sign
    # in by email.
    if user is not None and user.phone_verified_at is None and user.password_hash:
        released = release_claims(db, org_id, phone_number, keep=user)
        user.phone_number = None
        db.flush()
        logger.warning(
            "[auth] released an unverified claim on a number somebody has now "
            "proven (%s other claim(s) cleared)", released)
        user = None

    # Single use: the code has done its job, and the handle dies with it.
    _otp_drop(db, payload.verification_id)

    if not user:
        # Generate a temporary token proving this phone number was verified
        expire = datetime.now(timezone.utc) + timedelta(minutes=30)
        to_encode = {
            "exp": expire,
            "phone_number": phone_number,
            "organization_id": str(org_id),
            "type": "registration"
        }
        registration_token = jwt.encode(to_encode, settings.SECRET_KEY, algorithm="HS256")
        
        return OTPVerifySuccess(
            message="OTP verified. User not registered. Please call /auth/register.",
            registration_token=registration_token,
            phone_number=phone_number
        )

    if getattr(user, 'is_blocked', False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been blocked by an administrator.",
        )

    # Signing in is how a directory contact becomes a member.
    _graduate_from_directory(db, user)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))


@router.post("/register", response_model=Token)
@limiter.limit("5/minute")
def register_user(request: Request, payload: UserRegister, db: Session = Depends(get_db)):
    """Register a new Citizen or Volunteer after OTP verification."""
    
    # 1. Validate the registration_token to ensure the phone number was verified.
    #    Skipped only under settings.TESTING (conftest sets TESTING=true) — the same
    #    pattern as the OTP bypass and rate-limit disable. Production ALWAYS requires
    #    and validates the token.
    if not settings.TESTING:
        if not payload.registration_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Registration token is required. Please verify your phone number again.",
            )
        try:
            token_data = jwt.decode(payload.registration_token, settings.SECRET_KEY, algorithms=["HS256"])
            if token_data.get("type") != "registration":
                raise ValueError("Invalid token type")

            # Verify the phone number matches the token payload
            token_phone = token_data.get("phone_number")
            if token_phone != payload.phone_number:
                raise ValueError("Phone number mismatch")

            # Verify the org matches
            if token_data.get("organization_id") != str(payload.organization_id):
                raise ValueError("Organization mismatch")

        except Exception:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired registration token. Please verify your phone number again.",
            )

    # Ensure phone number is E.164 formatted (default to +91 for India)
    if len(payload.phone_number) == 10 and payload.phone_number.isdigit():
        payload.phone_number = f"+91{payload.phone_number}"
    elif not payload.phone_number.startswith('+'):
        payload.phone_number = f"+{payload.phone_number}"

    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    existing_user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        User.phone_number == payload.phone_number,
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered under this organization",
        )

    # Email is OPTIONAL now. When one IS supplied, reject a duplicate within this
    # org so two members can't claim the same contact email (app-level guard —
    # not a DB unique constraint, since legacy rows have NULL/duplicate emails).
    email = payload.email  # normalised (trimmed + lowercased) or None
    if email:
        email_taken = db.query(User).filter(
            User.organization_id == payload.organization_id,
            User.email == email,
        ).first()
        if email_taken:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered under this organization",
            )

    # CLUB_MEMBER registrations are held in a PENDING approval queue.
    # The user account is created with PUBLIC_CITIZEN so they can use
    # the app immediately; an admin must approve before the role upgrades.
    effective_role = "PUBLIC_CITIZEN" if payload.role == "CLUB_MEMBER" else payload.role

    user = User(
        organization_id=payload.organization_id,
        phone_number=payload.phone_number,
        email=email,
        role=effective_role,
        is_verified=True,
        preferred_language=payload.preferred_language,
    )
    db.add(user)
    db.flush()

    # A name is the one thing worth asking for at the door — it is what makes
    # the app usable at all, on a profile, in the directory, on a blood request.
    # Everything else (date of birth, gender, blood group, area) is asked later,
    # one question at a time. When even the name is missing, fall back to
    # something neutral and unique rather than inventing a person: the columns
    # are NOT NULL, and a blank row would break the directory instead of
    # signalling anything.
    fallback_name = f"Member {payload.phone_number[-4:]}"
    name_en = (payload.full_name_en or "").strip() or fallback_name

    profile = UserProfile(
        user_id=user.id,
        # Single-name UX: the client sends one name; store it to both the English
        # and Tamil columns when only one is provided, so display works either way.
        full_name_ta=(payload.full_name_ta or "").strip() or name_en,
        full_name_en=name_en,
        date_of_birth=payload.date_of_birth,
        gender=payload.gender,
        blood_group=payload.blood_group,
        last_login_at=datetime.now(timezone.utc),
    )
    db.add(profile)

    if payload.role == "VOLUNTEER":
        db.add(VolunteerMetadata(user_id=user.id, skills=[], total_hours_accrued=0.00))

    if payload.role == "CLUB_MEMBER":
        db.add(ClubMemberRequest(
            organization_id=payload.organization_id,
            user_id=user.id,
            status="PENDING",
        ))

    db.commit()
    db.refresh(user)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))


from google.oauth2 import id_token
from google.auth.transport import requests

@router.post("/google", response_model=None)
def login_google(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    """Google Sign-In for the mobile app.

    Returns a normal auth Token for an existing member. For a brand-new Google
    account it does NOT silently create a half-empty user — it returns
    `{needs_registration: true, email, full_name}` so the app can send them
    through registration to supply the now-mandatory phone number and date of
    birth (name/email pre-filled from Google). Their account links to this
    Google identity on the next sign-in, matched by email.

    Supports both ID Token (modern devices like Pixel 6a) and Access Token
    (older devices like Oppo A3s / Android 8.1 with older Play Services).
    """
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    idinfo = None
    if payload.id_token:
        try:
            idinfo = _verify_google_id_token(payload.id_token)
        except HTTPException as e:
            if payload.access_token:
                idinfo = _verify_google_access_token(payload.access_token)
            else:
                raise e
    elif payload.access_token:
        idinfo = _verify_google_access_token(payload.access_token)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either id_token or access_token must be provided",
        )

    return session_for_google_identity(db, payload.organization_id, idinfo)


# Accepted token audiences = configured client IDs + known first-party client
# IDs. The Android app (Firebase project 986299606001 / fyc-connect-25ab0) mints
# tokens with its own web client ID, while the website uses the 717823550652
# web client; both are legitimate. OAuth client IDs are not secrets (they ship
# inside the APK and google-services.json), so listing them here is safe and
# avoids "Token has wrong audience" rejections from env drift.
_KNOWN_GOOGLE_CLIENT_IDS = [
    "986299606001-jj9nkt5grit2ra01dsf8gcqbt9k50lar.apps.googleusercontent.com",  # Android (fyc-connect-25ab0)
    "717823550652-71od456bvv5q7k5fhifqbbe5h378sdq6.apps.googleusercontent.com",  # Web
]


def _verify_google_id_token(token: str) -> dict:
    """Check an ID token against every client id this club legitimately uses.

    Both roads in — the native plugin and the browser fallback — arrive with an
    ID token minted by a different client, so the audience is not knowable in
    advance. Trying each accepted one in turn is what keeps a config change on
    one road from silently invalidating the other.
    """
    valid_client_ids = list(dict.fromkeys(
        [cid for cid in [settings.GOOGLE_CLIENT_ID, settings.GOOGLE_WEB_CLIENT_ID] if cid]
        + _KNOWN_GOOGLE_CLIENT_IDS
    ))
    if not valid_client_ids:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Sign-In is not configured. Set GOOGLE_CLIENT_ID or GOOGLE_WEB_CLIENT_ID.",
        )

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


def _verify_google_access_token(access_token: str) -> dict:
    """Verify a Google OAuth2 access token via Google userinfo API.

    This fallback path ensures wide Android compatibility for older devices
    (e.g., Oppo A3s, Android 8.1 Oreo, older Google Play Services) where
    OpenID Connect idToken generation may be unavailable or unminted.
    """
    import urllib.request
    import json
    url = "https://www.googleapis.com/oauth2/v3/userinfo"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "User-Agent": "FYC-Connect-Backend",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if not data.get("email"):
                raise ValueError("Google account returned no email")
            return data
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google access token: {e}",
        )


def session_for_google_identity(db: Session, organization_id, idinfo: dict):
    """Turn a *verified* Google identity into a session for this club.

    Split out of `login_google` because the browser fallback reaches the same
    place by a different road: the native plugin hands us an ID token directly,
    the browser flow trades an authorization code for one. Only the road
    differs — who the member is, whether they already exist, and what happens
    when they do not, must not.
    """
    email = idinfo.get("email")
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google account has no email")

    google_sub = idinfo.get("sub")
    name = idinfo.get("name", "")
    given_name = idinfo.get("given_name", name)

    user = db.query(User).filter(
        User.organization_id == organization_id,
        User.email == email,
    ).first()

    if not user and google_sub:
        user = db.query(User).filter(
            User.organization_id == organization_id,
            User.google_sub == google_sub,
        ).first()

    is_super_admin = email == "vrn2252@gmail.com"

    if getattr(user, 'is_blocked', False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been blocked by an administrator.",
        )

    # New member (and not the owner bootstrap account): route them into
    # registration to collect the mandatory phone + date of birth rather than
    # creating an incomplete account. Name/email are pre-filled from Google.
    if not user and not is_super_admin:
        return {
            "needs_registration": True,
            "email": email,
            "full_name": name or given_name or "",
        }

    # Owner bootstrap only — auto-create so the super admin is never locked out.
    if not user:
        user = User(
            organization_id=organization_id,
            email=email,
            google_sub=google_sub,
            role="SUPER_ADMIN",
            is_verified=True,
            preferred_language="en",
        )
        db.add(user)
        db.flush()

        profile = UserProfile(
            user_id=user.id,
            full_name_en=name or given_name or "FYC User",
            full_name_ta=name or given_name or "FYC பயனர்",
            last_login_at=datetime.now(timezone.utc),
        )
        db.add(profile)
        db.commit()
        db.refresh(user)
    else:
        # Link google_sub if not present
        if google_sub and not user.google_sub:
            user.google_sub = google_sub
            db.commit()
            db.refresh(user)

        # If the user is vrn2252@gmail.com, upgrade them to SUPER_ADMIN to ensure they have access.
        if email == "vrn2252@gmail.com" and user.role != "SUPER_ADMIN":
            user.role = "SUPER_ADMIN"
            db.commit()
            db.refresh(user)

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))



# ── Google sign-in that does not depend on how this build was signed ────────
#
# The native plugin shows Google the pair (package name, signing certificate).
# Play re-signs uploaded bundles with its own key, so the Play copy and the
# sideloaded copy present different certificates and can fail independently —
# and when Google does not recognise one, it answers DEVELOPER_ERROR (code 10)
# and the member is stuck behind a fingerprint that lives in a console.
#
# These three endpoints are the way round it. Ordinary web OAuth, in the system
# browser, against the web client id: no certificate anywhere in it.

class BrowserLoginStart(_BaseModel):
    organization_id: uuid.UUID


@router.get("/google/browser/available")
def google_browser_available():
    """Should the app offer this at all?

    A member who has just been refused once should not be handed a second
    failure, so the app asks before showing the button.
    """
    return {
        "available": google_browser_auth.is_configured(),
        "missing": google_browser_auth.missing_configuration(),
        "redirect_uri": google_browser_auth.redirect_uri(),
    }


@router.post("/google/browser/start")
@limiter.limit("10/minute")
def google_browser_start(request: Request, payload: BrowserLoginStart,
                         db: Session = Depends(get_db)):
    """Open a browser sign-in and hand the app a handle to watch it by."""
    if not google_browser_auth.is_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Browser sign-in is not configured on the server.",
        )
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    session_id, url = google_browser_auth.start(db, payload.organization_id)
    return {
        "session_id": session_id,
        "authorization_url": url,
        "expires_in": int(google_browser_auth.SESSION_TTL.total_seconds()),
    }


def _browser_result_page(title: str, message: str, ok: bool) -> HTMLResponse:
    """What the member sees in the browser when Google sends them back.

    They still have the app open behind this tab, so the page's only job is to
    say which way it went and get out of the way.
    """
    tick = "&#10003;" if ok else "&#33;"
    colour = "#137333" if ok else "#c5221f"
    # `message` carries Google's error_description, or the first 160 characters
    # of whatever Google's token endpoint returned. Interpolating that into a
    # page served from the API origin, unescaped, is a hole somebody else fills.
    title = _html.escape(title)
    message = _html.escape(message)
    return HTMLResponse(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title></head>
<body style="margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
background:#fafafa;display:flex;align-items:center;justify-content:center;min-height:100vh">
<div style="text-align:center;padding:32px;max-width:420px">
  <div style="font-size:44px;color:{colour};line-height:1">{tick}</div>
  <h1 style="font-size:20px;margin:16px 0 8px;color:#202124">{title}</h1>
  <p style="font-size:15px;color:#5f6368;margin:0">{message}</p>
</div></body></html>""")


@router.get("/google/browser/callback")
async def google_browser_callback(request: Request, db: Session = Depends(get_db)):
    """Where Google returns the member. Finishes the exchange, parks the result.

    Nothing sensitive reaches this page: the session lands in the database and
    only the app, which holds the handle, can collect it.
    """
    params = request.query_params
    state = params.get("state") or ""
    row = google_browser_auth.load(db, state) if state else None
    # Only a session still waiting for Google may be written to. A second
    # callback carrying the same state would otherwise replace a finished
    # result with a different identity, which the app would then collect.
    if row is None or row.status != "pending":
        return _browser_result_page(
            "This sign-in has expired",
            "Go back to FYC Connect and start again.", ok=False)

    if params.get("error"):
        google_browser_auth.fail(db, row, f"Google reported: {params.get('error')}")
        return _browser_result_page(
            "Sign-in cancelled",
            "Nothing was changed. You can close this tab.", ok=False)

    code = params.get("code")
    if not code:
        google_browser_auth.fail(db, row, "Google returned no authorization code.")
        return _browser_result_page(
            "Sign-in did not complete",
            "Go back to FYC Connect and try again.", ok=False)

    try:
        id_tok = await google_browser_auth.exchange_code_for_id_token(code)
    except Exception as e:
        google_browser_auth.fail(db, row, str(e))
        return _browser_result_page(
            "Sign-in did not complete", str(e), ok=False)

    try:
        idinfo = await run_in_threadpool(_verify_google_id_token, id_tok)
        result = await run_in_threadpool(
            session_for_google_identity, db, row.organization_id, idinfo)
    except HTTPException as e:
        google_browser_auth.fail(db, row, str(e.detail))
        return _browser_result_page("Sign-in did not complete", str(e.detail), ok=False)
    except Exception as e:
        logger.exception("[google-browser] callback failed")
        google_browser_auth.fail(db, row, "Something went wrong finishing sign-in.")
        return _browser_result_page(
            "Sign-in did not complete",
            "Something went wrong. Go back to FYC Connect and try again.", ok=False)

    payload = result if isinstance(result, dict) else result.model_dump(mode="json")
    google_browser_auth.finish(db, row, payload)
    return _browser_result_page(
        "You're signed in",
        "Return to FYC Connect — it is already picking this up.", ok=True)


@router.get("/google/browser/result")
@limiter.limit("120/minute")
def google_browser_result(request: Request, session_id: str,
                          db: Session = Depends(get_db)):
    """The app polls this. Answers once, then the handle is spent."""
    row = google_browser_auth.load(db, session_id)
    if row is None:
        return {"status": "expired"}
    if row.status == "failed":
        error = row.error or "Sign-in did not complete."
        db.delete(row)
        db.commit()
        return {"status": "failed", "error": error}
    if row.status != "ready":
        return {"status": "pending"}

    result = google_browser_auth.claim(db, row)
    if result is None:
        return {"status": "failed", "error": "Sign-in did not complete."}
    return {"status": "ready", "result": result}


@router.post("/login/password", response_model=Token)
@limiter.limit("5/minute")
def login_password(request: Request, payload: AdminLogin, db: Session = Depends(get_db)):
    """Password login for Administrators, Executives, and Club Members."""
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

    user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        ((User.email == payload.username) | (User.phone_number == payload.username)),
    ).first()

    if not user or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid username or password")

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid username or password")

    # A password published in this repository is not a password.
    #
    # The seeded superadmin is created with FIRST_SUPERADMIN_PASSWORD on the
    # *first* boot only, so on a database that already has an organisation the
    # account keeps its original hash and setting the secret afterwards changes
    # nothing. The default is a literal in app/core/config.py, and this app is
    # public — so `admin@fycconnect.org` plus a string anyone can read was a
    # working SUPER_ADMIN login: every member's phone number, every child's
    # event registration, broadcast to the whole club, delete anything.
    #
    # Refused here rather than only at boot, because a check that runs at boot
    # protects nothing on a machine that is already running, and because this
    # holds whatever ENVIRONMENT is set to.
    if payload.password.strip().lower() in KNOWN_DEFAULT_PASSWORDS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account still uses a default password and cannot be "
                   "used until it is changed. Set FIRST_SUPERADMIN_PASSWORD "
                   "and restart to rotate it.",
        )
        
    if getattr(user, 'is_blocked', False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been blocked by an administrator.",
        )

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    return Token(access_token=access_token, refresh_token=create_refresh_token(user.id, user.token_version), token_type="bearer", user=_build_user_out(user, profile))


@router.post("/refresh", response_model=AccessTokenResponse)
@limiter.limit("30/minute")
def refresh_access_token(request: Request, payload: RefreshRequest, db: Session = Depends(get_db)):
    """Exchange a valid refresh token for a fresh access token. The app calls
    this silently when an access token expires, so the user stays signed in
    until they explicitly log out (or the refresh token itself expires)."""
    try:
        data = decode_token(payload.refresh_token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")
    if data.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not a refresh token")

    user = db.query(User).filter(User.id == data.get("sub")).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User no longer exists")

    # Revocation check: a refresh token is only valid while its `tv` claim
    # matches the user's current token_version. Logout / password-reset bump
    # token_version, instantly invalidating every outstanding refresh token.
    # Tokens minted before this feature carry no `tv` → treated as 0, which
    # matches the default so existing sessions are grandfathered in.
    if int(data.get("tv", 0)) != int(user.token_version or 0):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token has been revoked")

    access_token = create_access_token(
        subject=user.id,
        role=user.role,
        organization_id=str(user.organization_id),
    )
    return AccessTokenResponse(access_token=access_token)


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Log out everywhere: bump the user's token_version so every outstanding
    refresh token is immediately revoked (they can no longer mint access
    tokens). The client should also discard its stored tokens."""
    current_user.token_version = int(current_user.token_version or 0) + 1
    db.commit()
    return {"status": "ok", "message": "Logged out on all devices."}



@router.get("/users/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return the currently authenticated user with profile.

    The profile load is defended: `db.query(UserProfile)` selects every mapped
    column, so a column that exists in the model but not yet in the live DB
    (deploy lands before the migration boots) turns THIS request — the one the
    app makes on every open to learn whose it is — into a 500, and the home
    screen shows "?" where the name goes. Rather than take the whole app down
    over schema drift, fall back to a targeted read of only the columns the
    response actually needs, which cannot reference an un-migrated column.
    """
    try:
        profile = db.query(UserProfile).filter(
            UserProfile.user_id == current_user.id).first()
        return _build_user_out(current_user, profile)
    except Exception:
        # The failed ORM query poisons this request's session; read the name
        # through a FRESH session (targeted to only the stable columns, so it
        # cannot touch an un-migrated one) rather than rolling this one back.
        from sqlalchemy import text as _text
        from app.core.database import SessionLocal as _Fresh
        row = None
        try:
            with _Fresh() as _s:
                row = _s.execute(_text(
                    "SELECT full_name_en, full_name_ta, date_of_birth, "
                    "gender, blood_group FROM user_profiles "
                    "WHERE user_id = :uid"
                ), {"uid": str(current_user.id)}).first()
        except Exception:
            row = None

        class _P:  # a stand-in the builder reads attributes off
            full_name_en = row[0] if row else None
            full_name_ta = row[1] if row else None
            date_of_birth = row[2] if row else None
            gender = row[3] if row else None
            blood_group = row[4] if row else None
        return _build_user_out(current_user, _P() if row else None)


class PasswordSignup(_BaseModel):
    organization_id: uuid.UUID
    full_name: str = Field(min_length=2, max_length=120)
    phone_number: str = Field(min_length=10, max_length=15)
    # A plain string, checked lightly. Pydantic's EmailStr needs the
    # email-validator package, and adding a dependency two days before a code
    # freeze buys a stricter regex at the price of a new thing that can break
    # the build. The address is proven by sending mail to it, not by parsing.
    email: str = Field(min_length=5, max_length=120)
    password: str = Field(min_length=8, max_length=128)
    preferred_language: Optional[str] = "ta"


@router.post("/register/password", response_model=Token, status_code=201)
@limiter.limit("20/minute")
def register_with_password(request: Request, payload: PasswordSignup,
                           db: Session = Depends(get_db)):
    """Join with a name, a number, an email and a password. Verify later.

    **Why this exists.** Signing in depended entirely on two outside services —
    an SMS gateway and Google. When either refuses, nobody can join, and the
    club has no way to let them in. This is a door the club owns end to end: no
    provider, no review queue, no trial-plan surprise on the morning of an
    event.

    **What it does not do is pretend.** The account is created immediately and
    the identifiers are recorded as *claims*: `phone_verified_at` and
    `email_verified_at` stay NULL until somebody answers a code. A member can
    read, browse and be greeted by name straight away. Anything that turns on
    who they really are waits for proof — see `require_verified_phone`.

    The number is not owned by typing it. If someone else later answers a code
    on it, the claim is released to them (see services/account_claims.py). That
    rule is what makes deferring verification safe rather than an invitation.
    """
    org = db.query(Organization).filter(
        Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Organization not found")

    phone = payload.phone_number.strip()
    if len(phone) == 10 and phone.isdigit():
        phone = f"+91{phone}"
    elif not phone.startswith("+"):
        phone = f"+{phone}"

    email = payload.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Please enter a valid email address.")

    if payload.password.strip().lower() in KNOWN_DEFAULT_PASSWORDS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please choose a password of your own.")

    # A number already proven by somebody is theirs. Say so plainly rather than
    # failing on a constraint — "that number is already a member" is something
    # a person can act on.
    if owner_of_phone(db, org.id, phone):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That number already belongs to a member. "
                   "Sign in with the code we send to it.")

    # A number merely claimed by somebody else blocks this sign-up, because the
    # database keeps one row per number. The way through is to prove it: a code
    # answered on that number releases the claim.
    if db.query(User).filter(User.organization_id == org.id,
                             User.phone_number == phone).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Someone has already registered that number. "
                   "If it is yours, sign in with the code we send to it.")

    if db.query(User).filter(
            User.organization_id == org.id,
            User.email == email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="That email is already registered.")

    user = User(
        organization_id=org.id,
        phone_number=phone,
        email=email,
        password_hash=get_password_hash(payload.password),
        role="PUBLIC_CITIZEN",
        # Deliberately false. Nothing has been proven yet, and the older
        # `is_verified` flag is what several screens still read.
        is_verified=False,
        preferred_language=payload.preferred_language or "ta",
    )
    db.add(user)
    db.flush()
    profile = UserProfile(user_id=user.id,
                          full_name_en=payload.full_name.strip(),
                          full_name_ta=payload.full_name.strip())
    db.add(profile)
    db.commit()
    db.refresh(user)

    access_token = create_access_token(subject=user.id, role=user.role,
                                       organization_id=str(user.organization_id))
    refresh_token = create_refresh_token(subject=user.id,
                                         token_version=user.token_version)
    return Token(access_token=access_token, refresh_token=refresh_token,
                 token_type="bearer",
                 user=_build_user_out(user, profile))


@router.post("/google/claim-phone", response_model=PhoneClaimResponse)
@router.post("/phone/claim", response_model=PhoneClaimResponse)
@limiter.limit("10/minute")
def claim_phone(
    request: Request,
    payload: PhoneClaimRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PhoneClaimResponse:
    """Attach a typed phone as an unverified claim to the current authenticated user.

    The phone is a claim, not ownership: if another verified user or password user
    already owns the number, return 200 with conflict=True and claimed=False without
    breaking or terminating the user's Google session.
    """
    phone = payload.phone_number.strip()
    if len(phone) == 10 and phone.isdigit():
        phone = f"+91{phone}"
    elif not phone.startswith("+"):
        phone = f"+{phone}"

    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="Enter a valid phone number")

    if current_user.phone_number == phone:
        return PhoneClaimResponse(
            claimed=True,
            phone_number=phone,
            phone_verified=current_user.phone_verified_at is not None,
        )

    if current_user.phone_number and current_user.phone_number != phone:
        return PhoneClaimResponse(
            claimed=False,
            phone_number=current_user.phone_number,
            phone_verified=current_user.phone_verified_at is not None,
            reason="Your account already has a phone number.",
        )

    existing = db.query(User).filter(
        User.organization_id == current_user.organization_id,
        User.phone_number == phone,
        User.id != current_user.id,
    ).first()

    if existing is not None and (existing.phone_verified_at is not None or existing.password_hash):
        return PhoneClaimResponse(
            claimed=False,
            conflict=True,
            reason="That phone number is already attached to another account.",
        )
    elif existing is not None:
        existing.phone_number = None
        db.flush()

    current_user.phone_number = phone
    current_user.phone_verified_at = None
    db.commit()
    db.refresh(current_user)

    otp_sent = False
    otp_channel = None
    verification_id = None
    try:
        verification_id = f"v_{uuid.uuid4().hex[:12]}"
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)
        if settings.TWILIO_VERIFY_SID and send_verify_otp(phone):
            _otp_put(db, verification_id, phone, None, current_user.organization_id, expires_at)
            otp_sent = True
            otp_channel = "sms"
        else:
            otp_code = _generate_otp()
            _otp_put(db, verification_id, phone, otp_code, current_user.organization_id, expires_at)
            results = deliver_otp(phone, otp_code, email=current_user.email)
            channel = next((name for name, ok in results.items() if ok), None)
            if channel:
                otp_sent = True
                otp_channel = channel
            else:
                _otp_drop(db, verification_id)
                verification_id = None
    except Exception:
        db.rollback()

    return PhoneClaimResponse(
        claimed=True,
        phone_number=phone,
        phone_verified=False,
        otp_sent=otp_sent,
        otp_channel=otp_channel,
        otp_verification_id=verification_id,
    )


@router.post("/google/claim-phone/verify", response_model=PhoneClaimResponse)
@router.post("/phone/verify", response_model=PhoneClaimResponse)
@limiter.limit("20/minute")
def verify_claim_phone(
    request: Request,
    payload: PhoneClaimVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PhoneClaimResponse:
    """Prove the claimed phone number with an OTP code."""
    stored = _otp_get(db, payload.verification_id)
    if not stored or stored.phone_number != current_user.phone_number or stored.organization_id != current_user.organization_id:
        raise HTTPException(status_code=400, detail="Invalid or expired phone verification")

    if datetime.now(timezone.utc) > _as_utc(stored.expires_at):
        _otp_drop(db, payload.verification_id)
        raise HTTPException(status_code=400, detail="Phone verification has expired. Request a new code.")

    def _wrong():
        stored.attempts += 1
        if stored.attempts >= OTP_MAX_ATTEMPTS:
            _otp_drop(db, payload.verification_id)
            raise HTTPException(status_code=400, detail="Too many wrong codes. Please request a new one.")
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid OTP code")

    if stored.code_hash is None:
        if not check_verify_otp(stored.phone_number, payload.otp_code):
            _wrong()
    elif not hmac.compare_digest(_hash_code(payload.otp_code), stored.code_hash):
        _wrong()

    _otp_drop(db, payload.verification_id)
    mark_phone_verified(db, current_user)
    db.commit()
    db.refresh(current_user)

    return PhoneClaimResponse(
        claimed=True,
        phone_number=current_user.phone_number,
        phone_verified=True,
    )


@router.post(
    "/firebase/verify-phone",
    response_model=PhoneClaimResponse,
    summary="Verify phone number cryptographically using Firebase Phone Auth ID token",
)
@limiter.limit("20/minute")
def verify_phone_firebase(
    request: Request,
    payload: FirebasePhoneVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Verify and link a phone number proved by Firebase Phone Number Verification.

    Bypasses SMS OTP gateway tables entirely; uses Google's cryptographic token
    to establish phone proof.
    """
    result = firebase_phone_auth.claim_and_verify_firebase_phone(
        db=db,
        current_user=current_user,
        id_token=payload.id_token,
    )
    return PhoneClaimResponse(**result)

