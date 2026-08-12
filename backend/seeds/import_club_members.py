"""The people who filled in the club's membership form, as members.

They are not app users who happened to sign up. They wrote their names on a
form the club circulated, so the club already knows who they are — the app is
just catching up. That distinction decides everything below:

* **`role="CLUB_MEMBER"`, not `PUBLIC_CITIZEN`.** The member roster excludes
  public citizens, and the roster is what the finance screens search when a
  treasurer types a name. A person imported as a public citizen would be in the
  database and invisible to the one screen that needs them.

* **`is_verified=True`, `phone_verified_at` left NULL.** These are different
  facts and the schema keeps them apart deliberately. The club has confirmed
  who this person is; nobody has yet proved they hold that phone. The first one
  is what makes them a member, the second is what an OTP is for.

* **`source="MEMBER_FORM"`.** Provenance, so a later question — "who did we
  type in, and who signed themselves up?" — has an answer. Every existing
  filter on this column tests for `F2S_IMPORT` specifically, so tagging these
  rows keeps them in member lists, search, and opponent pickers, unlike the
  donor import which is deliberately kept out.

Idempotent: matched on email first, then phone. Re-running changes nothing, and
it never overwrites something a member has since set for themselves — if they
sign in and correct their own name, the next boot leaves it alone.
"""
from __future__ import annotations

import csv
import logging
import os
import re
import uuid
from datetime import date, datetime

from sqlalchemy.orm import Session

from app.models.tenant import Organization
from app.models.user import User, UserProfile

logger = logging.getLogger(__name__)

CSV_PATH = os.path.join(os.path.dirname(__file__), "club_members.csv")

# What this import writes into `users.source`.
SOURCE = "MEMBER_FORM"

# The eight real blood groups. The form let people type anything, and one row
# came back with the spreadsheet's own column header in it.
BLOOD_GROUPS = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}

_DIGITS = re.compile(r"\D+")


def normalise_phone(raw: str | None) -> str | None:
    """+91 followed by ten digits, however it was typed.

    The form took "9600458044" and "+91 7708501420" without complaint. Stored
    unnormalised, the same person signing in later would not match their own
    row, and the club would have two of them.
    """
    digits = _DIGITS.sub("", raw or "")
    if len(digits) < 10:
        return None
    return "+91" + digits[-10:]


def clean_blood_group(raw: str | None) -> str | None:
    """A real group, or nothing. Never a guess."""
    value = (raw or "").strip().upper().replace(" ", "")
    return value if value in BLOOD_GROUPS else None


# Nobody four months old fills in a membership form, and nobody is 130. A date
# outside this band is a typo, not a birthday — and the usual one is a date
# picker that opened on the current year and was never moved off it.
MIN_MEMBER_AGE_YEARS = 5
MAX_MEMBER_AGE_YEARS = 120


def parse_birthday(raw: str | None, *, today: date | None = None) -> date | None:
    """A date of birth, if it can be one.

    One row says 2026-03-21, which would make that member four months old. It
    parses perfectly — that is the problem. The club sends birthday wishes off
    this field, so an impossible date is not a harmless oddity: it is a
    greeting on the wrong day, every year, to somebody who is unlikely to
    mention it.

    The real year is not guessable from a wrong one, so nothing is repaired
    here. The date is dropped and the name reported, and somebody can ask him.
    """
    text = (raw or "").strip()
    if not text:
        return None
    try:
        parsed = datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        return None

    today = today or date.today()
    age = today.year - parsed.year - ((today.month, today.day) < (parsed.month, parsed.day))
    if not (MIN_MEMBER_AGE_YEARS <= age <= MAX_MEMBER_AGE_YEARS):
        return None
    return parsed


def read_rows(path: str = CSV_PATH) -> list[dict]:
    """The form's own export, cleaned on the way in.

    The file is committed exactly as it was downloaded — it is the record of
    what people actually submitted — and every correction happens here, where
    it can be read and tested.
    """
    if not os.path.exists(path):
        return []
    out = []
    with open(path, encoding="utf-8-sig", newline="") as fh:
        for raw in csv.DictReader(fh):
            # The form's column names carry trailing spaces. Normalise the keys
            # rather than depending on them.
            row = {(k or "").strip(): (v or "").strip() for k, v in raw.items()}
            name = " ".join(row.get("Name", "").split())
            email = row.get("Email", "").strip().lower() or None
            phone = normalise_phone(row.get("Phone number"))
            if not name or not (email or phone):
                continue      # nothing to identify them by
            out.append({
                "name": name[:150],
                "email": email,
                "phone": phone,
                "blood_group": clean_blood_group(row.get("Blood Group")),
                "date_of_birth": parse_birthday(row.get("Date of birth")),
            })
    return out


def _existing(db: Session, org_id, row: dict) -> User | None:
    """This person, if the database already has them.

    Email first: it is the field people type correctly. Phone second, because
    a member who signed in with an OTP before this import ran has a phone and
    may have no email at all.
    """
    if row["email"]:
        found = db.query(User).filter(
            User.organization_id == org_id,
            User.email == row["email"],
        ).first()
        if found:
            return found
    if row["phone"]:
        return db.query(User).filter(
            User.organization_id == org_id,
            User.phone_number == row["phone"],
        ).first()
    return None


