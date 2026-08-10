"""Celebrations and the member card — the feature the club planned first and
built last: the app remembers birthdays and wedding anniversaries every year,
announces them only where they belong, and shows one member to another
without leaking what was never offered.
"""
import datetime
import uuid

from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _make_org(db):
    org = Organization(id=uuid.uuid4(), slug=f"cel-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_user(db, org_id, phone, name="Member", dob=None, anniversary=None,
               celebrate=True):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role="VOLUNTEER",
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="உறுப்பினர்",
                       full_name_en=name, date_of_birth=dob,
                       wedding_anniversary=anniversary,
                       celebrate_publicly=celebrate))
    db.commit()
    return u


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id),
                          "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def test_todays_birthdays_and_anniversaries_are_listed(client, db):
    org = _make_org(db)
    today = datetime.date.today()
    _make_user(db, org.id, "9910000001", name="Viewer")
    _make_user(db, org.id, "9910000002", name="Birthday Person",
               dob=datetime.date(1990, today.month, today.day))
    _make_user(db, org.id, "9910000003", name="Anniversary Couple",
               anniversary=datetime.date(2015, today.month, today.day))
    _make_user(db, org.id, "9910000004", name="Ordinary Day",
               dob=datetime.date(1990, 1, 1) if today.month != 1 or today.day != 1
               else datetime.date(1990, 6, 15))
    H = _h(org.id, _login(client, org.id, "9910000001"))

    r = client.get("/api/v1/users/celebrations/today", headers=H)
    assert r.status_code == 200
    got = {(c["full_name_en"], c["kind"]) for c in r.json()}
    assert ("Birthday Person", "birthday") in got
    assert ("Anniversary Couple", "anniversary") in got
    assert all(name != "Ordinary Day" for name, _ in got)


def test_a_private_celebrant_is_not_announced(client, db):
    """The switch decides whether the CLUB is told — the personal greeting is
    handled by the job and is never public."""
    org = _make_org(db)
    today = datetime.date.today()
    _make_user(db, org.id, "9910000005", name="Viewer")
    _make_user(db, org.id, "9910000006", name="Private Person",
               dob=datetime.date(1985, today.month, today.day),
               celebrate=False)
    H = _h(org.id, _login(client, org.id, "9910000005"))

    r = client.get("/api/v1/users/celebrations/today", headers=H)
    assert all(c["full_name_en"] != "Private Person" for c in r.json())


