"""Importing the club's membership form.

Eleven people filled in a Google Form. Three answers came back unusable — a
blood group reading "Column 1", a blank one, and a date of birth that would
make that member four months old. None of them is a parsing problem. They parse
fine, which is precisely why they need catching.

The club has since supplied the real values. They live in a corrections table
rather than being edited into the CSV, so the file stays the record of what
people actually typed and the difference between the two is still readable.
"""
import uuid
from datetime import date

from app.models.finance import FinanceCampaign, FinanceCampaignAssignment
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from seeds.import_club_members import (SOURCE, clean_blood_group,
                                       ensure_treasurers, import_members,
                                       normalise_phone, parse_birthday,
                                       read_rows)


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"m-{uuid.uuid4().hex[:6]}",
                       name_ta="அ", name_en="Friends Youth Club")
    db.add(org)
    db.commit()
    return org


# ── Cleaning ────────────────────────────────────────────────────────────────

def test_a_phone_is_the_same_phone_however_it_was_typed():
    """The form accepted both spellings. Stored as typed, the same person would
    not match their own row when they later sign in."""
    assert normalise_phone("9600458044") == "+919600458044"
    assert normalise_phone("+91 7708501420") == "+917708501420"
    assert normalise_phone("  0 9003671311 ") == "+919003671311"
    assert normalise_phone("12345") is None
    assert normalise_phone("") is None


def test_the_spreadsheets_own_column_header_is_not_a_blood_group():
    """One row's blood group reads "Column 1". Kept, it would put that member
    in a search for a group they never gave."""
    assert clean_blood_group("Column 1") is None
    assert clean_blood_group("") is None
    assert clean_blood_group("o+") == "O+"
    assert clean_blood_group("AB -") == "AB-", "a stray space is not a bad answer"
    assert clean_blood_group("B+") == "B+"


def test_a_date_that_makes_a_member_four_months_old_is_not_a_birthday():
    """One row says 2026-03-21 — five months ago, not in the future, and it
    parses perfectly. That is exactly why it needs catching: the club sends
    birthday wishes off this field, so an impossible date is a greeting on the
    wrong day, every year, to somebody unlikely to mention it."""
    today = date(2026, 8, 12)
    assert parse_birthday("1987-06-10", today=today) == date(1987, 6, 10)
    assert parse_birthday("2026-03-21", today=today) is None
    assert parse_birthday("2007-08-31", today=today) == date(2007, 8, 31), (
        "the youngest real member on the form is eighteen and must survive")
    assert parse_birthday("1850-01-01", today=today) is None
    assert parse_birthday("", today=today) is None
    assert parse_birthday("not a date", today=today) is None


def test_every_member_ends_up_with_both_fields(client, db):
    """After the corrections there are no gaps left to chase."""
    org = _org(db)
    import_members(db, org)

    profiles = (db.query(UserProfile).join(User, User.id == UserProfile.user_id)
                  .filter(User.organization_id == org.id).all())
    assert len(profiles) == 11
    assert all(p.blood_group for p in profiles)
    assert all(p.date_of_birth for p in profiles)


def test_the_committed_csv_is_the_one_the_club_submitted():
    """Read from the real file, not a fixture — a change to it should be
    visible here."""
    rows = read_rows()
    assert len(rows) == 11
    names = {r["name"] for r in rows}
    assert "Ratheesh R" in names
    assert "John" in names, "trailing space in the form value must be trimmed"
    assert all(r["phone"].startswith("+91") for r in rows if r["phone"])


# ── Importing ───────────────────────────────────────────────────────────────

def test_everyone_on_the_form_becomes_a_club_member(client, db):
    org = _org(db)
    report = import_members(db, org)

    assert report["created"] == 11
    people = db.query(User).filter(User.organization_id == org.id).all()
    assert len(people) == 11
    assert {p.role for p in people} == {"CLUB_MEMBER"}, (
        "PUBLIC_CITIZEN is excluded from the roster the finance screens search")
    assert {p.source for p in people} == {SOURCE}


