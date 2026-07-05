import uuid

from app.models.tenant import Organization


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"search-org-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _register(client, org_id, phone, name_en="Ravi Kumar"):
    res = client.post("/api/v1/auth/register", json={
        "organization_id": str(org_id),
        "phone_number": phone,
        "role": "PUBLIC_CITIZEN",
        "full_name_ta": "ரவி",
        "full_name_en": name_en,
    })
    assert res.status_code in (200, 201), res.text
    return res.json()["access_token"]


def test_global_search_returns_users_without_500(client, db):
    """Regression: global search used u.profile_picture_url (nonexistent),
    which 500'd as 'failed to load results'. Confirm a USER match returns 200."""
    org = _make_org(db)
    _register(client, org.id, "+919555000001", name_en="Ravindran Selvam")

    res = client.get(
        "/api/v1/search",
        params={"q": "Ravindran"},
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    hits = res.json()
    assert any(h["type"] == "USER" and "Ravindran" in h["title"] for h in hits)


def test_global_search_empty_query_ok(client, db):
    """A search that matches nothing returns an empty list, not an error."""
    org = _make_org(db)
    res = client.get(
        "/api/v1/search",
        params={"q": "zzzznomatch"},
        headers={"X-Organization-ID": str(org.id)},
    )
    assert res.status_code == 200
    assert res.json() == []
