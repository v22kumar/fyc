"""Follow-ups to donor segregation:
  * the public donor list flags imported (Friends2Support) donors via is_imported
    so the app can badge them, while self-registered donors are not flagged;
  * the global "people" search excludes imported donor contacts (they still
    appear under the blood-donor results, just not as members/people).
"""
import uuid

from tests.test_cricket_scoring import _make_org


def _mk_donor(db, org_id, name, phone, *, source=None, role="PUBLIC_CITIZEN"):
    from app.models.user import User, UserProfile
    from app.models.blood_donor import BloodDonor
    u = User(id=uuid.uuid4(), organization_id=org_id, phone_number=phone,
             role=role, is_verified=True, source=source)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.add(BloodDonor(id=uuid.uuid4(), organization_id=org_id, user_id=u.id,
                      blood_group="O+", is_available=True))
    return u


def test_donor_list_flags_imported_and_people_search_excludes_them(client, db):
    org = _make_org(db)
    _mk_donor(db, org.id, "Imported Donor Z", "9500000301", source="F2S_IMPORT")
    _mk_donor(db, org.id, "Real Donor Y", "9500000302", source=None, role="CLUB_MEMBER")
    db.commit()

    H = {"X-Organization-ID": str(org.id)}

    # Donor list carries the imported flag for the badge.
    r = client.get("/api/v1/blood-donors", headers=H)
    assert r.status_code == 200, r.text
    by_name = {d["full_name_en"]: d for d in r.json()}
    assert by_name["Imported Donor Z"]["is_imported"] is True
    assert by_name["Real Donor Y"]["is_imported"] is False

    # Global people search excludes imported donor contacts, keeps real people.
    s = client.get("/api/v1/search", params={"q": "Donor"}, headers=H)
    assert s.status_code == 200, s.text
    people = {x["title"] for x in s.json() if x["type"] == "USER"}
    assert "Real Donor Y" in people
    assert "Imported Donor Z" not in people