def test_they_appear_in_the_roster_a_treasurer_searches(client, db):
    """The whole point of importing them as members rather than users."""
    from app.core.security import create_access_token
    org = _org(db)
    import_members(db, org)

    admin = User(organization_id=org.id, phone_number="+919888899999",
                 role="ADMIN", is_verified=True)
    db.add(admin)
    db.flush()
    db.add(UserProfile(user_id=admin.id, full_name_en="Admin", full_name_ta="Admin"))
    db.commit()

    token = create_access_token(subject=admin.id, role=admin.role,
                                organization_id=str(org.id))
    roster = client.get("/api/v1/users/roster", headers={
        "Authorization": f"Bearer {token}",
        "X-Organization-ID": str(org.id),
    }).json()

    names = {m["full_name_en"] for m in roster}
    assert "Sajin Raj" in names
    assert "R.Alexander" in names


def test_the_clubs_corrections_win_over_the_form(client, db):
    """The three unusable answers, replaced by what the club knows — and only
    the named fields, never the rest of the row."""
    org = _org(db)
    report = import_members(db, org)

    assert report["no_blood_group"] == [], "both blanks are now filled"
    assert report["no_birthday"] == []

    john = db.query(User).filter(User.email == "johnjothis8@gmail.com").first()
    john_profile = db.query(UserProfile).filter(UserProfile.user_id == john.id).first()
    assert john_profile.date_of_birth == date(2003, 3, 21), (
        "the form's 2026 was a date picker left on the current year")
    assert john_profile.blood_group == "B+", "his own answer stands"

    for email in ("ratheeshrtr1987@gmail.com", "vijay19rahavan@gmail.com"):
        user = db.query(User).filter(User.email == email).first()
        profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
        assert profile.blood_group == "O+"

    ratheesh = db.query(User).filter(User.email == "ratheeshrtr1987@gmail.com").first()
    r_profile = db.query(UserProfile).filter(UserProfile.user_id == ratheesh.id).first()
    assert r_profile.date_of_birth == date(1987, 6, 10), (
        "correcting his blood group must not disturb the date he got right")


def test_the_csv_still_says_what_the_form_said(client, db):
    """A correction applied on top, not edited into the record. If the two ever
    stop differing, somebody has quietly rewritten what people submitted."""
    import csv as _csv
    from seeds.import_club_members import CSV_PATH

    with open(CSV_PATH, encoding="utf-8-sig", newline="") as fh:
        raw = {r["Email"]: r for r in _csv.DictReader(fh)}

    assert raw["johnjothis8@gmail.com"]["Date of birth "] == "2026-03-21"
    assert raw["ratheeshrtr1987@gmail.com"]["Blood Group "] == "Column 1"
    assert raw["vijay19rahavan@gmail.com"]["Blood Group "] == ""


def test_running_it_again_changes_nothing(client, db):
    """It runs on every boot. A second pass must not double the club."""
    org = _org(db)
    import_members(db, org)
    second = import_members(db, org)

    assert second["created"] == 0
    assert second["unchanged"] == 11
    assert db.query(User).filter(User.organization_id == org.id).count() == 11


def test_it_does_not_overwrite_what_a_member_has_since_corrected(client, db):
    """A member who signs in and fixes their own name keeps it."""
    org = _org(db)
    import_members(db, org)

    anish = db.query(User).filter(User.email == "anishalone0@gmail.com").first()
    profile = db.query(UserProfile).filter(UserProfile.user_id == anish.id).first()
    profile.full_name_en = "Anish Kumar"
    db.commit()

    import_members(db, org)
    db.refresh(profile)
    assert profile.full_name_en == "Anish Kumar"


