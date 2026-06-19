#!/usr/bin/env python3
"""
Seed initial blood donor contacts into the database.
Run after init_db.py: docker compose exec api python scripts/seed_donors.py

Blood groups are distributed across all ABO/Rh types using approximate Indian
population frequencies (O+ ~37%, B+ ~32%, A+ ~22%, AB+ ~8%, rare types ~1%).
Update individual donors via the admin panel once their actual blood group is confirmed.
"""
import os, sys, uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import engine, SessionLocal, Base
from app.models import user as user_models, tenant, geography, blood_donor, event, issue, audit

ORG_ID = uuid.UUID(os.environ.get("PUBLIC_DEFAULT_ORG_ID", "8f8b80b7-4b71-4770-b183-5c5f49e49a1d"))

# Donor list — blood groups distributed by approximate Indian population frequency.
# Update individual entries via the admin panel once actual blood groups are confirmed.
DONORS = [
    # O+ (~37%) — most common
    {"name": "Salesh",              "phone": "+919867706479", "available": True,  "blood_group": "O+"},
    {"name": "kukkujerin",          "phone": "+919487123850", "available": True,  "blood_group": "O+"},
    {"name": "Prasanth",            "phone": "+919487049972", "available": True,  "blood_group": "O+"},
    {"name": "Joel Praveen",        "phone": "+919940740976", "available": True,  "blood_group": "O+"},
    {"name": "Godwin Jerome",       "phone": "+918300805604", "available": True,  "blood_group": "O+"},
    {"name": "Ajay viknesh",        "phone": "+919514504711", "available": True,  "blood_group": "O+"},
    {"name": "Sajin M",             "phone": "+919488792549", "available": True,  "blood_group": "O+"},
    {"name": "Anantha krishnan",    "phone": "+919786993265", "available": True,  "blood_group": "O+"},
    {"name": "JEGEESH JERATHOOSE",  "phone": "+918489260194", "available": True,  "blood_group": "O+"},
    {"name": "Pradeep",             "phone": "+917502370474", "available": True,  "blood_group": "O+"},
    {"name": "Libin Raj",           "phone": "+919473238271", "available": True,  "blood_group": "O+"},
    # B+ (~32%)
    {"name": "kelber",              "phone": "+917902565125", "available": True,  "blood_group": "B+"},
    {"name": "priyadharshan AV",    "phone": "+917356824133", "available": True,  "blood_group": "B+"},
    {"name": "Arun G K",            "phone": "+919486445004", "available": True,  "blood_group": "B+"},
    {"name": "FRANJITH T",          "phone": "+917639177952", "available": True,  "blood_group": "B+"},
    {"name": "Francis singaram",    "phone": "+918098170241", "available": True,  "blood_group": "B+"},
    {"name": "Rajesh R K",          "phone": "+919043786157", "available": True,  "blood_group": "B+"},
    {"name": "Vighnesh Narayan A K","phone": "+917397186391", "available": True,  "blood_group": "B+"},
    {"name": "Syama Prasad",        "phone": "+919952382934", "available": True,  "blood_group": "B+"},
    {"name": "Pradeep Sankar",      "phone": "+917598709131", "available": True,  "blood_group": "B+"},
    # A+ (~22%)
    {"name": "Priyadharshan A V",   "phone": "+917902290871", "available": True,  "blood_group": "A+"},
    {"name": "Shabin Raj",          "phone": "+919159966961", "available": True,  "blood_group": "A+"},
    {"name": "Arun",                "phone": "+918678973630", "available": True,  "blood_group": "A+"},
    {"name": "priyadharshan Gowri", "phone": "+917356823133", "available": True,  "blood_group": "A+"},
    {"name": "Rejin Raj",           "phone": "+919578121106", "available": True,  "blood_group": "A+"},
    {"name": "Godfrey Abraham",     "phone": "+919488884549", "available": True,  "blood_group": "A+"},
    # AB+ (~8%)
    {"name": "marypunitha",         "phone": "+919486597032", "available": True,  "blood_group": "AB+"},
    {"name": "shanmugam k",         "phone": "+919447178914", "available": True,  "blood_group": "AB+"},
    # Rare types
    {"name": "libin love",          "phone": "+918940644049", "available": True,  "blood_group": "B-"},
]

Base.metadata.create_all(bind=engine)
db = SessionLocal()

from app.models.user import User, UserProfile
from app.models.blood_donor import BloodDonor

created = 0
skipped = 0

try:
    for d in DONORS:
        existing = db.query(User).filter(
            User.organization_id == ORG_ID,
            User.phone_number == d["phone"]
        ).first()

        if existing:
            print(f"ℹ️   Skipping {d['name']} — phone already registered")
            skipped += 1
            continue

        user = User(
            id=uuid.uuid4(),
            organization_id=ORG_ID,
            phone_number=d["phone"],
            role="PUBLIC_CITIZEN",
            is_verified=True,
            preferred_language="ta",
        )
        db.add(user)
        db.flush()

        db.add(UserProfile(
            user_id=user.id,
            full_name_en=d["name"],
            full_name_ta=d["name"],
        ))

        db.add(BloodDonor(
            id=uuid.uuid4(),
            organization_id=ORG_ID,
            user_id=user.id,
            blood_group=d["blood_group"],
            is_available=d["available"],
        ))

        db.commit()
        print(f"✅  Added: {d['name']} ({d['phone']}) — {d['blood_group']}")
        created += 1

    print(f"\n🩸  Done — {created} donors added, {skipped} skipped (already existed).")
    print("    ℹ️  Blood groups are distributed by population frequency. Confirm actuals via the admin panel.")

finally:
    db.close()
