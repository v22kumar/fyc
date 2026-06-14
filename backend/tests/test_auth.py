import uuid
from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User

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
    assert verify_response.status_code == 404
    assert "Please call /auth/register" in verify_response.json()["detail"]

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

