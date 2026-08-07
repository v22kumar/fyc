"""The department directory and the escalation ladders, as data.

Replaces the nine-row Python list in `routers/issues.py` that mapped one
category to one office for the entire tenant regardless of where the complaint
came from.

## What is in here, and what is deliberately not

**In:** government bodies, the offices within them, the order those offices are
tried in, and how long each gets. All of it public, structural, and stable for
years.

**Not in: a single email address or officer name.** Every `Authority` is seeded
with its designation and no contact details. That is not an oversight to be
filled in later by a script — it is the design. A fabricated address for a real
public official is worse than an empty one: the letter goes nowhere, the log
says it was sent, and the club tells a citizen their complaint is with the
Commissioner when it is in a bounce folder. The club enters each contact, with
the page it came from and the date it was checked.

Portal URLs and helplines *are* seeded, because those are published facts that
can be cited — and because they are what the app falls back to showing a citizen
when no rung of the ladder is reachable yet, so nobody hits a dead end.

Idempotent: safe to run on every boot and after every edit. Departments upsert
on `(organization_id, code)`, rules on `(organization_id, category, scope)`.
Existing contact details are never touched.
"""
from __future__ import annotations

from typing import Iterable
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.civic import (
    Authority, CivicCategory as C, Department, GovTier, JurisdictionScope as S,
    LocalBodyType, RoutingRule, RoutingStep, Rung as R,
)

# ── Departments ──────────────────────────────────────────────────────────────
# code, name_en, name_ta, tier, portal_url, helpline
#
# Portals are only filled in where the address is one this project has actually
# seen cited. An unverified URL in a directory is the same class of mistake as an
# unverified email; where there is doubt the field is left null and the ladder
# still works, because routing depends on the offices, not the links.
DEPARTMENTS: list[tuple] = [
    ("WARD_OFFICE", "Ward Councillor / Ward Member", "வார்டு உறுப்பினர்",
     GovTier.LOCAL_BODY, None, None),
    ("ULB_ENGINEERING", "Local Body — Engineering Wing", "நகராட்சி — பொறியியல் பிரிவு",
     GovTier.LOCAL_BODY, "https://www.tnurbantree.tn.gov.in/nagercoil/", None),
    ("ULB_WATER", "Local Body — Water Supply", "நகராட்சி — குடிநீர் வழங்கல்",
     GovTier.LOCAL_BODY, "https://www.tnurbantree.tn.gov.in/nagercoil/", None),
    ("ULB_ELECTRICAL", "Local Body — Street Lighting", "நகராட்சி — தெரு விளக்கு",
     GovTier.LOCAL_BODY, "https://www.tnurbantree.tn.gov.in/nagercoil/", None),
    ("ULB_HEALTH", "Local Body — Health & Sanitation", "நகராட்சி — சுகாதாரம் மற்றும் தூய்மை",
     GovTier.LOCAL_BODY, "https://www.tnurbantree.tn.gov.in/nagercoil/", None),
    ("VILLAGE_PANCHAYAT", "Village Panchayat", "ஊராட்சி",
     GovTier.LOCAL_BODY, "https://kanniyakumari.nic.in/localbodies/", None),
    ("PANCHAYAT_UNION", "Panchayat Union (Block)", "ஊராட்சி ஒன்றியம்",
     GovTier.LOCAL_BODY, "https://kanniyakumari.nic.in/localbodies/", None),
    ("TNRD", "Rural Development & Panchayat Raj", "ஊரக வளர்ச்சி மற்றும் ஊராட்சித் துறை",
     GovTier.STATE, "https://tnrd.tn.gov.in/", None),
    ("HIGHWAYS", "State Highways Department", "மாநில நெடுஞ்சாலைத் துறை",
     GovTier.STATE, None, None),
    ("NHAI", "National Highways Authority of India", "தேசிய நெடுஞ்சாலை ஆணையம்",
     GovTier.CENTRAL, None, "1033"),
    ("TANGEDCO", "TANGEDCO — Electricity Board", "மின்சார வாரியம் (TANGEDCO)",
     GovTier.STATE, "https://www.tnebnet.org/", "1912"),
    ("TWAD", "TWAD Board — Water Supply & Drainage", "குடிநீர் வடிகால் வாரியம்",
     GovTier.STATE, "https://twadboard.tn.gov.in/", None),
    ("REVENUE", "Revenue Department", "வருவாய்த் துறை",
     GovTier.STATE, "https://www.cra.tn.gov.in/griev_pet.php", None),
    ("SCHOOL_EDUCATION", "School Education Department", "பள்ளிக் கல்வித் துறை",
     GovTier.STATE, None, None),
    ("HEALTH_SERVICES", "Public Health & Medical Services", "பொது சுகாதாரத் துறை",
     GovTier.STATE, None, "104"),
    ("TNPCB", "TN Pollution Control Board", "மாசுக் கட்டுப்பாட்டு வாரியம்",
     GovTier.STATE, None, None),
    ("TNSTC", "TN State Transport Corporation", "அரசு போக்குவரத்துக் கழகம்",
     GovTier.STATE, None, None),
    ("POLICE", "Police", "காவல் துறை",
     GovTier.STATE, None, "100"),
    ("COLLECTORATE", "District Collectorate, Kanniyakumari", "மாவட்ட ஆட்சியர் அலுவலகம்",
     GovTier.STATE, "https://kanniyakumari.nic.in/", None),
    ("CM_HELPLINE", "CM Helpline — IIPGCMS", "முதலமைச்சர் உதவி மையம்",
     GovTier.STATE, "https://www.tn.gov.in/grievance", "1100"),
    ("CPGRAMS", "CPGRAMS — Central Government Grievances", "மத்திய அரசு குறைதீர் மையம்",
     GovTier.CENTRAL, "https://pgportal.gov.in/", None),
]

