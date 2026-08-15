import uuid
from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User


def _org_with_admin(db, phone="+919888800001", password="pass"):
    org = Organization(id=uuid.uuid4(), slug=f"a-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Org")
    db.add(org)
    db.flush()
    u = User(organization_id=org.id, phone_number=phone,
             password_hash=get_password_hash(password), role="ADMIN", is_verified=True)
    db.add(u)
    db.commit()
    return org, u


def test_login_returns_refresh_token_and_refresh_mints_access(client, db):
    org, _ = _org_with_admin(db)
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org.id), "username": "+919888800001", "password": "pass"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["access_token"] and body["refresh_token"], "login must return both tokens"

    # Exchange the refresh token for a fresh access token.
    rr = client.post("/api/v1/auth/refresh", json={"refresh_token": body["refresh_token"]})
    assert rr.status_code == 200, rr.text
    assert rr.json()["access_token"]


def test_refresh_rejects_an_access_token(client, db):
    """An access token must not be usable at /refresh (type mismatch) — only a
    genuine refresh token works."""
    org, _ = _org_with_admin(db, phone="+919888800002")
    body = client.post("/api/v1/auth/login/password",
                       json={"organization_id": str(org.id), "username": "+919888800002", "password": "pass"}).json()
    bad = client.post("/api/v1/auth/refresh", json={"refresh_token": body["access_token"]})
    assert bad.status_code == 401

    junk = client.post("/api/v1/auth/refresh", json={"refresh_token": "not-a-jwt"})
    assert junk.status_code == 401


def test_logout_revokes_refresh_tokens(client, db):
    """After /auth/logout bumps token_version, the old refresh token can no
    longer mint access tokens (server-side revocation)."""
    org, _ = _org_with_admin(db, phone="+919888800009")
    body = client.post("/api/v1/auth/login/password",
                       json={"organization_id": str(org.id), "username": "+919888800009", "password": "pass"}).json()
    refresh = body["refresh_token"]

    # Works before logout.
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": refresh}).status_code == 200

    # Log out everywhere (authenticated with the access token).
    out = client.post("/api/v1/auth/logout", headers={
        "Authorization": f"Bearer {body['access_token']}",
        "X-Organization-ID": str(org.id),
    })
    assert out.status_code == 200, out.text

    # The same refresh token is now revoked.
    revoked = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
    assert revoked.status_code == 401


def test_refresh_token_cannot_access_protected_endpoint(client, db):
    """A refresh token must not authenticate a normal request — only /refresh."""
    org, _ = _org_with_admin(db, phone="+919888800003")
    body = client.post("/api/v1/auth/login/password",
                       json={"organization_id": str(org.id), "username": "+919888800003", "password": "pass"}).json()
    r = client.get("/api/v1/auth/users/me", headers={
        "Authorization": f"Bearer {body['refresh_token']}",
        "X-Organization-ID": str(org.id),
    })
    assert r.status_code == 401
    # The access token still works on the same endpoint.
    ok = client.get("/api/v1/auth/users/me", headers={
        "Authorization": f"Bearer {body['access_token']}",
        "X-Organization-ID": str(org.id),
    })
    assert ok.status_code == 200


