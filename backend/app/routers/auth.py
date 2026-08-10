import hashlib
import hmac
import secrets
import uuid
from typing import Union
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
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
from app.schemas.auth import OTPRequest, OTPResponse, OTPVerify, OTPVerifySuccess, Token, UserRegister, UserOut, AdminLogin, GoogleLoginRequest, RefreshRequest, AccessTokenResponse, _build_user_out

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


def _generate_otp() -> str:
    """Return a fixed bypass code in test/dev, or a random 6-digit code otherwise."""
    if settings.OTP_BYPASS_CODE:
        return settings.OTP_BYPASS_CODE
    # secrets, not random: Mersenne Twister output is reconstructible from
    # observed values, and an attacker can observe codes sent to numbers they
    # control.
    return f"{secrets.randbelow(1_000_000):06d}"


@router.post("/otp/send", response_model=OTPResponse)
@limiter.limit("5/minute")
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
@limiter.limit("10/minute")
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
    """
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

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
                idinfo = id_token.verify_oauth2_token(
                    payload.id_token, requests.Request(), cid
                )
                break
            except ValueError as e:
                last_err = e
        if idinfo is None:
            raise last_err
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid Google token: {e}")
        
    email = idinfo.get("email")
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google account has no email")

    google_sub = idinfo.get("sub")
    name = idinfo.get("name", "")
    given_name = idinfo.get("given_name", name)

    user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        User.email == email,
    ).first()

    if not user and google_sub:
        user = db.query(User).filter(
            User.organization_id == payload.organization_id,
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
            organization_id=payload.organization_id,
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