# ── Offices ──────────────────────────────────────────────────────────────────
# department_code, rung, designation_en, designation_ta, local_body_type
#
# Designations only. Every one of these is a public fact about which desk exists;
# none of them carries a way to reach it until the club fills that in.
AUTHORITIES: list[tuple] = [
    ("WARD_OFFICE", R.WARD, "Ward Councillor", "வார்டு உறுப்பினர்", None),
    ("ULB_ENGINEERING", R.SECTION, "Assistant Engineer", "உதவி பொறியாளர்", None),
    ("ULB_ENGINEERING", R.LOCAL_HEAD, "Commissioner", "ஆணையர்", LocalBodyType.CORPORATION),
    ("ULB_ENGINEERING", R.LOCAL_HEAD, "Executive Officer", "செயல் அலுவலர்", LocalBodyType.TOWN_PANCHAYAT),
    ("ULB_WATER", R.SECTION, "Assistant Engineer — Water Supply", "உதவி பொறியாளர் — குடிநீர்", None),
    ("ULB_WATER", R.LOCAL_HEAD, "Commissioner", "ஆணையர்", LocalBodyType.CORPORATION),
    ("ULB_ELECTRICAL", R.SECTION, "Assistant Engineer — Street Lighting", "உதவி பொறியாளர் — தெரு விளக்கு", None),
    ("ULB_ELECTRICAL", R.LOCAL_HEAD, "Commissioner", "ஆணையர்", LocalBodyType.CORPORATION),
    ("ULB_HEALTH", R.SECTION, "Sanitary Inspector", "சுகாதார ஆய்வாளர்", None),
    ("ULB_HEALTH", R.LOCAL_HEAD, "City Health Officer", "நகர சுகாதார அலுவலர்", LocalBodyType.CORPORATION),
    ("VILLAGE_PANCHAYAT", R.WARD, "Ward Member", "வார்டு உறுப்பினர்", LocalBodyType.VILLAGE_PANCHAYAT),
    ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, "Panchayat President", "ஊராட்சித் தலைவர்", LocalBodyType.VILLAGE_PANCHAYAT),
    ("PANCHAYAT_UNION", R.LOCAL_HEAD, "Block Development Officer", "ஊராட்சி ஒன்றிய வளர்ச்சி அலுவலர்", None),
    ("TWAD", R.SUBDIVISION, "Assistant Executive Engineer", "உதவி செயற்பொறியாளர்", None),
    ("TWAD", R.DISTRICT, "Executive Engineer", "செயற்பொறியாளர்", None),
    ("TANGEDCO", R.SECTION, "Assistant Engineer — Section Office", "உதவி பொறியாளர் — பிரிவு அலுவலகம்", None),
    ("TANGEDCO", R.SUBDIVISION, "Assistant Executive Engineer", "உதவி செயற்பொறியாளர்", None),
    ("TANGEDCO", R.DISTRICT, "Executive Engineer", "செயற்பொறியாளர்", None),
    ("REVENUE", R.SECTION, "Village Administrative Officer", "கிராம நிர்வாக அலுவலர்", None),
    ("REVENUE", R.LOCAL_HEAD, "Tahsildar", "வட்டாட்சியர்", None),
    ("REVENUE", R.SUBDIVISION, "Revenue Divisional Officer", "வருவாய் கோட்டாட்சியர்", None),
    ("SCHOOL_EDUCATION", R.SECTION, "Headmaster", "தலைமை ஆசிரியர்", None),
    ("SCHOOL_EDUCATION", R.LOCAL_HEAD, "Block Education Officer", "வட்டாரக் கல்வி அலுவலர்", None),
    ("SCHOOL_EDUCATION", R.DISTRICT, "Chief Educational Officer", "முதன்மைக் கல்வி அலுவலர்", None),
    ("HEALTH_SERVICES", R.SECTION, "Block Medical Officer", "வட்டார மருத்துவ அலுவலர்", None),
    ("HEALTH_SERVICES", R.DISTRICT, "Deputy Director of Health Services", "துணை இயக்குநர், சுகாதாரப் பணிகள்", None),
    ("TNPCB", R.DISTRICT, "District Environmental Engineer", "மாவட்ட சுற்றுச்சூழல் பொறியாளர்", None),
    ("TNPCB", R.STATE, "Member Secretary", "உறுப்பினர் செயலாளர்", None),
    ("TNSTC", R.LOCAL_HEAD, "Branch Manager", "கிளை மேலாளர்", None),
    ("TNSTC", R.DISTRICT, "Divisional Manager", "கோட்ட மேலாளர்", None),
    ("POLICE", R.SECTION, "Station House Officer / Inspector", "காவல் நிலை ஆய்வாளர்", None),
    ("POLICE", R.SUBDIVISION, "Deputy Superintendent of Police", "காவல் துணைக் கண்காணிப்பாளர்", None),
    ("POLICE", R.DISTRICT, "Superintendent of Police", "காவல் கண்காணிப்பாளர்", None),
    ("HIGHWAYS", R.SUBDIVISION, "Assistant Divisional Engineer", "உதவி கோட்டப் பொறியாளர்", None),
    ("HIGHWAYS", R.DISTRICT, "Divisional Engineer", "கோட்டப் பொறியாளர்", None),
    ("NHAI", R.DISTRICT, "Project Director", "திட்ட இயக்குநர்", None),
    ("COLLECTORATE", R.DISTRICT, "District Collector", "மாவட்ட ஆட்சியர்", None),
    ("CM_HELPLINE", R.STATE, "Chief Minister's Special Cell", "முதலமைச்சர் சிறப்பு பிரிவு", None),
    ("CPGRAMS", R.CENTRAL, "Nodal Appellate Authority", "மைய மேல்முறையீட்டு அதிகாரி", None),
]

