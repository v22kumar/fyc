#!/usr/bin/env python3
"""
Seed blood donors scraped from Friends2Support (Kanyakumari + Thiruvananthapuram).
Run as a Fly.io release command: python seeds/import_donors.py

Idempotent — skips any donor whose phone number is already in the database.
"""
import csv
import os
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy.orm import Session

from app.core.database import engine
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.models.blood_donor import BloodDonor
from app.models.geography import GeographicNode, GeoLevel

CSV_PATH = Path(__file__).parent / "donors.csv"
ORG_ID = uuid.UUID(os.environ.get("DEFAULT_ORG_ID", "8f8b80b7-4b71-4770-b183-5c5f49e49a1d"))
VALID_BLOOD_GROUPS = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}


def normalise_phone(raw: str) -> str:
    digits = "".join(c for c in raw if c.isdigit())
    if len(digits) == 10:
        return f"+91{digits}"
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"
    return f"+91{digits[-10:]}" if len(digits) > 10 else raw


def get_or_create_geo(db: Session, state: str, district: str, city: str) -> uuid.UUID | None:
    if not (state and district and city):
        return None

    state_node = db.query(GeographicNode).filter_by(level=GeoLevel.STATE).filter(
        GeographicNode.name_en.ilike(state)).first()
    if not state_node:
        state_node = GeographicNode(id=uuid.uuid4(), parent_id=None,
                                    level=GeoLevel.STATE, name_en=state, name_ta=state)
        db.add(state_node); db.flush()

    district_node = db.query(GeographicNode).filter_by(
        level=GeoLevel.DISTRICT, parent_id=state_node.id).filter(
        GeographicNode.name_en.ilike(district)).first()
    if not district_node:
        district_node = GeographicNode(id=uuid.uuid4(), parent_id=state_node.id,
                                       level=GeoLevel.DISTRICT, name_en=district, name_ta=district)
        db.add(district_node); db.flush()

    city_node = db.query(GeographicNode).filter_by(
        level=GeoLevel.TALUK, parent_id=district_node.id).filter(
        GeographicNode.name_en.ilike(city)).first()
    if not city_node:
        city_node = GeographicNode(id=uuid.uuid4(), parent_id=district_node.id,
                                   level=GeoLevel.TALUK, name_en=city, name_ta=city)
        db.add(city_node); db.flush()

    return city_node.id


def main():
    if not CSV_PATH.exists():
        print(f"[seed] CSV not found at {CSV_PATH}, skipping.")
        return

    try:
        with engine.begin() as conn:
            from sqlalchemy import text
            conn.execute(text("DROP TABLE IF EXISTS apscheduler_jobs;"))
            print("[seed] Dropped old apscheduler_jobs table to fix unpickling crash")
    except Exception as e:
        print(f"[seed] DB not ready ({e}), skipping friends2support import.")
        return

    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    print(f"[seed] Loaded {len(rows)} rows from {CSV_PATH.name}")
    created = skipped = errors = 0

    with Session(engine) as db:
        org = db.query(Organization).filter_by(id=ORG_ID).first()
        if not org:
            print(f"[seed] Organisation {ORG_ID} not found — run init_db first.")
            return

        for row in rows:
            name        = (row.get("name") or "").strip()
            phone_raw   = (row.get("phone") or "").strip()
            blood_group = (row.get("blood_group") or "O+").strip()
            available   = str(row.get("available", "True")).lower() in ("true", "yes", "1")
            state       = (row.get("state") or "").strip()
            district    = (row.get("district") or "").strip()
            city        = (row.get("city") or "").strip()

            if blood_group not in VALID_BLOOD_GROUPS:
                blood_group = "O+"

            phone = normalise_phone(phone_raw) if phone_raw else None
            if not phone:
                skipped += 1
                continue

            if db.query(User).filter_by(phone_number=phone, organization_id=ORG_ID).first():
                skipped += 1
                continue

            try:
                geo_id = get_or_create_geo(db, state, district, city)
                user_id = uuid.uuid4()
                db.add(User(id=user_id, organization_id=ORG_ID, phone_number=phone,
                            role="PUBLIC_CITIZEN", is_verified=True, preferred_language="ta"))
                db.flush()
                db.add(UserProfile(user_id=user_id,
                                   full_name_en=name or f"Donor_{user_id.hex[:6]}",
                                   full_name_ta=name or f"Donor_{user_id.hex[:6]}",
                                   address_line_en=city or None,
                                   geography_id=geo_id))
                db.add(BloodDonor(id=uuid.uuid4(), user_id=user_id, organization_id=ORG_ID,
                                  blood_group=blood_group, is_available=available,
                                  geography_id=geo_id))
                created += 1
            except Exception as e:
                db.rollback()
                errors += 1
                if errors <= 5:
                    print(f"[seed] Error ({name}): {e}")
                continue

        db.commit()

    print(f"[seed] Friends2Support import done: {created} created, {skipped} skipped, {errors} errors")


if __name__ == "__main__":
    main()
