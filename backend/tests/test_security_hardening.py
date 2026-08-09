"""The three doors the security review found ajar, now with alarms.

1. A verification_id used to survive wrong OTP guesses for its whole
   10-minute TTL — a stable target for grinding the 6-digit space. Now a
   handful of wrong codes destroys it.
2. `require_exec` proves you are an exec of *your* org, not that the fixture
   you are scoring is yours. The cricket mutations now resolve fixtures only
   within the caller's organization.
3. An upload's Content-Type header is the client's claim; the first bytes
   are the file's own. The two must agree.
"""
import io
import uuid

from app.core.security import get_password_hash
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _make_org(db, slug_prefix="sec"):
    org = Organization(id=uuid.uuid4(), slug=f"{slug_prefix}-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _make_exec(db, org_id, phone):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"),
             role="EXECUTIVE_MEMBER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta="நிர்வாகி", full_name_en="Organizer"))
    db.commit()
    return u


def _login(client, org_id, phone):
    r = client.post("/api/v1/auth/login/password",
                    json={"organization_id": str(org_id),
                          "username": phone, "password": "pass"})
    return r.json()["access_token"]


def _h(org_id, token):
    return {"Authorization": f"Bearer {token}", "X-Organization-ID": str(org_id)}


# ── 1 · OTP guessing burns the verification, not just the guess ───────────────

def _send_otp(client, db, phone):
    org = _make_org(db, "otp")
    r = client.post("/api/v1/auth/otp/send",
                    json={"phone_number": phone,
                          "organization_id": str(org.id)})
    assert r.status_code == 200
    return org, r.json()["verification_id"]


def test_five_wrong_codes_destroy_the_verification(client, db):
    _, vid = _send_otp(client, db, "9600000001")

    for i in range(4):
        r = client.post("/api/v1/auth/otp/verify",
                        json={"verification_id": vid, "otp_code": "000001"})
        assert r.status_code == 400
        assert r.json()["detail"] == "Invalid OTP code"

    # The fifth wrong guess kills the id itself.
    r = client.post("/api/v1/auth/otp/verify",
                    json={"verification_id": vid, "otp_code": "000001"})
    assert r.status_code == 400
    assert "Too many wrong codes" in r.json()["detail"]

    # Even the RIGHT code is now useless — the attacker cannot keep the
    # window open by pacing their guesses.
    r = client.post("/api/v1/auth/otp/verify",
                    json={"verification_id": vid, "otp_code": "123456"})
    assert r.status_code == 400
    assert "Invalid or expired verification ID" in r.json()["detail"]


def test_the_right_code_still_works_before_the_limit(client, db):
    """The lock must not catch the member who fat-fingers the code twice."""
    _, vid = _send_otp(client, db, "9600000002")

    for _ in range(2):
        client.post("/api/v1/auth/otp/verify",
                    json={"verification_id": vid, "otp_code": "999999"})

    r = client.post("/api/v1/auth/otp/verify",
                    json={"verification_id": vid, "otp_code": "123456"})
    assert r.status_code == 200


# ── 2 · Cricket scoring stops at the organization boundary ────────────────────

