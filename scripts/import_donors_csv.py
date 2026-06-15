#!/usr/bin/env python3
"""
Import blood donors from friends2support_donors.csv into the FYC database.
Run AFTER scrape_friends2support.py has produced the CSV.

Usage (inside Docker):
  docker compose exec api python scripts/import_donors_csv.py

Or directly:
  python scripts/import_donors_csv.py --csv scripts/friends2support_donors.csv
"""

import csv
import os
import sys
import uuid
import argparse
from pathlib import Path

# Allow running both inside and outside Docker
sys.path.insert(0, str(Path(__file__).parent.parent))

os.environ.setdefault("DATABASE_URL", "postgresql://fyc:fyc_pass@db:5432/fycdb")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.models import Base
from app.models.user import User, UserProfile
from app.models.blood_donor import BloodDonor
from app.models.tenant import Organization

DATABASE_URL = os.environ["DATABASE_URL"]
DEFAULT_ORG_ID = os.environ.get("DEFAULT_ORG_ID", "8f8b80b7-4b71-4770-b183-5c5f49e49a1d")

VALID_BLOOD_GROUPS = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}


def normalise_phone(raw: str) -> str:
    digits = "".join(c for c in raw if c.isdigit())
    if len(digits) == 10:
        return f"+91{digits}"
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"
    return f"+91{digits[-10:]}" if len(digits) > 10 else raw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", default=str(Path(__file__).parent / "friends2support_donors.csv"))
    parser.add_argument("--dry-run", action="store_true", help="Parse only, don't write to DB")
    args = parser.parse_args()

    csv_path = Path(args.csv)
    if not csv_path.exists():
        print(f"CSV not found: {csv_path}")
        print("Run scrape_friends2support.py first.")
        sys.exit(1)

    engine = create_engine(DATABASE_URL)

    with open(csv_path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    print(f"Loaded {len(rows)} rows from {csv_path}")
    if args.dry_run:
        print("[DRY RUN] No database writes.")

    created = skipped = errors = 0

    with Session(engine) as db:
        org = db.get(Organization, DEFAULT_ORG_ID)
        if not org and not args.dry_run:
            print(f"Organisation {DEFAULT_ORG_ID} not found. Run migrations first.")
            sys.exit(1)

        for i, row in enumerate(rows):
            name = row.get("name", "").strip()
            phone_raw = row.get("phone", "").strip()
            blood_group = row.get("blood_group", "O+").strip()
            city = row.get("city", "").strip()
            available_raw = row.get("available", "True")
            available = str(available_raw).lower() in ("true", "yes", "1", "available")

            if blood_group not in VALID_BLOOD_GROUPS:
                blood_group = "O+"

            phone = normalise_phone(phone_raw) if phone_raw else None

            if not phone:
                skipped += 1
                continue

            if args.dry_run:
                print(f"  [{i+1}] {name} | {blood_group} | {phone} | {city}")
                created += 1
                continue

            # Skip if phone already in DB
            if phone:
                existing = db.query(User).filter_by(phone_number=phone, organization_id=DEFAULT_ORG_ID).first()
                if existing:
                    skipped += 1
                    continue

            try:
                user_id = uuid.uuid4()
                display_name = name or f"f2s_{user_id.hex[:8]}"
                user = User(
                    id=user_id,
                    organization_id=DEFAULT_ORG_ID,
                    phone_number=phone,
                    role="PUBLIC_CITIZEN",
                    is_verified=False,
                )
                db.add(user)
                db.flush()

                profile = UserProfile(
                    user_id=user_id,
                    full_name_en=display_name,
                    full_name_ta=display_name,
                    address_line_en=city or "",
                    address_line_ta=city or "",
                )
                db.add(profile)

                donor = BloodDonor(
                    id=uuid.uuid4(),
                    user_id=user_id,
                    organization_id=DEFAULT_ORG_ID,
                    blood_group=blood_group,
                    is_available=available,
                    last_donation_date=None,
                )
                db.add(donor)
                created += 1

            except Exception as e:
                db.rollback()
                errors += 1
                print(f"  Error row {i+1} ({name}): {e}")
                continue

        if not args.dry_run:
            db.commit()

    print(f"\nDone: {created} created, {skipped} skipped (duplicate phone), {errors} errors")


if __name__ == "__main__":
    main()
