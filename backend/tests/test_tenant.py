import uuid
from app.models.tenant import Organization

def test_tenant_isolation_success(client, db):
    """Accessing user details with matching JWT and X-Organization-ID must succeed."""
    org = Organization(
        id=uuid.uuid4(),
        slug="org-a",
        name_ta="அமைப்பு ஏ",
        name_en="Organization A"
    )
    db.add(org)
    db.commit()

    # Register User
    reg_response = client.post(
        "/api/v1/auth/register",
        json={
            "organization_id": str(org.id),
            "phone_number": "+919876543210",
            "role": "PUBLIC_CITIZEN",
            "full_name_ta": "அன்பு",
            "full_name_en": "Anbu"
        }
    )
    token = reg_response.json()["access_token"]

    # Request /users/me with correct X-Organization-ID
    response = client.get(
        "/api/v1/auth/users/me",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Organization-ID": str(org.id)
        }
    )
    assert response.status_code == 200
    assert response.json()["phone_number"] == "+919876543210"

def test_tenant_isolation_forbidden_mismatch(client, db):
    """Accessing with a mismatching X-Organization-ID must return 403 forbidden."""
    org_a = Organization(
        id=uuid.uuid4(),
        slug="org-a",
        name_ta="அமைப்பு ஏ",
        name_en="Organization A"
    )
    org_b = Organization(
        id=uuid.uuid4(),
        slug="org-b",
        name_ta="அமைப்பு பி",
        name_en="Organization B"
    )
    db.add_all([org_a, org_b])
    db.commit()

    # Register under Org A
    reg_response = client.post(
        "/api/v1/auth/register",
        json={
            "organization_id": str(org_a.id),
            "phone_number": "+919876543210",
            "role": "PUBLIC_CITIZEN",
            "full_name_ta": "அன்பு",
            "full_name_en": "Anbu"
        }
    )
    token = reg_response.json()["access_token"]

    # Request /users/me with Org B header (Mismatch)
    response = client.get(
        "/api/v1/auth/users/me",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Organization-ID": str(org_b.id)
        }
    )
    assert response.status_code == 403
    assert "Cross-tenant access denied" in response.json()["detail"]

def test_tenant_isolation_missing_header(client, db):
    """Accessing without X-Organization-ID header must return 403 forbidden."""
    org = Organization(
        id=uuid.uuid4(),
        slug="org-a",
        name_ta="அமைப்பு ஏ",
        name_en="Organization A"
    )
    db.add(org)
    db.commit()

    # Register
    reg_response = client.post(
        "/api/v1/auth/register",
        json={
            "organization_id": str(org.id),
            "phone_number": "+919876543210",
            "role": "PUBLIC_CITIZEN",
            "full_name_ta": "அன்பு",
            "full_name_en": "Anbu"
        }
    )
    token = reg_response.json()["access_token"]

    # Request /users/me without X-Organization-ID header
    response = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 403
    assert "Cross-tenant access denied" in response.json()["detail"]