def test_the_member_card_shows_the_day_and_never_the_year(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9910000007", name="Viewer")
    member = _make_user(db, org.id, "9910000008", name="Arun Kumar",
                        dob=datetime.date(1990, 8, 9),
                        anniversary=datetime.date(2015, 12, 1))
    H = _h(org.id, _login(client, org.id, "9910000007"))

    r = client.get(f"/api/v1/users/{member.id}/card", headers=H)
    assert r.status_code == 200
    card = r.json()
    assert card["full_name_en"] == "Arun Kumar"
    assert card["birthday_day_month"] == "08-09"
    assert card["anniversary_day_month"] == "12-01"
    # The year — someone's age, someone's wedding year — never leaves.
    assert "1990" not in r.text and "2015" not in r.text
    # Nor do the contact and medical facts the card deliberately excludes.
    for forbidden in ("phone", "email", "blood_group", "gender"):
        assert forbidden not in card


def test_a_private_member_card_shows_no_dates_at_all(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9910000009", name="Viewer")
    member = _make_user(db, org.id, "9910000010", name="Private",
                        dob=datetime.date(1985, 3, 3), celebrate=False)
    H = _h(org.id, _login(client, org.id, "9910000009"))

    card = client.get(f"/api/v1/users/{member.id}/card", headers=H).json()
    assert card["birthday_day_month"] is None
    assert card["is_birthday_today"] is False


def test_another_orgs_member_is_a_404(client, db):
    org_a = _make_org(db)
    org_b = _make_org(db)
    _make_user(db, org_a.id, "9910000011", name="Viewer")
    stranger = _make_user(db, org_b.id, "9910000012", name="Elsewhere")
    H = _h(org_a.id, _login(client, org_a.id, "9910000011"))

    assert client.get(f"/api/v1/users/{stranger.id}/card",
                      headers=H).status_code == 404


def test_anniversary_saves_through_the_profile_patch(client, db):
    org = _make_org(db)
    _make_user(db, org.id, "9910000013", name="Me")
    H = _h(org.id, _login(client, org.id, "9910000013"))

    r = client.patch("/api/v1/users/me/profile", json={
        "wedding_anniversary": "2018-11-25",
        "celebrate_publicly": False,
    }, headers=H)
    assert r.status_code == 200

    db.expire_all()
    me = db.query(User).filter(User.phone_number == "9910000013").first()
    profile = db.query(UserProfile).filter(
        UserProfile.user_id == me.id).first()
    assert str(profile.wedding_anniversary) == "2018-11-25"
    assert profile.celebrate_publicly is False


def test_milestone_anniversaries_carry_their_ordinal(client, db):
    """A 10th anniversary IS the story — the member typed the year in
    themselves. A birthday still never carries an age."""
    org = _make_org(db)
    today = datetime.date.today()
    _make_user(db, org.id, "9910000014", name="Viewer")
    _make_user(db, org.id, "9910000015", name="Ten Years",
               anniversary=datetime.date(today.year - 10, today.month, today.day))
    _make_user(db, org.id, "9910000016", name="Three Years",
               anniversary=datetime.date(today.year - 3, today.month, today.day))
    _make_user(db, org.id, "9910000017", name="Birthday Person",
               dob=datetime.date(1990, today.month, today.day))
    H = _h(org.id, _login(client, org.id, "9910000014"))

    got = {c["full_name_en"]: c
           for c in client.get("/api/v1/users/celebrations/today",
                               headers=H).json()}
    assert got["Ten Years"]["years"] == 10
    assert got["Ten Years"]["is_milestone"] is True
    assert got["Three Years"]["years"] == 3
    assert got["Three Years"]["is_milestone"] is False
    assert got["Birthday Person"]["years"] is None, \
        "an age is nobody's announcement to make"


def test_a_legacy_row_with_null_flag_is_still_announced(client, db):
    """Production rows existed before the column did — NULL means the member
    never chose, and never-chose counts as public (the pre-feature default)."""
    org = _make_org(db)
    today = datetime.date.today()
    _make_user(db, org.id, "9910000018", name="Viewer")
    legacy = _make_user(db, org.id, "9910000019", name="Legacy Member",
                        dob=datetime.date(1990, today.month, today.day))
    profile = db.query(UserProfile).filter(
        UserProfile.user_id == legacy.id).first()
    profile.celebrate_publicly = None
    db.commit()
    H = _h(org.id, _login(client, org.id, "9910000018"))

    names = {c["full_name_en"]
             for c in client.get("/api/v1/users/celebrations/today",
                                 headers=H).json()}
    assert "Legacy Member" in names



def test_a_birthday_only_reaches_members(client, db):
    """Who is celebrating today is the club's own news.

    `/users/birthdays/today` answered anyone holding the org id, which turned a
    warm internal signal into a roster of names and dates a stranger could
    collect. The newer `/celebrations/today` always required a session; this
    older endpoint was never brought in line.
    """
    org = _make_org(db)
    today = datetime.date.today()
    _make_user(db, org.id, "9910000030", name="Celebrant",
               dob=datetime.date(1988, today.month, today.day))

    anon = client.get("/api/v1/users/birthdays/today",
                      headers={"X-Organization-ID": str(org.id)})
    assert anon.status_code == 401

    _make_user(db, org.id, "9910000031", name="Viewer")
    H = _h(org.id, _login(client, org.id, "9910000031"))
    signed_in = client.get("/api/v1/users/birthdays/today", headers=H)
    assert signed_in.status_code == 200
    assert "Celebrant" in {b["full_name_en"] for b in signed_in.json()}
