"""Drip questions.

Registration stays short on purpose, which leaves the fields the app needs —
blood group first — empty for almost everybody. So we ask afterwards, one
question at a time, days apart.

The whole feature is its restraint. These tests are mostly about when we must
NOT ask, because a version that asks too often is worse than not asking at all:
it turns into the form we were avoiding.
"""
import uuid
from datetime import datetime, timedelta, timezone

from app.core.security import create_access_token, get_password_hash
from app.models.profile_prompt import ProfilePromptState
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}",
                       name_ta="x", name_en="x")
    db.add(org)
    db.commit()
    return org


def _member(db, org, phone="9400000001", blood_group=None):
    u = User(organization_id=org.id, phone_number=phone,
             password_hash=get_password_hash("x"), role="USER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en="M", full_name_ta="M",
                       blood_group=blood_group))
    db.commit()
    return u


def _h(u, org):
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(org.id))}",
        "X-Organization-ID": str(org.id),
    }


def _ask(client, u, org):
    r = client.get("/api/v1/profile-prompts/next", headers=_h(u, org))
    assert r.status_code == 200, r.text
    return r.json()


# ── What we ask, and in what order ────────────────────────────────────────────

def test_the_first_question_is_blood_group(client, db):
    """Everything in the blood-donation screen depends on this one field, so it
    goes first. Nothing else is worth asking until it is answered."""
    org = _org(db)
    u = _member(db, org)
    assert _ask(client, u, org)["id"] == "blood_group"


def test_a_known_blood_group_is_never_asked_for(client, db):
    """Asking for something already on file reads as not paying attention."""
    org = _org(db)
    u = _member(db, org, blood_group="O+")
    assert _ask(client, u, org)["id"] != "blood_group"


def test_an_answer_lands_on_the_profile_where_the_app_reads_it(client, db):
    org = _org(db)
    u = _member(db, org)
    r = client.post("/api/v1/profile-prompts/answer",
                    json={"question_id": "blood_group", "answer": "B+"},
                    headers=_h(u, org))
    assert r.status_code == 204, r.text
    db.expire_all()
    profile = db.query(UserProfile).filter(UserProfile.user_id == u.id).first()
    assert profile.blood_group == "B+"


def test_dont_know_is_recorded_but_never_written_as_a_blood_group(client, db):
    """"I don't know mine" is a real answer — it stops us asking again — but it
    is not a blood group, and a donor search must never match on it."""
    org = _org(db)
    u = _member(db, org)
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "dont_know"},
                headers=_h(u, org))
    db.expire_all()
    profile = db.query(UserProfile).filter(UserProfile.user_id == u.id).first()
    assert profile.blood_group is None
    state = db.query(ProfilePromptState).filter(
        ProfilePromptState.user_id == u.id).first()
    assert state.answer == "dont_know"
    assert state.answered_at is not None


def test_an_invented_answer_is_rejected(client, db):
    org = _org(db)
    u = _member(db, org)
    r = client.post("/api/v1/profile-prompts/answer",
                    json={"question_id": "blood_group", "answer": "Z+"},
                    headers=_h(u, org))
    assert r.status_code == 400


# ── When we must not ask ──────────────────────────────────────────────────────

def test_nobody_is_asked_twice_in_the_same_breath(client, db):
    """Answer today, hear nothing tomorrow. This is the rule that keeps it from
    becoming the signup form we deliberately kept short."""
    org = _org(db)
    u = _member(db, org)
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "A+"},
                headers=_h(u, org))
    assert _ask(client, u, org) is None


def test_the_quiet_period_ends(client, db):
    org = _org(db)
    u = _member(db, org)
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "A+"},
                headers=_h(u, org))
    state = db.query(ProfilePromptState).filter(
        ProfilePromptState.user_id == u.id).first()
    state.answered_at = datetime.now(timezone.utc) - timedelta(days=5)
    db.commit()
    nxt = _ask(client, u, org)
    assert nxt is not None
    assert nxt["id"] != "blood_group"  # answered; moved on


def test_a_dismissed_question_goes_to_the_back_not_away(client, db):
    """Dismissing has to be free, or the card becomes a demand."""
    org = _org(db)
    u = _member(db, org)
    r = client.post("/api/v1/profile-prompts/dismiss",
                    json={"question_id": "blood_group", "answer": "-"},
                    headers=_h(u, org))
    assert r.status_code == 204
    assert _ask(client, u, org) is None  # quiet straight after

    state = db.query(ProfilePromptState).filter(
        ProfilePromptState.user_id == u.id).first()
    state.dismissed_at = datetime.now(timezone.utc) - timedelta(days=30)
    db.commit()
    assert _ask(client, u, org)["id"] == "blood_group"  # offered again later


def test_three_dismissals_and_we_take_the_hint(client, db):
    org = _org(db)
    u = _member(db, org)
    for _ in range(3):
        client.post("/api/v1/profile-prompts/dismiss",
                    json={"question_id": "blood_group", "answer": "-"},
                    headers=_h(u, org))
        state = db.query(ProfilePromptState).filter(
            ProfilePromptState.user_id == u.id).first()
        state.dismissed_at = datetime.now(timezone.utc) - timedelta(days=30)
        db.commit()
    nxt = _ask(client, u, org)
    assert nxt is None or nxt["id"] != "blood_group"


def test_the_same_card_is_not_shown_again_the_same_day(client, db):
    """A member who neither answers nor dismisses is not nagged every session."""
    org = _org(db)
    u = _member(db, org)
    first = _ask(client, u, org)
    assert first["id"] == "blood_group"
    assert _ask(client, u, org) is None


def test_a_fully_answered_member_is_left_alone(client, db):
    org = _org(db)
    u = _member(db, org)
    from app.services.profile_questions import CATALOGUE
    for q in CATALOGUE:
        state = ProfilePromptState(
            organization_id=org.id, user_id=u.id, question_id=q.id,
            answered_at=datetime.now(timezone.utc) - timedelta(days=40),
            answer="x")
        db.add(state)
    db.commit()
    assert _ask(client, u, org) is None


def test_questions_are_private_to_the_member(client, db):
    """One member's answers must never influence another's prompts."""
    org = _org(db)
    a = _member(db, org, phone="9400000002")
    b = _member(db, org, phone="9400000003")
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "O-"},
                headers=_h(a, org))
    assert _ask(client, b, org)["id"] == "blood_group"
