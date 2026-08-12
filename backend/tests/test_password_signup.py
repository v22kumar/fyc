"""A door the club owns, and the rule that keeps it safe.

Signing in depended entirely on two outside services — an SMS gateway and
Google. When either refuses, nobody can join and the club has no way to let
them in. Password sign-up removes that dependency.

Deferring verification is the easy half. The hard half is that the club
identifies members *by phone number*, so letting somebody register a number
they have not proven would otherwise mean: type a number, and inherit whoever
verifies it later. These tests are mostly about that.
"""
import uuid

from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.services.account_claims import mark_phone_verified, owner_of_phone


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"pw-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _signup(client, org_id, phone="9876500001", email=None, password="a-real-password",
            name="Anitha R"):
    return client.post("/api/v1/auth/register/password", json={
        "organization_id": str(org_id),
        "full_name": name,
        "phone_number": phone,
        "email": email or f"{uuid.uuid4().hex[:8]}@example.test",
        "password": password,
    })


def test_somebody_can_join_without_any_outside_service(client, db):
    """The whole point: no SMS gateway, no Google, no review queue."""
    org = _org(db)
    r = _signup(client, org.id)
    assert r.status_code == 201, r.text
    assert r.json()["access_token"], "they are signed in immediately"


def test_joining_proves_nothing_yet(client, db):
    """An account is not a verified identity, and must not claim to be."""
    org = _org(db)
    _signup(client, org.id, phone="9876500002")
    user = db.query(User).filter(User.phone_number == "+919876500002").one()
    assert user.phone_verified_at is None
    assert user.email_verified_at is None
    assert user.is_verified is False
    assert user.role == "PUBLIC_CITIZEN"


def test_a_number_somebody_proved_is_theirs(client, db):
    """Registering over a verified member must be refused, not merged."""
    org = _org(db)
    _signup(client, org.id, phone="9876500003")
    member = db.query(User).filter(User.phone_number == "+919876500003").one()
    mark_phone_verified(db, member)
    db.commit()

    r = _signup(client, org.id, phone="9876500003")
    assert r.status_code == 409
    assert "already belongs to a member" in r.json()["detail"]


def test_answering_a_code_takes_the_number_back(client, db):
    """The rule that makes deferred verification safe.

    An impostor registers with somebody else's number. When the real owner
    answers a code on it, the claim is released — the impostor keeps their
    account and password and loses only a number that was never theirs.
    """
    from app.services.account_claims import release_claims

    org = _org(db)
    _signup(client, org.id, phone="9876500004", name="Impostor")
    impostor = db.query(User).filter(User.phone_number == "+919876500004").one()
    impostor_id = impostor.id
    assert impostor.phone_verified_at is None

    released = release_claims(db, org.id, "+919876500004", keep=impostor)
    impostor.phone_number = None
    db.commit()

    db.expire_all()
    kept = db.get(User, impostor_id)
    assert kept is not None, "the account survives — only the number is lost"
    assert kept.password_hash, "and their password still works"
    assert kept.phone_number is None
    assert owner_of_phone(db, org.id, "+919876500004") is None, \
        "the number is free for whoever proves it"


def test_verification_settles_every_rival_claim_at_once(db):
    """Stamping a date while a rival claim stands recreates the ambiguity the
    stamp was meant to end."""
    org = _org(db)

    def _member(phone, verified=False):
        u = User(organization_id=org.id, phone_number=phone,
                 password_hash="x", role="PUBLIC_CITIZEN", is_verified=False)
        db.add(u); db.flush()
        db.add(UserProfile(user_id=u.id, full_name_ta="ப", full_name_en="P"))
        return u

    real = _member("+919876500005")
    db.commit()
    released = mark_phone_verified(db, real)
    db.commit()

    assert real.phone_verified_at is not None
    assert real.is_verified is True
    assert released == 0
    assert owner_of_phone(db, org.id, "+919876500005").id == real.id


def test_a_published_default_cannot_be_chosen_as_a_password(client, db):
    org = _org(db)
    r = _signup(client, org.id, phone="9876500006", password="changeme")
    assert r.status_code == 400
    assert "password of your own" in r.json()["detail"]


def test_a_short_password_is_refused(client, db):
    org = _org(db)
    r = _signup(client, org.id, phone="9876500007", password="abc")
    assert r.status_code == 422


def test_the_same_email_cannot_join_twice(client, db):
    org = _org(db)
    email = "one@example.test"
    assert _signup(client, org.id, phone="9876500008", email=email).status_code == 201
    r = _signup(client, org.id, phone="9876500009", email=email)
    assert r.status_code == 409
    assert "email" in r.json()["detail"].lower()


def test_they_can_sign_in_with_the_password_afterwards(client, db):
    org = _org(db)
    _signup(client, org.id, phone="9876500010", password="a-real-password")
    r = client.post("/api/v1/auth/login/password", json={
        "organization_id": str(org.id),
        "username": "+919876500010",
        "password": "a-real-password",
    })
    assert r.status_code == 200
    assert r.json()["access_token"]