def test_otp_send_invalid_organization(client):
    """Sending OTP to a non-existent organization must return 404."""
    random_uuid = str(uuid.uuid4())
    response = client.post(
        "/api/v1/auth/otp/send",
        json={"organization_id": random_uuid, "phone_number": "+919876543210"}
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Organization not found"

def test_otp_send_success(client, db):
    """Sending OTP to a valid organization must return 200 and verification_id."""
    org = Organization(
        id=uuid.uuid4(),
        slug="test-club",
        name_ta="தேர்வு கிளப்",
        name_en="Test Club"
    )
    db.add(org)
    db.commit()

    response = client.post(
        "/api/v1/auth/otp/send",
        json={"organization_id": str(org.id), "phone_number": "+919876543210"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "verification_id" in data
    assert data["message"] == "OTP sent successfully"

def test_otp_verify_invalid_code(client, db):
    """Verifying with a wrong OTP must return 400."""
    org = Organization(
        id=uuid.uuid4(),
        slug="test-club",
        name_ta="தேர்வு கிளப்",
        name_en="Test Club"
    )
    db.add(org)
    db.commit()

    # Request OTP
    send_response = client.post(
        "/api/v1/auth/otp/send",
        json={"organization_id": str(org.id), "phone_number": "+919876543210"}
    )
    v_id = send_response.json()["verification_id"]

    # Verify with incorrect code
    verify_response = client.post(
        "/api/v1/auth/otp/verify",
        json={"verification_id": v_id, "otp_code": "000000"}
    )
    assert verify_response.status_code == 400
    assert verify_response.json()["detail"] == "Invalid OTP code"

def test_otp_verify_unregistered_user(client, db):
    """Verifying correct OTP for a non-registered number must return 404 for registration."""
    org = Organization(
        id=uuid.uuid4(),
        slug="test-club",
        name_ta="தேர்வு கிளப்",
        name_en="Test Club"
    )
    db.add(org)
    db.commit()

    send_response = client.post(
        "/api/v1/auth/otp/send",
        json={"organization_id": str(org.id), "phone_number": "+919876543210"}
    )
    v_id = send_response.json()["verification_id"]

    # Verify with correct code
    verify_response = client.post(
        "/api/v1/auth/otp/verify",
        json={"verification_id": v_id, "otp_code": "123456"}
    )
    # Unregistered number → 200 with a registration_token (OTPVerifySuccess),
    # which the app exchanges at /auth/register. (Older builds returned 404.)
    assert verify_response.status_code == 200, verify_response.text
    data = verify_response.json()
    assert data.get("registration_token")
    assert data["phone_number"] == "+919876543210"

def test_registration_and_login_flow(client, db):
    """Test full registration and subsequent login via OTP flow."""
    org = Organization(
        id=uuid.uuid4(),
        slug="test-club",
        name_ta="தேர்வு கிளப்",
        name_en="Test Club"
    )
    db.add(org)
    db.commit()

    # Register
    reg_response = client.post(
        "/api/v1/auth/register",
        json={
            "organization_id": str(org.id),
            "phone_number": "+919876543210",
            "email": "Karthik@Example.com",
            "date_of_birth": "2000-05-15",
            "role": "VOLUNTEER",
            "full_name_ta": "கார்த்திக் ஜே",
            "full_name_en": "Karthik J"
        }
    )
    assert reg_response.status_code == 200
    reg_data = reg_response.json()
    assert "access_token" in reg_data
    assert reg_data["user"]["phone_number"] == "+919876543210"
    assert reg_data["user"]["role"] == "VOLUNTEER"
    # Email is stored normalised (trimmed + lowercased); DOB is captured.
    assert reg_data["user"]["email"] == "karthik@example.com"
    assert reg_data["user"]["date_of_birth"] == "2000-05-15"

    # Send OTP again for login
    send_response = client.post(
        "/api/v1/auth/otp/send",
        json={"organization_id": str(org.id), "phone_number": "+919876543210"}
    )
    v_id = send_response.json()["verification_id"]

    # Verify OTP for login
    login_response = client.post(
        "/api/v1/auth/otp/verify",
        json={"verification_id": v_id, "otp_code": "123456"}
    )
    assert login_response.status_code == 200
    login_data = login_response.json()
    assert "access_token" in login_data
    assert login_data["user"]["phone_number"] == "+919876543210"

def test_admin_password_login_success(client, db):
    """Test successful password login for administrators."""
    org = Organization(
        id=uuid.uuid4(),
        slug="test-club",
        name_ta="தேர்வு கிளப்",
        name_en="Test Club"
    )
    db.add(org)
    db.commit()

    hashed_pwd = get_password_hash("mysecretpassword")
    admin = User(
        organization_id=org.id,
        phone_number="+919876543211",
        email="admin@test.com",
        password_hash=hashed_pwd,
        role="ADMIN",
        is_verified=True
    )
    db.add(admin)
    db.commit()

    login_response = client.post(
        "/api/v1/auth/login/password",
        json={
            "organization_id": str(org.id),
            "username": "admin@test.com",
            "password": "mysecretpassword"
        }
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()
    assert login_response.json()["user"]["role"] == "ADMIN"

def test_admin_password_login_failure(client, db):
    """Test login failure with invalid credentials."""
    org = Organization(
        id=uuid.uuid4(),
        slug="test-club",
        name_ta="தேர்வு கிளப்",
        name_en="Test Club"
    )
    db.add(org)
    db.commit()

    hashed_pwd = get_password_hash("mysecretpassword")
    admin = User(
        organization_id=org.id,
        phone_number="+919876543211",
        email="admin@test.com",
        password_hash=hashed_pwd,
        role="ADMIN",
        is_verified=True
    )
    db.add(admin)
    db.commit()

    login_response = client.post(
        "/api/v1/auth/login/password",
        json={
            "organization_id": str(org.id),
            "username": "admin@test.com",
            "password": "wrongpassword"
        }
    )
    assert login_response.status_code == 400
    assert login_response.json()["detail"] == "Invalid username or password"



def _reg_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"reg-{uuid.uuid4().hex[:6]}",
                       name_ta="கிளப்", name_en="Club")
    db.add(org)
    db.commit()
    return org


def _reg_payload(org_id, **overrides):
    payload = {
        "organization_id": str(org_id),
        "phone_number": "+919000000001",
        "email": "member@example.com",
        "date_of_birth": "1995-03-10",
        "role": "VOLUNTEER",
        "full_name_ta": "பெயர்",
        "full_name_en": "Name",
    }
    payload.update(overrides)
    return payload


def test_register_email_optional(client, db):
    """Email is optional at registration now — omitting it succeeds."""
    org = _reg_org(db)
    body = _reg_payload(org.id)
    body.pop("email")
    r = client.post("/api/v1/auth/register", json=body)
    assert r.status_code == 200, r.text
    assert r.json()["user"].get("email") in (None, "")


def test_register_rejects_invalid_email(client, db):
    org = _reg_org(db)
    r = client.post("/api/v1/auth/register", json=_reg_payload(org.id, email="not-an-email"))
    assert r.status_code == 422, r.text


def test_register_needs_nothing_but_a_verified_number(client, db):
    """Signing up is not a form any more.

    Registration used to demand a date of birth, a name and a role before an
    account could exist — a queue between a member and the app on the day they
    installed it, and then the completeness gate asked for most of it again.
    Those facts are still wanted; they are asked afterwards, one question at a
    time, by the profile-prompt system. What the door needs is a number we have
    verified."""
    org = _reg_org(db)
    body = _reg_payload(org.id)
    for optional in ("date_of_birth", "gender", "role", "email"):
        body.pop(optional, None)
    r = client.post("/api/v1/auth/register", json=body)
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]


def test_register_without_a_name_still_produces_a_usable_account(client, db):
    """The name columns are NOT NULL, so a nameless signup must land on
    something neutral and unique rather than a blank row that breaks the
    directory."""
    org = _reg_org(db)
    body = _reg_payload(org.id, phone_number="+919000000077")
    for optional in ("date_of_birth", "gender", "role", "email", "full_name_en",
                     "full_name_ta"):
        body.pop(optional, None)
    r = client.post("/api/v1/auth/register", json=body)
    assert r.status_code == 200, r.text
    assert r.json()["user"]["full_name_en"] == "Member 0077"


def test_register_rejects_future_date_of_birth(client, db):
    org = _reg_org(db)
    r = client.post("/api/v1/auth/register", json=_reg_payload(org.id, date_of_birth="2999-01-01"))
    assert r.status_code == 422, r.text


def test_register_rejects_duplicate_email_in_org(client, db):
    org = _reg_org(db)
    first = client.post("/api/v1/auth/register", json=_reg_payload(org.id))
    assert first.status_code == 200, first.text
    # Same email (case-insensitive), different phone → rejected.
    dup = client.post("/api/v1/auth/register",
                      json=_reg_payload(org.id, phone_number="+919000000002", email="MEMBER@example.com"))
    assert dup.status_code == 400, dup.text
    assert "Email already registered" in dup.json()["detail"]


def test_google_new_user_gets_a_session(client, db, monkeypatch):
    """A brand-new Google account is signed straight in as an ordinary member.

    Google proves the identity and that creates the session; the phone stays an
    unverified claim collected later under the grace period, never a gate on
    getting in (docs/design/one-button-sign-in.md). This is what lets a
    participant with a Google account log in when SMS/OTP delivery is degraded.
    """
    import app.routers.auth as auth_router
    org = _reg_org(db)

    monkeypatch.setattr(
        auth_router.id_token, "verify_oauth2_token",
        lambda *a, **k: {"email": "newbie@gmail.com", "sub": "g-sub-1", "name": "New Bie"},
    )

    r = client.post("/api/v1/auth/google",
                    json={"organization_id": str(org.id), "id_token": "fake"})
    assert r.status_code == 200, r.text
    body = r.json()
    # A real session, not a registration detour.
    assert body.get("needs_registration") is not True
    assert "access_token" in body

    created = db.query(User).filter(User.email == "newbie@gmail.com").first()
    assert created is not None
    # Ordinary member, and the phone is untouched and unverified — the security
    # invariant that only OTP proof may attach/verify a number is preserved.
    assert created.role == "PUBLIC_CITIZEN"
    assert created.phone_number is None
    assert created.phone_verified_at is None


def test_google_existing_user_logs_in(client, db, monkeypatch):
    """An existing member signing in with Google still gets a normal token."""
    import app.routers.auth as auth_router
    org = _reg_org(db)

    # Register a member the normal way, then attach their email via Google.
    reg = client.post("/api/v1/auth/register", json=_reg_payload(org.id, email="existing@gmail.com"))
    assert reg.status_code == 200, reg.text

    monkeypatch.setattr(
        auth_router.id_token, "verify_oauth2_token",
        lambda *a, **k: {"email": "existing@gmail.com", "sub": "g-sub-2", "name": "Existing"},
    )
    r = client.post("/api/v1/auth/google",
                    json={"organization_id": str(org.id), "id_token": "fake"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert "access_token" in body
    assert body.get("needs_registration") is not True


def test_google_access_token_fallback_for_legacy_devices(client, db, monkeypatch):
    """Older Android devices (Oppo A3s, etc.) where idToken is unminted can authenticate via access_token."""
    import app.routers.auth as auth_router
    org = _reg_org(db)

    reg = client.post("/api/v1/auth/register", json=_reg_payload(org.id, email="oppo_user@gmail.com"))
    assert reg.status_code == 200, reg.text

    monkeypatch.setattr(
        auth_router, "_verify_google_access_token",
        lambda token: {"email": "oppo_user@gmail.com", "sub": "g-sub-oppo", "name": "Oppo User"},
    )
    r = client.post(
        "/api/v1/auth/google",
        json={"organization_id": str(org.id), "access_token": "ya29.valid_access_token"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert "access_token" in body
    assert body.get("needs_registration") is not True


def _send_otp_direct(db, org_id, phone, email=None):
    """Call the handler past its rate-limit decorator.

    These two tests are about the delivery ladder, not about the limiter — and
    the limiter is per-IP with every test in this file sharing one, so by the
    time they run the budget is spent. Neither `Limiter.reset()` nor clearing
    the storage moves the moving window, so the honest way in is the
    undecorated function that slowapi leaves on `__wrapped__`.
    """
    from app.routers.auth import send_otp
    from app.schemas.auth import OTPRequest
    payload = OTPRequest(organization_id=org_id, phone_number=phone, email=email)
    return send_otp.__wrapped__(request=None, payload=payload, db=db)


def test_a_twilio_outage_does_not_lock_the_club_out(db, monkeypatch):
    """The fallbacks exist for exactly this moment and must be reachable.

    This used to be an if/else: with TWILIO_VERIFY_SID configured, a failed
    Verify send raised 502 and stopped there. The WhatsApp and email senders in
    otp_sender.py were only ever reached when Verify was not configured at all
    — so on the one day Twilio has an outage, or a trial balance runs out, or a
    number is unverified, every member is locked out and the code written to
    save them is unreachable."""
    from app.core.config import settings as app_settings
    from app.routers import auth as auth_router

    org = Organization(id=uuid.uuid4(), slug=f"t-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Org")
    db.add(org); db.commit()

    monkeypatch.setattr(app_settings, "TWILIO_VERIFY_SID", "VAtest", raising=False)
    # Twilio is down.
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: False)
    # WhatsApp picks it up.
    monkeypatch.setattr(auth_router, "deliver_otp",
                        lambda phone, otp, email=None: {"whatsapp": True})

    res = _send_otp_direct(db, org.id, "+919876500011")
    assert res.channel == "whatsapp", "must fall through, not raise"

    # And the code minted for the fallback channel actually verifies, rather
    # than the request pointing at a Twilio verification that never happened.
    from app.models.otp import PendingOtp
    pending = db.get(PendingOtp, res.verification_id)
    assert pending is not None, "the handle must outlive the request"
    assert pending.code_hash is not None, \
        "a fallback channel needs a code we generated"


def test_every_channel_down_says_so_and_leaves_nothing_dangling(db, monkeypatch):
    """When nothing carried it, do not hand back a verification id pointing at
    a message that was never sent."""
    import pytest
    from fastapi import HTTPException
    from app.core.config import settings as app_settings
    from app.routers import auth as auth_router

    org = Organization(id=uuid.uuid4(), slug=f"t-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Org")
    db.add(org); db.commit()

    monkeypatch.setattr(app_settings, "TWILIO_VERIFY_SID", "VAtest", raising=False)
    monkeypatch.setattr(app_settings, "OTP_BYPASS_CODE", "", raising=False)
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: False)
    monkeypatch.setattr(auth_router, "deliver_otp",
                        lambda phone, otp, email=None: {"whatsapp": False, "email": False})

    from app.models.otp import PendingOtp
    before = db.query(PendingOtp).count()
    with pytest.raises(HTTPException) as raised:
        _send_otp_direct(db, org.id, "+919876500012")
    assert raised.value.status_code == 502
    assert "organizer" in raised.value.detail.lower()
    assert db.query(PendingOtp).count() == before, "no dangling verification"


def test_the_app_can_say_which_doors_are_open(client):
    """A deploy where OTP and Google both stopped working left no way to tell,
    from outside, whether the cause was a missing secret, an expired
    credential, a bad client id or the code — every answer needed someone with
    dashboard access. This reports configuration, never values."""
    r = client.get("/api/health/auth")
    assert r.status_code == 200, r.text
    body = r.json()

    assert "can_deliver_a_code" in body
    assert set(body["channels"]) == {
        "sms_twilio_verify", "whatsapp_twilio", "email_smtp", "otp_bypass"
    }
    # Configuration, not credentials. Nothing here may carry a secret value.
    blob = r.text.lower()
    for leak in ("auth_token", "password", "sid", "secret_key"):
        assert leak not in blob, f"{leak} must not appear in a public probe"


def test_a_restart_does_not_lose_a_sign_in_in_progress(db, monkeypatch):
    """The pending code must outlive the process that minted it.

    It used to live in a module-level dict. On one machine with one worker that
    looks correct — until the process restarts. A deploy, a crash, an OOM kill:
    any of them emptied the dict, and every member holding an SMS they had not
    typed yet got "Invalid or expired verification ID".

    That message is the damaging part. It is indistinguishable from mistyping
    the code, so nobody reports a server fault — they assume they fumbled it,
    ask for a new code, and hit the same wall. Across a run of frequent deploys
    it reads exactly like "login has been down for days".

    Here the restart is simulated the only way that proves the point: throw
    away every scrap of module state and re-import, then verify.
    """
    import importlib
    from app.core.config import settings as app_settings
    from app.routers import auth as auth_router

    org = Organization(id=uuid.uuid4(), slug=f"t-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Org")
    db.add(org)
    db.commit()

    monkeypatch.setattr(app_settings, "TWILIO_VERIFY_SID", "", raising=False)
    monkeypatch.setattr(app_settings, "OTP_BYPASS_CODE", "", raising=False)
    sent = {}

    def _capture(phone, otp, email=None):
        sent["code"] = otp
        return {"sms": True}

    monkeypatch.setattr(auth_router, "deliver_otp", _capture)
    res = _send_otp_direct(db, org.id, "+919876500099")

    # ── the machine goes away and comes back ──────────────────────────────
    importlib.reload(auth_router)

    from app.schemas.auth import OTPVerify
    out = auth_router.verify_otp.__wrapped__(
        request=None,
        payload=OTPVerify(verification_id=res.verification_id,
                          otp_code=sent["code"]),
        db=db,
    )
    assert getattr(out, "registration_token", None) or getattr(out, "access_token", None), \
        "the code that was sent must still work after a restart"


def test_the_code_itself_is_never_written_down(db, monkeypatch):
    """Only an HMAC of the code is stored.

    A six-digit code is a million guesses — trivially reversed from a plain
    hash — so the digest is keyed with the app secret. A leaked table is inert
    to anyone without SECRET_KEY, for the ten minutes the row exists at all.
    """
    from app.core.config import settings as app_settings
    from app.models.otp import PendingOtp
    from app.routers import auth as auth_router

    org = Organization(id=uuid.uuid4(), slug=f"t-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Org")
    db.add(org)
    db.commit()

    monkeypatch.setattr(app_settings, "TWILIO_VERIFY_SID", "", raising=False)
    monkeypatch.setattr(app_settings, "OTP_BYPASS_CODE", "", raising=False)
    sent = {}
    monkeypatch.setattr(auth_router, "deliver_otp",
                        lambda phone, otp, email=None: (sent.update(code=otp),
                                                        {"sms": True})[1])

    res = _send_otp_direct(db, org.id, "+919876500098")
    row = db.get(PendingOtp, res.verification_id)

    assert sent["code"] not in (row.code_hash or ""), "the code must not be recoverable"
    assert len(row.code_hash) == 64, "sha256 hex"


def test_the_app_can_say_where_a_half_finished_sign_in_is_kept(client):
    """"The code arrived, then the server said the handle was invalid" has
    several causes that look identical from a phone.

    Production is unreachable from a development machine, so the only way to
    tell a lost-on-restart store from a missing table from two instances
    answering in turn is to let the deployment say so itself. Counts and names,
    never a phone number and never a code.
    """
    body = client.get("/api/health/auth").json()
    store = body["session_store"]

    assert store["otp_store"] == "database", \
        "a store that dies with the process is the bug this reports"
    assert store["table_present"] is True
    assert isinstance(store["pending_sign_ins"], int)
    assert store["database"] in {"postgresql", "sqlite"}
    # Two loads showing different instances is the whole diagnosis for
    # "it works every other time".
    assert store["instance"]

    # Nothing here may carry a secret, a number or a code.
    assert "url" not in str(store).lower()


def test_the_health_page_names_which_google_client_the_browser_road_uses(client):
    """A redirect_uri_mismatch has two causes that read identically.

    The club has two legitimate web clients — the website's and the mobile
    app's Firebase project. A callback URI registered on one says nothing about
    the other, so "the URI is missing" and "the URI is on the wrong client"
    produce the same error page. Reporting the redirect URI alone left guessing
    and redeploying as the only way to tell them apart, twice.

    Client ids are not secrets; they ship inside the APK. The secret must never
    appear here, and that is what the second half of this test holds down.
    """
    fallback = client.get("/api/health/auth").json()["google_sign_in"]["browser_fallback"]

    assert "client_id" in fallback, \
        "the answer to 'which client?' belongs in the response, not in somebody's memory"

    body = str(client.get("/api/health/auth").json())
    assert "GOCSPX" not in body, "a client secret must never be reported"
    assert "client_secret" not in body
