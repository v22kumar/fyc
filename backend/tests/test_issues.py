import uuid
from app.models.tenant import Organization


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"iss-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _register(client, org_id, phone, role="PUBLIC_CITIZEN"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id),
        "phone_number": phone,
        "role": role,
        "full_name_ta": "பயனர்",
        "full_name_en": "User"
    })
    return res.json()["access_token"]


ISSUE_PAYLOAD = {
    "category": "ROAD",
    "description_ta": "சாலையில் பள்ளம் உள்ளது",
    "description_en": "There is a pothole on the road",
    "latitude": 8.1833,
    "longitude": 77.4119,
    "photo_url": "https://example.com/photo.jpg"
}


def test_submit_issue_anonymous(client, db):
    """Anonymous users can submit issues with X-Organization-ID header."""
    org = _make_org(db)
    res = client.post(
        "/api/v1/issues",
        json=ISSUE_PAYLOAD,
        headers={"X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    data = res.json()
    assert data["category"] == "ROAD"
    assert data["status"] == "NEW"
    assert data["reported_by_user_id"] is None


def test_submit_issue_authenticated(client, db):
    """Authenticated users have their ID linked to the issue."""
    org = _make_org(db)
    token = _register(client, org.id, "+919222222221")

    res = client.post(
        "/api/v1/issues",
        json=ISSUE_PAYLOAD,
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 201
    assert res.json()["reported_by_user_id"] is not None


def test_submit_issue_no_org_header(client, db):
    """Missing X-Organization-ID header must return 400."""
    res = client.post("/api/v1/issues", json=ISSUE_PAYLOAD)
    assert res.status_code == 400


def test_list_issues(client, db):
    org = _make_org(db)
    client.post("/api/v1/issues", json=ISSUE_PAYLOAD, headers={"X-Organization-ID": str(org.id)})
    client.post("/api/v1/issues", json={**ISSUE_PAYLOAD, "category": "WATER"},
                headers={"X-Organization-ID": str(org.id)})

    res = client.get("/api/v1/issues", headers={"X-Organization-ID": str(org.id)})
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_get_issue_by_id(client, db):
    org = _make_org(db)
    create_res = client.post(
        "/api/v1/issues", json=ISSUE_PAYLOAD,
        headers={"X-Organization-ID": str(org.id)}
    )
    issue_id = create_res.json()["id"]

    res = client.get(
        f"/api/v1/issues/{issue_id}",
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert res.json()["id"] == issue_id


def test_issue_state_machine_assign(client, db):
    """Admin can transition NEW → ASSIGNED."""
    org = _make_org(db)
    admin_token = _register(client, org.id, "+919222222222", role="VOLUNTEER")
    # Register an actual admin
    from app.models.user import User, UserProfile
    from app.core.security import get_password_hash
    admin = User(organization_id=org.id, phone_number="+919222222223",
                 password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(admin)
    db.flush()
    db.add(UserProfile(user_id=admin.id, full_name_ta="அட்மின்", full_name_en="Admin"))
    db.commit()
    admin_login = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "+919222222223", "password": "pass"
    })
    admin_token = admin_login.json()["access_token"]

    issue_res = client.post(
        "/api/v1/issues", json=ISSUE_PAYLOAD,
        headers={"X-Organization-ID": str(org.id)}
    )
    issue_id = issue_res.json()["id"]

    vol_token = _register(client, org.id, "+919222222224", role="VOLUNTEER")
    vol_me = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)}
    )
    vol_id = vol_me.json()["id"]

    status_res = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "ASSIGNED", "assigned_volunteer_id": vol_id},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}
    )
    assert status_res.status_code == 200
    assert status_res.json()["status"] == "ASSIGNED"
    assert status_res.json()["assigned_volunteer_id"] == vol_id


