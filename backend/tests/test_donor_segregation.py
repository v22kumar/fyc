"""Imported Friends2Support donors (User rows created donor-only) carry
source='F2S_IMPORT' and must be kept out of member/opponent lists like the chess
members list — while real users (source NULL), including a real member who is
also a donor, still appear.
"""
import uuid

from tests.test_cricket_scoring import _make_org, _make_exec, _login, _h


def test_chess_members_excludes_imported_f2s_donors(client, db):
    from app.models.user import User, UserProfile
    from app.models.blood_donor import BloodDonor

    org = _make_org(db)
    _make_exec(db, org.id, "9500000201")  # the caller (a real member)
    tok = _login(client, org.id, "9500000201")
    H = _h(org.id, tok)

    # A real self-registered member — must appear as a chess opponent.
    real = User(id=uuid.uuid4(), organization_id=org.id, phone_number="9500000202",
                role="CLUB_MEMBER", is_verified=True)
    db.add(real)
    db.flush()
    db.add(UserProfile(user_id=real.id, full_name_en="Real Member", full_name_ta="Real Member"))

    # An imported Friends2Support donor — a directory contact, NOT a real user.
    donor = User(id=uuid.uuid4(), organization_id=org.id, phone_number="9500000203",
                 role="PUBLIC_CITIZEN", is_verified=True, source="F2S_IMPORT")
    db.add(donor)
    db.flush()
    db.add(UserProfile(user_id=donor.id, full_name_en="Imported Donor", full_name_ta="Imported Donor"))
    db.add(BloodDonor(id=uuid.uuid4(), organization_id=org.id, user_id=donor.id,
                      blood_group="O+", is_available=True))
    db.commit()

    r = client.get("/api/v1/chess/members", headers=H)
    assert r.status_code == 200, r.text
    names = {m["name"] for m in r.json()}
    assert "Real Member" in names           # real users still listed
    assert "Imported Donor" not in names    # imported donor contacts filtered out