# Roles this import must never touch. Somebody who has since become an
# executive is not demoted back to an ordinary member by a re-run.
_SENIOR = ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN")


def import_members(db: Session, org: Organization, *,
                   path: str = CSV_PATH) -> dict:
    """Create or top up the club's members. Returns a small report."""
    report = {"created": 0, "updated": 0, "unchanged": 0,
              "no_birthday": [], "no_blood_group": []}

    for row in read_rows(path):
        if row["date_of_birth"] is None:
            report["no_birthday"].append(row["name"])
        if row["blood_group"] is None:
            report["no_blood_group"].append(row["name"])

        user = _existing(db, org.id, row)

        if user is None:
            user = User(
                id=uuid.uuid4(),
                organization_id=org.id,
                email=row["email"],
                phone_number=row["phone"],
                role="CLUB_MEMBER",
                # The club knows who they are. Whether they hold that phone is
                # a separate question, and phone_verified_at stays NULL until
                # an OTP answers it.
                is_verified=True,
                source=SOURCE,
                preferred_language="ta",
            )
            db.add(user)
            db.flush()
            db.add(UserProfile(
                user_id=user.id,
                full_name_en=row["name"],
                full_name_ta=row["name"],
                blood_group=row["blood_group"],
                date_of_birth=row["date_of_birth"],
            ))
            report["created"] += 1
            continue

        # They already exist — from an earlier run, or because they signed
        # themselves up. Fill gaps; overwrite nothing.
        touched = False
        if (user.role or "PUBLIC_CITIZEN") not in _SENIOR and user.role != "CLUB_MEMBER":
            user.role = "CLUB_MEMBER"
            touched = True
        if not user.email and row["email"]:
            user.email = row["email"]
            touched = True
        if not user.phone_number and row["phone"]:
            user.phone_number = row["phone"]
            touched = True

        profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
        if profile is None:
            db.add(UserProfile(
                user_id=user.id,
                full_name_en=row["name"],
                full_name_ta=row["name"],
                blood_group=row["blood_group"],
                date_of_birth=row["date_of_birth"],
            ))
            touched = True
        else:
            if not profile.blood_group and row["blood_group"]:
                profile.blood_group = row["blood_group"]
                touched = True
            if not profile.date_of_birth and row["date_of_birth"]:
                profile.date_of_birth = row["date_of_birth"]
                touched = True

        report["updated" if touched else "unchanged"] += 1

    db.commit()
    return report


# ── The club's treasurer ─────────────────────────────────────────────────────
#
# Named by email, not by the name on the form. The form row reads "John " with
# no surname; the email says johnjothis8@gmail.com. An email is the field
# people type correctly and the one that stays the same when somebody fixes
# their own name later.
TREASURER_EMAILS = ("johnjothis8@gmail.com",)


def ensure_treasurers(db: Session, org: Organization, *,
                      emails: tuple[str, ...] = TREASURER_EMAILS) -> dict:
    """Appoint the club's treasurers to every collection that is running.

    An appointment is per campaign — that is the whole point of it, so being
    trusted with this year's anniversary does not silently carry into every
    future collection. The consequence is that this can only appoint somebody
    to a campaign that already exists: if the club has not created the
    collection yet, there is nothing to appoint them to, and the report says so
    rather than pretending it worked.
    """
    from app.models.finance import FinanceCampaign, FinanceCampaignAssignment

    report = {"appointed": [], "already": [], "not_found": [], "campaigns": 0}

    campaigns = db.query(FinanceCampaign).filter(
        FinanceCampaign.organization_id == org.id,
        FinanceCampaign.status == "ACTIVE",
        FinanceCampaign.deleted_at.is_(None),
    ).all()
    report["campaigns"] = len(campaigns)
    if not campaigns:
        return report

    for email in emails:
        user = db.query(User).filter(
            User.organization_id == org.id,
            User.email == email.lower(),
        ).first()
        if user is None:
            report["not_found"].append(email)
            continue

        for campaign in campaigns:
            live = db.query(FinanceCampaignAssignment).filter(
                FinanceCampaignAssignment.campaign_id == campaign.id,
                FinanceCampaignAssignment.user_id == user.id,
                FinanceCampaignAssignment.revoked_at.is_(None),
            ).first()
            if live:
                report["already"].append(email)
                continue
            db.add(FinanceCampaignAssignment(
                campaign_id=campaign.id,
                user_id=user.id,
                capacity="TREASURER",
            ))
            report["appointed"].append(email)

    db.commit()
    return report


def main() -> None:
    """Run standalone: `python -m seeds.import_club_members` from backend/."""
    import sys
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
    from app.core.database import SessionLocal

    db = SessionLocal()
    try:
        org = db.query(Organization).first()
        if org is None:
            print("No organisation yet — nothing to import into.")
            return
        members = import_members(db, org)
        treasurers = ensure_treasurers(db, org)
        print(f"members: {members}")
        print(f"treasurers: {treasurers}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