# ── Ladders ──────────────────────────────────────────────────────────────────
# The last rung of every ladder is a grievance system of last resort, so no
# complaint can run out of places to go.
#
# Wait days are how long an office gets before the club is *asked* whether to
# escalate. They are not timers that send anything.
_URBAN_TAIL = [("COLLECTORATE", R.DISTRICT, 14), ("CM_HELPLINE", R.STATE, 21)]
_RURAL_TAIL = [("COLLECTORATE", R.DISTRICT, 14), ("CM_HELPLINE", R.STATE, 21)]

# category, scope, [(department_code, rung, wait_days)], notes
LADDERS: list[tuple] = [
    (C.ROAD, S.URBAN, [
        ("WARD_OFFICE", R.WARD, 3),
        ("ULB_ENGINEERING", R.SECTION, 7),
        ("ULB_ENGINEERING", R.LOCAL_HEAD, 10),
    ] + _URBAN_TAIL,
     "A road on a national or state highway belongs to NHAI or the Highways "
     "Department instead. Road class cannot be derived from GPS, so the club "
     "reviewer switches the route when they recognise the road."),
    (C.ROAD, S.RURAL, [
        ("VILLAGE_PANCHAYAT", R.WARD, 3),
        ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, 5),
        ("PANCHAYAT_UNION", R.LOCAL_HEAD, 10),
    ] + _RURAL_TAIL, None),

    (C.STREET_LIGHT, S.URBAN, [
        ("WARD_OFFICE", R.WARD, 3),
        ("ULB_ELECTRICAL", R.SECTION, 5),
        ("ULB_ELECTRICAL", R.LOCAL_HEAD, 10),
    ] + _URBAN_TAIL, None),
    (C.STREET_LIGHT, S.RURAL, [
        ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, 5),
        ("PANCHAYAT_UNION", R.LOCAL_HEAD, 10),
    ] + _RURAL_TAIL, None),

    (C.DRINKING_WATER, S.URBAN, [
        ("WARD_OFFICE", R.WARD, 3),
        ("ULB_WATER", R.SECTION, 5),
        ("ULB_WATER", R.LOCAL_HEAD, 10),
        ("TWAD", R.DISTRICT, 14),
    ] + _URBAN_TAIL, None),
    (C.DRINKING_WATER, S.RURAL, [
        ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, 5),
        ("TWAD", R.SUBDIVISION, 10),
        ("PANCHAYAT_UNION", R.LOCAL_HEAD, 10),
    ] + _RURAL_TAIL, None),

    (C.DRAINAGE, S.URBAN, [
        ("WARD_OFFICE", R.WARD, 3),
        ("ULB_ENGINEERING", R.SECTION, 5),
        ("ULB_ENGINEERING", R.LOCAL_HEAD, 10),
    ] + _URBAN_TAIL, None),
    (C.DRAINAGE, S.RURAL, [
        ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, 5),
        ("PANCHAYAT_UNION", R.LOCAL_HEAD, 10),
    ] + _RURAL_TAIL, None),

    (C.GARBAGE, S.URBAN, [
        ("WARD_OFFICE", R.WARD, 3),
        ("ULB_HEALTH", R.SECTION, 5),
        ("ULB_HEALTH", R.LOCAL_HEAD, 10),
    ] + _URBAN_TAIL, None),
    (C.GARBAGE, S.RURAL, [
        ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, 5),
        ("PANCHAYAT_UNION", R.LOCAL_HEAD, 10),
    ] + _RURAL_TAIL, None),

    (C.PUBLIC_HEALTH, S.URBAN, [
        ("ULB_HEALTH", R.SECTION, 5),
        ("ULB_HEALTH", R.LOCAL_HEAD, 10),
        ("HEALTH_SERVICES", R.DISTRICT, 14),
    ] + _URBAN_TAIL, None),
    (C.PUBLIC_HEALTH, S.RURAL, [
        ("VILLAGE_PANCHAYAT", R.LOCAL_HEAD, 5),
        ("PANCHAYAT_UNION", R.LOCAL_HEAD, 7),
        ("HEALTH_SERVICES", R.DISTRICT, 14),
    ] + _RURAL_TAIL, None),

    # ── Ladders that ignore the local body entirely ──────────────────────────
    # These departments run their own chain of offices in a city and a village
    # alike. Written once so the two can never drift apart.
    (C.ELECTRICITY, S.ANY, [
        ("TANGEDCO", R.SECTION, 2),
        ("TANGEDCO", R.SUBDIVISION, 5),
        ("TANGEDCO", R.DISTRICT, 10),
        ("CM_HELPLINE", R.STATE, 21),
    ],
     "A live or fallen wire is an emergency and belongs on the phone to 1912, "
     "not in a review queue."),
    (C.ENCROACHMENT, S.ANY, [
        ("REVENUE", R.SECTION, 7),
        ("REVENUE", R.LOCAL_HEAD, 10),
        ("REVENUE", R.SUBDIVISION, 14),
        ("COLLECTORATE", R.DISTRICT, 21),
        ("CM_HELPLINE", R.STATE, 21),
    ], "Land is a revenue subject, so this runs VAO → Tahsildar → RDO → Collector."),
    (C.SCHOOL, S.ANY, [
        ("SCHOOL_EDUCATION", R.SECTION, 7),
        ("SCHOOL_EDUCATION", R.LOCAL_HEAD, 10),
        ("SCHOOL_EDUCATION", R.DISTRICT, 14),
        ("CM_HELPLINE", R.STATE, 21),
    ], None),
    (C.HEALTHCARE, S.ANY, [
        ("HEALTH_SERVICES", R.SECTION, 5),
        ("HEALTH_SERVICES", R.DISTRICT, 10),
        ("COLLECTORATE", R.DISTRICT, 14),
        ("CM_HELPLINE", R.STATE, 21),
    ], None),
    (C.POLLUTION, S.ANY, [
        ("TNPCB", R.DISTRICT, 14),
        ("TNPCB", R.STATE, 21),
        ("COLLECTORATE", R.DISTRICT, 14),
        ("CM_HELPLINE", R.STATE, 21),
    ], None),
    (C.TRANSPORT, S.ANY, [
        ("TNSTC", R.LOCAL_HEAD, 7),
        ("TNSTC", R.DISTRICT, 14),
        ("CM_HELPLINE", R.STATE, 21),
    ], None),
    (C.SAFETY, S.ANY, [
        ("POLICE", R.SECTION, 3),
        ("POLICE", R.SUBDIVISION, 7),
        ("POLICE", R.DISTRICT, 14),
        ("CM_HELPLINE", R.STATE, 21),
    ], "Anything happening right now goes to 100, not through this ladder."),
    (C.OTHER, S.ANY, [
        ("COLLECTORATE", R.DISTRICT, 14),
        ("CM_HELPLINE", R.STATE, 21),
    ], None),
]