def test_issue_invalid_transition(client, db):
    """Invalid state transitions must return 400."""
    org = _make_org(db)
    from app.models.user import User, UserProfile
    from app.core.security import get_password_hash
    admin = User(organization_id=org.id, phone_number="+919222222225",
                 password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(admin)
    db.flush()
    db.add(UserProfile(user_id=admin.id, full_name_ta="அட்மின்", full_name_en="Admin"))
    db.commit()
    admin_login = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "+919222222225", "password": "pass"
    })
    token = admin_login.json()["access_token"]

    issue_res = client.post(
        "/api/v1/issues", json=ISSUE_PAYLOAD,
        headers={"X-Organization-ID": str(org.id)}
    )
    issue_id = issue_res.json()["id"]

    # NEW → RESOLVED is invalid
    res = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "RESOLVED"},
        headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 400
    assert "Invalid transition" in res.json()["detail"]


def test_volunteer_cannot_update_unassigned_issue(client, db):
    """A volunteer cannot update an issue not assigned to them."""
    org = _make_org(db)
    from app.models.user import User, UserProfile
    from app.core.security import get_password_hash

    admin = User(organization_id=org.id, phone_number="+919222222226",
                 password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(admin)
    db.flush()
    db.add(UserProfile(user_id=admin.id, full_name_ta="அட்மின்", full_name_en="Admin"))
    db.commit()
    admin_login = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "+919222222226", "password": "pass"
    })
    admin_token = admin_login.json()["access_token"]

    vol_token = _register(client, org.id, "+919222222227", role="VOLUNTEER")

    issue_res = client.post(
        "/api/v1/issues", json=ISSUE_PAYLOAD,
        headers={"X-Organization-ID": str(org.id)}
    )
    issue_id = issue_res.json()["id"]

    # Admin assigns to someone else
    other_vol_token = _register(client, org.id, "+919222222228", role="VOLUNTEER")
    other_vol_me = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {other_vol_token}", "X-Organization-ID": str(org.id)}
    )
    other_vol_id = other_vol_me.json()["id"]

    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "ASSIGNED", "assigned_volunteer_id": other_vol_id},
        headers={"Authorization": f"Bearer {admin_token}", "X-Organization-ID": str(org.id)}
    )

    # Volunteer who is NOT assigned tries to update
    res = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "UNDER_REVIEW"},
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)}
    )
    assert res.status_code == 403


def test_issue_full_lifecycle(client, db):
    """Walk the full happy path: NEW → ASSIGNED → UNDER_REVIEW → RESOLVED → CLOSED."""
    org = _make_org(db)
    from app.models.user import User, UserProfile
    from app.core.security import get_password_hash

    admin = User(organization_id=org.id, phone_number="+919222222229",
                 password_hash=get_password_hash("pass"), role="ADMIN", is_verified=True)
    db.add(admin)
    db.flush()
    db.add(UserProfile(user_id=admin.id, full_name_ta="அட்மின்", full_name_en="Admin"))
    db.commit()
    admin_login = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id), "username": "+919222222229", "password": "pass"
    })
    admin_token = admin_login.json()["access_token"]

    vol_token = _register(client, org.id, "+919222222230", role="VOLUNTEER")
    vol_id = client.get(
        "/api/v1/auth/users/me",
        headers={"Authorization": f"Bearer {vol_token}", "X-Organization-ID": str(org.id)}
    ).json()["id"]

    issue_id = client.post(
        "/api/v1/issues", json=ISSUE_PAYLOAD,
        headers={"X-Organization-ID": str(org.id)}
    ).json()["id"]

    def transition(token, new_status, extra=None):
        body = {"status": new_status}
        if extra:
            body.update(extra)
        return client.patch(
            f"/api/v1/issues/{issue_id}/status", json=body,
            headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(org.id)}
        )

    assert transition(admin_token, "ASSIGNED", {"assigned_volunteer_id": vol_id}).status_code == 200
    assert transition(vol_token, "UNDER_REVIEW").status_code == 200
    assert transition(vol_token, "RESOLVED", {"verification_photo_url": "https://s3/proof.jpg"}).status_code == 200
    assert transition(admin_token, "CLOSED").status_code == 200

    final = client.get(
        f"/api/v1/issues/{issue_id}",
        headers={"X-Organization-ID": str(org.id)},
    ).json()
    assert final["status"] == "CLOSED"
    assert final["verification_photo_url"] == "https://s3/proof.jpg"
