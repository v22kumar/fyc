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
from app.models.profile_attribute import ProfileAttribute
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


def _catalogue(client, u, org):
    r = client.get("/api/v1/profile-prompts/catalogue", headers=_h(u, org))
    assert r.status_code == 200, r.text
    return r.json()


def _unanswered(client, u, org):
    """What the app would still have to ask, in order."""
    c = _catalogue(client, u, org)
    done = set(c["answered"])
    return [q["id"] for q in c["questions"] if q["id"] not in done]


# ── The catalogue ─────────────────────────────────────────────────────────────

def test_blood_group_leads_the_catalogue(client, db):
    """Everything in the blood-donation screen depends on this one field, so the
    app should ask it before anything else."""
    org = _org(db)
    u = _member(db, org)
    assert _unanswered(client, u, org)[0] == "blood_group"


def test_a_known_blood_group_is_not_asked_for(client, db):
    """Asking for something already on file reads as not paying attention."""
    org = _org(db)
    u = _member(db, org, blood_group="O+")
    assert "blood_group" not in _unanswered(client, u, org)


def test_the_catalogue_publishes_the_cadence(client, db):
    """The app enforces the gaps, so it has to be told what they are — and they
    should be tunable without shipping a new build."""
    org = _org(db)
    c = _catalogue(client, _member(db, org), org)
    assert c["quiet_days_after_response"] >= 1
    assert c["quiet_days_after_dismiss"] > c["quiet_days_after_response"]
    assert c["max_dismissals"] >= 1


def test_an_unchanged_catalogue_costs_a_304(client, db):
    """This is fetched on app open. In the steady state it must not re-send."""
    org = _org(db)
    u = _member(db, org)
    first = client.get("/api/v1/profile-prompts/catalogue", headers=_h(u, org))
    etag = first.headers.get("etag")
    assert etag
    again = client.get("/api/v1/profile-prompts/catalogue",
                       headers={**_h(u, org), "If-None-Match": etag})
    assert again.status_code == 304


def test_answering_changes_the_etag(client, db):
    """A stale catalogue would have the app re-asking what was just answered."""
    org = _org(db)
    u = _member(db, org)
    etag = client.get("/api/v1/profile-prompts/catalogue",
                      headers=_h(u, org)).headers["etag"]
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "A+"},
                headers=_h(u, org))
    after = client.get("/api/v1/profile-prompts/catalogue",
                       headers={**_h(u, org), "If-None-Match": etag})
    assert after.status_code == 200


def test_one_members_answers_never_leak_into_anothers_catalogue(client, db):
    org = _org(db)
    a = _member(db, org, phone="9400000002")
    b = _member(db, org, phone="9400000003")
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "O-"},
                headers=_h(a, org))
    assert "blood_group" in _unanswered(client, b, org)


# ── Answers ───────────────────────────────────────────────────────────────────

def test_an_answer_lands_on_the_profile_where_features_query_it(client, db):
    org = _org(db)
    u = _member(db, org)
    r = client.post("/api/v1/profile-prompts/answer",
                    json={"question_id": "blood_group", "answer": "B+"},
                    headers=_h(u, org))
    assert r.status_code == 204, r.text
    db.expire_all()
    profile = db.query(UserProfile).filter(UserProfile.user_id == u.id).first()
    assert profile.blood_group == "B+"


def test_every_answer_also_lands_in_the_attribute_store(client, db):
    """The store is what makes the profile expandable: a new question is a new
    row here, never a migration."""
    org = _org(db)
    u = _member(db, org)
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "education", "answer": "graduate"},
                headers=_h(u, org))
    attr = db.query(ProfileAttribute).filter(
        ProfileAttribute.user_id == u.id).first()
    assert attr.key == "education"
    assert attr.value == "graduate"
    assert attr.answered_at is not None


def test_answering_again_updates_rather_than_duplicates(client, db):
    org = _org(db)
    u = _member(db, org)
    for v in ("school", "graduate"):
        client.post("/api/v1/profile-prompts/answer",
                    json={"question_id": "education", "answer": v},
                    headers=_h(u, org))
    rows = db.query(ProfileAttribute).filter(
        ProfileAttribute.user_id == u.id).all()
    assert len(rows) == 1
    assert rows[0].value == "graduate"


def test_dont_know_is_remembered_but_never_written_as_a_blood_group(client, db):
    """A real answer — it stops us asking — but not a blood group, and a donor
    search must never match on it."""
    org = _org(db)
    u = _member(db, org)
    client.post("/api/v1/profile-prompts/answer",
                json={"question_id": "blood_group", "answer": "dont_know"},
                headers=_h(u, org))
    db.expire_all()
    assert db.query(UserProfile).filter(
        UserProfile.user_id == u.id).first().blood_group is None
    assert "blood_group" not in _unanswered(client, u, org)


def test_an_invented_answer_is_rejected(client, db):
    org = _org(db)
    u = _member(db, org)
    r = client.post("/api/v1/profile-prompts/answer",
                    json={"question_id": "blood_group", "answer": "Z+"},
                    headers=_h(u, org))
    assert r.status_code == 400


def test_a_dismissal_is_remembered_across_a_reinstall(client, db):
    """The app holds the fortnight itself, but its memory dies with the install.
    The count has to survive, or someone who pushed a question away three times
    would be asked again by a fresh phone."""
    org = _org(db)
    u = _member(db, org)
    for _ in range(2):
        client.post("/api/v1/profile-prompts/dismiss",
                    json={"question_id": "blood_group", "answer": "-"},
                    headers=_h(u, org))
    state = db.query(ProfilePromptState).filter(
        ProfilePromptState.user_id == u.id).first()
    assert state.dismiss_count == 2