def test_somebody_who_already_signed_up_is_matched_not_duplicated(client, db):
    """They gave a phone at sign-in and an email on the form. One person."""
    org = _org(db)
    existing = User(organization_id=org.id, phone_number="+919952667724",
                    role="PUBLIC_CITIZEN", is_verified=True)
    db.add(existing)
    db.commit()

    report = import_members(db, org)

    assert report["created"] == 10
    assert db.query(User).filter(
        User.organization_id == org.id,
        User.phone_number == "+919952667724").count() == 1
    db.refresh(existing)
    assert existing.role == "CLUB_MEMBER", "the form says they are a member"
    assert existing.email == "johnjothis8@gmail.com", "the gap is filled"


def test_an_executive_is_not_demoted_by_a_re_run(client, db):
    """Somebody promoted since the form must not be knocked back down."""
    org = _org(db)
    import_members(db, org)

    sajin = db.query(User).filter(User.email == "sajinraj0002@gmail.com").first()
    sajin.role = "EXECUTIVE_MEMBER"
    db.commit()

    import_members(db, org)
    db.refresh(sajin)
    assert sajin.role == "EXECUTIVE_MEMBER"


def test_nobodys_phone_is_marked_verified_by_being_typed_in(client, db):
    """The club knows who they are; nobody has proved they hold the number.
    Those are different facts and the schema keeps them apart."""
    org = _org(db)
    import_members(db, org)

    for person in db.query(User).filter(User.organization_id == org.id).all():
        assert person.is_verified is True
        assert person.phone_verified_at is None


# ── The treasurer ───────────────────────────────────────────────────────────

def test_john_is_appointed_to_the_running_collection(client, db):
    org = _org(db)
    import_members(db, org)
    campaign = FinanceCampaign(
        organization_id=org.id, title_en="FYC Anniversary Celebration 2026",
        title_ta="விழா", status="ACTIVE")
    db.add(campaign)
    db.commit()

    report = ensure_treasurers(db, org)

    assert report["appointed"] == ["johnjothis8@gmail.com"]
    john = db.query(User).filter(User.email == "johnjothis8@gmail.com").first()
    assert db.query(FinanceCampaignAssignment).filter(
        FinanceCampaignAssignment.campaign_id == campaign.id,
        FinanceCampaignAssignment.user_id == john.id,
        FinanceCampaignAssignment.revoked_at.is_(None)).count() == 1


def test_appointing_him_twice_appoints_him_once(client, db):
    org = _org(db)
    import_members(db, org)
    db.add(FinanceCampaign(organization_id=org.id, title_en="A", title_ta="A",
                           status="ACTIVE"))
    db.commit()

    ensure_treasurers(db, org)
    second = ensure_treasurers(db, org)

    assert second["appointed"] == []
    assert second["already"] == ["johnjothis8@gmail.com"]
    assert db.query(FinanceCampaignAssignment).count() == 1


def test_with_no_collection_yet_it_says_so_rather_than_pretending(client, db):
    """An appointment is per campaign. There is nothing to appoint anybody to
    until the club creates one, and the report should not imply otherwise."""
    org = _org(db)
    import_members(db, org)

    report = ensure_treasurers(db, org)

    assert report["campaigns"] == 0
    assert report["appointed"] == []
    assert db.query(FinanceCampaignAssignment).count() == 0


def test_a_closed_collection_does_not_get_a_new_treasurer(client, db):
    org = _org(db)
    import_members(db, org)
    db.add(FinanceCampaign(organization_id=org.id, title_en="Last year",
                           title_ta="Last year", status="CLOSED"))
    db.commit()

    report = ensure_treasurers(db, org)
    assert report["campaigns"] == 0


def test_a_treasurer_who_is_not_in_the_club_is_reported_not_invented(client, db):
    org = _org(db)
    db.add(FinanceCampaign(organization_id=org.id, title_en="A", title_ta="A",
                           status="ACTIVE"))
    db.commit()

    report = ensure_treasurers(db, org, emails=("nobody@example.com",))

    assert report["not_found"] == ["nobody@example.com"]
    assert db.query(FinanceCampaignAssignment).count() == 0