def _cricket_fixture(client, db):
    """Org A with a scorable fixture, following the real organizer flow."""
    org = _make_org(db, "crk")
    _make_exec(db, org.id, "9600000010")
    tok = _login(client, org.id, "9600000010")
    H = _h(org.id, tok)

    tid = client.post("/api/v1/sports/tournaments", json={
        "name_ta": "கிரிக்கெட்", "name_en": "Cricket",
        "sport": "cricket", "year": 2026, "format": "LEAGUE",
    }, headers=H).json()["id"]
    team_ids = []
    for name in ("Eagles", "Phoenix"):
        tr = client.post(f"/api/v1/sports/tournaments/{tid}/teams",
                         json={"name": name, "captain_name": f"{name} Cap",
                               "contact_phone": None, "is_fyc_team": False},
                         headers=H)
        team_ids.append(tr.json()["id"])
        client.patch(
            f"/api/v1/sports/tournaments/{tid}/teams/{tr.json()['id']}/status",
            json={"status": "APPROVED"}, headers=H)
    client.post(f"/api/v1/sports/tournaments/{tid}/close-registration", headers=H)
    fid = client.post(f"/api/v1/sports/tournaments/{tid}/generate-fixtures",
                      headers=H).json()[0]["id"]

    init = client.post(f"/api/v1/fixtures/{fid}/cricket/init", json={
        "toss_winner_id": team_ids[0], "toss_decision": "BAT", "overs": 20,
        "striker_name": "Kumar", "non_striker_name": "Raj",
        "bowler_name": "Vel",
    }, headers=H)
    return H, fid, init.json()["current_players"]


def _foreign_exec_headers(client, db):
    org_b = _make_org(db, "crk-b")
    _make_exec(db, org_b.id, "9600000011")
    return _h(org_b.id, _login(client, org_b.id, "9600000011"))


def test_an_exec_of_another_org_cannot_touch_the_match(client, db):
    _, fid, p = _cricket_fixture(client, db)
    foreign = _foreign_exec_headers(client, db)

    # A structurally valid delivery — the player ids are readable off the
    # public scoreboard, so the attacker can produce one.
    ball = {"striker_id": p["striker_id"],
            "non_striker_id": p["non_striker_id"],
            "bowler_id": p["bowler_id"],
            "runs_batter": 4, "is_wicket": False}
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball",
                    json=ball, headers=foreign)
    # The match must be invisible, exactly as if the id were unknown.
    assert r.status_code == 400
    assert r.json()["code"] == "MATCH_SETUP_INCOMPLETE"

    assert client.post(f"/api/v1/fixtures/{fid}/cricket/undo",
                       headers=foreign).status_code == 404
    assert client.post(f"/api/v1/fixtures/{fid}/cricket/second-innings",
                       json={"toss_winner_id": str(uuid.uuid4()),
                             "toss_decision": "BAT", "overs": 20,
                             "striker_name": "A", "non_striker_name": "B",
                             "bowler_name": "C"},
                       headers=foreign).status_code == 404


def test_an_exec_of_another_org_cannot_init_the_fixture(client, db):
    H, fid, _p = _cricket_fixture(client, db)
    foreign = _foreign_exec_headers(client, db)
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/init", json={
        "toss_winner_id": str(uuid.uuid4()), "toss_decision": "BAT",
        "overs": 20, "striker_name": "X", "non_striker_name": "Y",
        "bowler_name": "Z",
    }, headers=foreign)
    assert r.status_code == 404


def test_the_home_org_still_scores_normally(client, db):
    """The gate keeps strangers out, not the scorer."""
    H, fid, p = _cricket_fixture(client, db)
    r = client.post(f"/api/v1/fixtures/{fid}/cricket/ball",
                    json={"striker_id": p["striker_id"],
                          "non_striker_id": p["non_striker_id"],
                          "bowler_id": p["bowler_id"],
                          "runs_batter": 4, "is_wicket": False},
                    headers=H)
    assert r.status_code == 200
    assert client.post(f"/api/v1/fixtures/{fid}/cricket/undo",
                       headers=H).status_code == 200


# ── 3 · The file's first bytes must match its claimed type ────────────────────

def test_a_fake_jpeg_is_refused(client, db):
    org = _make_org(db, "med")
    _make_exec(db, org.id, "9600000020")
    tok = _login(client, org.id, "9600000020")

    not_an_image = io.BytesIO(b"<script>alert(1)</script>" + b"\x00" * 100)
    r = client.post(
        "/api/v1/media/upload",
        files={"file": ("photo.jpg", not_an_image, "image/jpeg")},
        headers=_h(org.id, tok),
    )
    assert r.status_code == 415