def seed(db: Session, organization_id: UUID) -> dict:
    """Create or update the directory for one organisation. Idempotent.

    Never writes to `email`, `phone`, `source_url` or `verified_at` on an
    Authority — those belong to whoever checked them, and a re-seed must not
    quietly undo an evening of somebody phoning offices.
    """
    made = {"departments": 0, "authorities": 0, "rules": 0}

    by_code: dict[str, Department] = {
        d.code: d
        for d in db.query(Department).filter(
            Department.organization_id == organization_id
        )
    }

    for code, en, ta, tier, portal, helpline in DEPARTMENTS:
        dept = by_code.get(code)
        if dept is None:
            dept = Department(organization_id=organization_id, code=code)
            db.add(dept)
            by_code[code] = dept
            made["departments"] += 1
        # Structural fields are ours to keep current; nothing here is user data.
        dept.name_en, dept.name_ta = en, ta
        dept.tier = tier.value
        dept.portal_url, dept.helpline = portal, helpline
        dept.is_active = True
    db.flush()

    existing_auth = {
        (a.department_id, a.rung, a.designation_en, a.local_body_type): a
        for a in db.query(Authority).filter(
            Authority.organization_id == organization_id
        )
    }
    for code, rung, en, ta, lbt in AUTHORITIES:
        dept = by_code.get(code)
        if dept is None:
            continue
        key = (dept.id, int(rung), en, lbt.value if lbt else None)
        if key in existing_auth:
            continue
        db.add(Authority(
            organization_id=organization_id,
            department_id=dept.id,
            rung=int(rung),
            designation_en=en,
            designation_ta=ta,
            local_body_type=lbt.value if lbt else None,
            # No email, no phone, no source. Filled in by the club, not by this.
            is_active=True,
        ))
        made["authorities"] += 1

    existing_rules = {
        (r.category, r.scope): r
        for r in db.query(RoutingRule).filter(
            RoutingRule.organization_id == organization_id
        )
    }
    for category, scope, steps, notes in LADDERS:
        rule = existing_rules.get((category.value, scope.value))
        if rule is None:
            rule = RoutingRule(
                organization_id=organization_id,
                category=category.value,
                scope=scope.value,
            )
            db.add(rule)
            db.flush()
            made["rules"] += 1
        rule.notes, rule.is_active = notes, True
        # Steps are replaced wholesale: a ladder is one decision, and merging
        # positions row by row is how a rule ends up with two rung 3s.
        for old in list(rule.steps):
            db.delete(old)
        db.flush()
        for position, (dept_code, rung, wait_days) in enumerate(steps, start=1):
            db.add(RoutingStep(
                organization_id=organization_id,
                rule_id=rule.id,
                position=position,
                department_code=dept_code,
                rung=int(rung),
                wait_days=wait_days,
            ))

    db.commit()
    return made
