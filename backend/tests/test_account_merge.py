"""Two accounts for one person, folded into one.

The case that prompted this: an officer set up by email with a password, who
later signed in on their phone and got a second account. Because a phone number
is unique per club, OTP sign-in can only ever reach the phone one — so the
officer signs in and finds themselves an ordinary member, with none of their
own work attached.
"""
import uuid

from app.core.security import get_password_hash
from app.models.notification import Notification
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"mg-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _user(db, org_id, *, phone=None, email=None, role="VOLUNTEER", **profile):
    u = User(organization_id=org_id, phone_number=phone, email=email,
             password_hash=get_password_hash("pass"), role=role,
             is_verified=True)
    db.add(u)
    db.flush()
    profile.setdefault("full_name_ta", profile.get("full_name_en", "உறுப்பினர்"))
    db.add(UserProfile(user_id=u.id, **profile))
    db.commit()
    return u


def _login(client, org_id, username):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id),
                          "username": username, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


def _notify(db, org_id, user_id, title):
    db.add(Notification(id=uuid.uuid4(), organization_id=org_id, user_id=user_id,
                        title_en=title, title_ta=title, body_en="b", body_ta="b",
                        notification_type="ADMIN"))
    db.commit()


def test_a_rehearsal_changes_nothing(client, db):
    """The default is a dry run, and a dry run must leave both accounts alone.

    It executes every statement for real and rolls back, which is the only way
    the numbers in the report can be trusted — but it means a bug in the
    rollback would silently destroy an account. Hence this test first.
    """
    org = _org(db)
    _user(db, org.id, email="boss@fyc.test", role="ADMIN", full_name_en="Boss")
    keeper = db.query(User).filter(User.email == "boss@fyc.test").one()
    other = _user(db, org.id, phone="9490000001", full_name_en="Same Person")
    _notify(db, org.id, other.id, "For the phone account")
    H = _h(org.id, _login(client, org.id, "boss@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(keeper.id), "merge_user_id": str(other.id),
    }, headers=H)
    assert r.status_code == 200
    assert r.json()["dry_run"] is True
    assert r.json()["moved"]["notifications.user_id"] == 1

    db.expire_all()
    assert db.get(User, other.id) is not None, "a rehearsal must not delete"
    assert db.get(User, keeper.id).phone_number is None
    assert db.query(Notification).filter(
        Notification.user_id == other.id).count() == 1


def test_the_phone_and_the_work_move_to_the_account_that_stays(client, db):
    org = _org(db)
    _user(db, org.id, email="boss@fyc.test", role="ADMIN", full_name_en="Boss")
    keeper = db.query(User).filter(User.email == "boss@fyc.test").one()
    other = _user(db, org.id, phone="9490000002", full_name_en="Same Person")
    _notify(db, org.id, other.id, "Mine, really")
    H = _h(org.id, _login(client, org.id, "boss@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(keeper.id), "merge_user_id": str(other.id),
        "dry_run": False,
    }, headers=H)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["phone_number_moved"] == "9490000002"
    assert body["role_after"] == "ADMIN", "the stronger of the two roles survives"

    db.expire_all()
    assert db.get(User, other.id) is None, "the second account is gone"
    assert db.get(User, keeper.id).phone_number == "9490000002", \
        "signing in by OTP must now reach the account that has the powers"
    assert db.query(Notification).filter(
        Notification.user_id == keeper.id).count() == 1


def test_the_profile_keeps_what_only_the_other_account_knew(client, db):
    """This is usually where the real information is.

    An officer's email account was created by an administrator and carries
    little more than a name. The phone account was created by the member
    themselves, so the date of birth and blood group live there — and those are
    exactly what the birthday card and the donor search read.
    """
    org = _org(db)
    import datetime
    _user(db, org.id, email="boss@fyc.test", role="ADMIN", full_name_en="Boss")
    keeper = db.query(User).filter(User.email == "boss@fyc.test").one()
    other = _user(db, org.id, phone="9490000003", full_name_en="Boss",
                  date_of_birth=datetime.date(1985, 4, 12), blood_group="O+")
    H = _h(org.id, _login(client, org.id, "boss@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(keeper.id), "merge_user_id": str(other.id),
        "dry_run": False,
    }, headers=H)
    assert r.status_code == 200
    filled = r.json()["profile_fields_filled"]
    assert "date_of_birth" in filled and "blood_group" in filled

    db.expire_all()
    kept = db.query(UserProfile).filter(UserProfile.user_id == keeper.id).one()
    assert kept.date_of_birth == datetime.date(1985, 4, 12)
    assert kept.blood_group == "O+"
    assert kept.full_name_en == "Boss", "an existing answer is never overwritten"


def test_a_collision_drops_the_duplicate_instead_of_failing(client, db):
    """Some tables allow exactly one row per user.

    Both accounts have a profile. Merging cannot produce two, and it must not
    abort the whole operation either — the surviving account keeps its own row
    and the duplicate is deleted, counted and reported.
    """
    org = _org(db)
    _user(db, org.id, email="boss@fyc.test", role="ADMIN", full_name_en="Boss")
    keeper = db.query(User).filter(User.email == "boss@fyc.test").one()
    other = _user(db, org.id, phone="9490000004", full_name_en="Same Person")
    H = _h(org.id, _login(client, org.id, "boss@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(keeper.id), "merge_user_id": str(other.id),
        "dry_run": False,
    }, headers=H)
    assert r.status_code == 200, r.text

    db.expire_all()
    assert db.query(UserProfile).filter(
        UserProfile.user_id == keeper.id).count() == 1
    assert db.query(UserProfile).filter(
        UserProfile.user_id == other.id).count() == 0


def test_merging_is_not_an_executives_tool(client, db):
    org = _org(db)
    _user(db, org.id, email="exec@fyc.test", role="EXECUTIVE_MEMBER",
          full_name_en="Exec")
    a = _user(db, org.id, phone="9490000005", full_name_en="A")
    b = _user(db, org.id, phone="9490000006", full_name_en="B")
    H = _h(org.id, _login(client, org.id, "exec@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(a.id), "merge_user_id": str(b.id), "dry_run": False,
    }, headers=H)
    assert r.status_code == 403, \
        "moving everything one account owns and deleting it is above this tier"


def test_you_cannot_delete_the_account_you_are_signed_in_as(client, db):
    """It would end the session mid-request and leave no way back in."""
    org = _org(db)
    _user(db, org.id, email="boss@fyc.test", role="ADMIN", full_name_en="Boss")
    caller = db.query(User).filter(User.email == "boss@fyc.test").one()
    other = _user(db, org.id, phone="9490000007", full_name_en="Other")
    H = _h(org.id, _login(client, org.id, "boss@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(other.id), "merge_user_id": str(caller.id),
        "dry_run": False,
    }, headers=H)
    assert r.status_code == 400
    assert "keeping" in r.json()["detail"]


def test_an_account_from_another_club_is_not_visible(client, db):
    org = _org(db)
    elsewhere = _org(db)
    _user(db, org.id, email="boss@fyc.test", role="ADMIN", full_name_en="Boss")
    keeper = db.query(User).filter(User.email == "boss@fyc.test").one()
    stranger = _user(db, elsewhere.id, phone="9490000008", full_name_en="Elsewhere")
    H = _h(org.id, _login(client, org.id, "boss@fyc.test"))

    r = client.post("/api/v1/users/merge", json={
        "keep_user_id": str(keeper.id), "merge_user_id": str(stranger.id),
        "dry_run": False,
    }, headers=H)
    assert r.status_code == 404
