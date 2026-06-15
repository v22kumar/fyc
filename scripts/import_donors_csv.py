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
sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))

from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.database import engine
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.models.blood_donor import BloodDonor
from app.models.geography import GeographicNode, GeoLevel

DEFAULT_ORG_ID = os.environ.get("DEFAULT_ORG_ID", "8f8b80b7-4b71-4770-b183-5c5f49e49a1d")
VALID_BLOOD_GROUPS = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}


def normalise_phone(raw: str) -> str:
    digits = "".join(c for c in raw if c.isdigit())
    if len(digits) == 10:
        return f"+91{digits}"
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"
    return f"+91{digits[-10:]}" if len(digits) > 10 else raw


def get_or_create_geography(db: Session, state_name: str, district_name: str, city_name: str) -> uuid.UUID:
    """Ensure the geography node hierarchy exists and return the leaf city/taluk node ID."""
    # 1. State Node
    state_node = db.query(GeographicNode).filter(
        GeographicNode.level == GeoLevel.STATE,
        GeographicNode.name_en.ilike(state_name)
    ).first()
    
    if not state_node:
        state_node = GeographicNode(
            id=uuid.uuid4(),
            parent_id=None,
            level=GeoLevel.STATE,
            name_en=state_name.title(),
            name_ta=state_name.title()
        )
        db.add(state_node)
        db.flush()
        print(f"  Created State Node: {state_node.name_en}")
        
    # 2. District Node
    district_node = db.query(GeographicNode).filter(
        GeographicNode.level == GeoLevel.DISTRICT,
        GeographicNode.name_en.ilike(district_name),
        GeographicNode.parent_id == state_node.id
    ).first()
    
    if not district_node:
        district_node = GeographicNode(
            id=uuid.uuid4(),
            parent_id=state_node.id,
            level=GeoLevel.DISTRICT,
            name_en=district_name.title(),
            name_ta=district_name.title()
        )
        db.add(district_node)
        db.flush()
        print(f"  Created District Node: {district_node.name_en}")
        
    # 3. Taluk/City Node
    city_node = db.query(GeographicNode).filter(
        GeographicNode.level == GeoLevel.TALUK,
        GeographicNode.name_en.ilike(city_name),
        GeographicNode.parent_id == district_node.id
    ).first()
    
    if not city_node:
        city_node = GeographicNode(
            id=uuid.uuid4(),
            parent_id=district_node.id,
            level=GeoLevel.TALUK,
            name_en=city_name.title(),
            name_ta=city_name.title()
        )
        db.add(city_node)
        db.flush()
        print(f"  Created Taluk/City Node: {city_node.name_en}")
        
    return city_node.id


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

    # Automatically alter SQLite user_profiles table to add gender column if missing
    if not args.dry_run:
        try:
            with engine.connect() as conn:
                result = conn.execute(text("PRAGMA table_info(user_profiles)"))
                columns = [row[1] for row in result.fetchall()]
                if "gender" not in columns:
                    print("Adding 'gender' column to 'user_profiles' table...")
                    conn.execute(text("ALTER TABLE user_profiles ADD COLUMN gender VARCHAR(20)"))
                    conn.commit()
        except Exception as e:
            print(f"Warning: Could not alter user_profiles table ({e}). Continuing anyway.")

    with open(csv_path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    print(f"Loaded {len(rows)} rows from {csv_path}")
    if args.dry_run:
        print("[DRY RUN] No database writes.")

    created = skipped = errors = 0
    org_uuid = uuid.UUID(DEFAULT_ORG_ID)

    with Session(engine) as db:
        org = db.query(Organization).filter(Organization.id == org_uuid).first()
        if not org and not args.dry_run:
            print(f"Organisation {DEFAULT_ORG_ID} not found. Run migrations/init_db first.")
            sys.exit(1)

        for i, row in enumerate(rows):
            name = row.get("name", "").strip()
            phone_raw = row.get("phone", "").strip()
            blood_group = row.get("blood_group", "O+").strip()
            available_raw = row.get("available", "True")
            available = str(available_raw).lower() in ("true", "yes", "1", "available")
            
            # Place fields
            state_name = row.get("state", "Tamil Nadu").strip()
            district_name = row.get("district", "Kanyakumari").strip()
            city_name = row.get("city", "").strip()
            gender = row.get("gender", "").strip() or None

            if blood_group not in VALID_BLOOD_GROUPS:
                blood_group = "O+"

            phone = normalise_phone(phone_raw) if phone_raw else None

            if not phone:
                skipped += 1
                continue

            if args.dry_run:
                print(f"  [{i+1}] {name} | {blood_group} | {phone} | {state_name} -> {district_name} -> {city_name} | Gender: {gender}")
                created += 1
                continue

            # Skip if phone already in DB under this org
            if phone:
                existing = db.query(User).filter_by(phone_number=phone, organization_id=org_uuid).first()
                if existing:
                    skipped += 1
                    continue

            try:
                # Find or create leaf geography node (Taluk/City)
                geography_id = None
                if state_name and district_name and city_name:
                    geography_id = get_or_create_geography(db, state_name, district_name, city_name)

                user_id = uuid.uuid4()
                user = User(
                    id=user_id,
                    organization_id=org_uuid,
                    phone_number=phone or f"+9100000{uuid.uuid4().hex[:5]}",
                    role="PUBLIC_CITIZEN",
                    is_verified=True,
                    preferred_language="ta",
                )
                db.add(user)
                db.flush()

                profile = UserProfile(
                    user_id=user_id,
                    full_name_en=name or f"Citizen_{user_id.hex[:6]}",
                    full_name_ta=name or f"Citizen_{user_id.hex[:6]}",
                    address_line_en=city_name or None,
                    address_line_ta=city_name or None,
                    geography_id=geography_id,
                    gender=gender,
                )
                db.add(profile)

                donor = BloodDonor(
                    id=uuid.uuid4(),
                    user_id=user_id,
                    organization_id=org_uuid,
                    blood_group=blood_group,
                    is_available=available,
                    geography_id=geography_id,
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
