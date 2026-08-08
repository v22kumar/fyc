"""Import collected government contacts into the civic directory, with a report.

Reads a filled-in worksheet (see `civic_contacts_worksheet.py`), checks it hard,
writes a Markdown report, and only then — with `--apply` — touches the database.

## What it refuses, and why

**A contact with no source.** The same rule the PATCH endpoint enforces, applied
to bulk import so the back door is not softer than the front one. This directory
decides where complaints about real people's streets get sent; an entry nobody
can trace is one nobody can check when it stops working.

**An office id that is not in the canonical list.** Import never *creates* an
office. The office list comes from the seed, which is reviewed; a typo in a
spreadsheet must not silently add a desk that does not exist.

**A confidence of `not_found` alongside a phone number.** One of the two is
wrong and a human should say which.

## What it reports rather than refuses

Duplicates and conflicts. Two sources disagreeing about a phone number is
normal — one page is stale — and the resolution is a judgement, not a rule. Both
are listed with their sources so somebody can decide.

    python scripts/import_civic_contacts.py seeds/civic_contacts.worksheet.json
    python scripts/import_civic_contacts.py <file> --apply --org <uuid>
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, ".")

CONFIDENCE = {
    "official_government_website",
    "official_pdf",
    "department_portal",
    "not_found",
}
#: A record claiming one of these must carry a source and a date.
CONFIDENCE_WITH_SOURCE = CONFIDENCE - {"not_found"}

_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class Problem:
    """One reason a record cannot be imported."""

    def __init__(self, office_id: str, message: str):
        self.office_id, self.message = office_id, message

    def __str__(self) -> str:
        return f"{self.office_id}: {self.message}"


def canonical_ids() -> dict:
    """The offices that exist, from the seed rather than from the database.

    Reading the seed means the check works before anything has been deployed and
    cannot be fooled by a directory that was itself imported badly.
    """
    from scripts.civic_contacts_worksheet import office_id
    from seeds.civic_directory import AUTHORITIES

    return {
        office_id(code, rung, en, lbt): (code, int(rung), en, lbt)
        for code, rung, en, ta, lbt in AUTHORITIES
    }


def check(records: list[dict]) -> tuple[list[dict], list[Problem]]:
    """Split the file into what can be imported and what cannot."""
    known = canonical_ids()
    good, problems = [], []

    for record in records:
        oid = record.get("office_id") or "<no office_id>"
        confidence = record.get("confidence")
        phone = (record.get("phone") or "").strip()
        email = (record.get("email") or "").strip()
        source = (record.get("source_url") or "").strip()
        verified = (record.get("verified_at") or "").strip()

        if oid not in known:
            problems.append(Problem(oid, "not an office in the canonical directory"))
            continue
        if confidence not in CONFIDENCE:
            problems.append(Problem(oid, f"confidence must be one of {sorted(CONFIDENCE)}"))
            continue

        has_contact = bool(phone or email)
        if has_contact and not source:
            problems.append(Problem(oid, "a contact needs the source_url it was read from"))
            continue
        if has_contact and not verified:
            problems.append(Problem(oid, "a contact needs verified_at — the day a human read it"))
            continue
        if has_contact and confidence == "not_found":
            problems.append(Problem(oid, "confidence says not_found but a contact is present"))
            continue
        if confidence in CONFIDENCE_WITH_SOURCE and not has_contact:
            problems.append(
                Problem(oid, f"confidence says {confidence} but no phone or email was recorded")
            )
            continue
        if email and not _EMAIL.match(email):
            problems.append(Problem(oid, f"not a usable email address: {email!r}"))
            continue
        if verified:
            try:
                datetime.strptime(verified, "%Y-%m-%d")
            except ValueError:
                problems.append(Problem(oid, f"verified_at must be YYYY-MM-DD, got {verified!r}"))
                continue

        good.append(record)

    return good, problems


def find_duplicates(records: list[dict]) -> dict:
    """Offices with more than one record. Legitimate — a zone office can have
    several numbers — so this is reported, never rejected."""
    by_office = defaultdict(list)
    for r in records:
        if r.get("phone") or r.get("email"):
            by_office[r["office_id"]].append(r)
    return {k: v for k, v in by_office.items() if len(v) > 1}


def find_conflicts(duplicates: dict) -> dict:
    """Duplicates whose sources disagree about the same field.

    A stale page is the usual cause, and choosing between them is a judgement a
    person makes — so both are shown with their sources rather than one being
    picked by a rule nobody remembers writing.
    """
    conflicts = {}
    for office, group in duplicates.items():
        for field in ("phone", "email"):
            values = {(r.get(field) or "").strip() for r in group}
            values.discard("")
            if len(values) > 1:
                conflicts.setdefault(office, []).append({
                    "field": field,
                    "values": [
                        {"value": r.get(field), "source_url": r.get("source_url")}
                        for r in group
                        if (r.get(field) or "").strip()
                    ],
                })
    return conflicts


def report(records, good, problems, duplicates, conflicts, known) -> str:
    filled = {r["office_id"] for r in good if r.get("phone") or r.get("email")}
    missing = sorted(set(known) - filled)
    by_confidence = defaultdict(int)
    for r in good:
        by_confidence[r["confidence"]] += 1

    lines = [
        "# Civic directory — contact collection report",
        "",
        f"Generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        "## Summary",
        "",
        f"- Offices in the canonical directory: **{len(known)}**",
        f"- Records read: **{len(records)}**",
        f"- Offices with a usable contact: **{len(filled)}**",
        f"- Offices still without one: **{len(missing)}**",
        f"- Records rejected: **{len(problems)}**",
        "",
        "## Confidence",
        "",
        "| Level | Records |",
        "| --- | ---: |",
    ]
    for level in sorted(CONFIDENCE):
        lines.append(f"| {level} | {by_confidence.get(level, 0)} |")

    lines += ["", "## Offices matched", ""]
    if filled:
        lines += ["| Office | Contact | Source | Verified |", "| --- | --- | --- | --- |"]
        for r in good:
            if not (r.get("phone") or r.get("email")):
                continue
            contact = r.get("email") or r.get("phone")
            lines.append(
                f"| `{r['office_id']}` | {contact} | {r.get('source_url')} | {r.get('verified_at')} |"
            )
    else:
        lines.append("_None yet._")

    lines += ["", "## Offices with no published contact found", ""]
    lines += [f"- `{oid}`" for oid in missing] or ["_None._"]

    lines += ["", "## Duplicate contacts", ""]
    if duplicates:
        for office, group in duplicates.items():
            lines.append(f"- `{office}` — {len(group)} records")
    else:
        lines.append("_None._")

    lines += ["", "## Conflicting information between sources", ""]
    if conflicts:
        for office, issues in conflicts.items():
            for issue in issues:
                lines.append(f"- `{office}` — **{issue['field']}** disagrees:")
                for v in issue["values"]:
                    lines.append(f"    - `{v['value']}` from {v['source_url']}")
    else:
        lines.append("_None._")

    lines += ["", "## Rejected records", ""]
    lines += [f"- {p}" for p in problems] or ["_None._"]
    lines.append("")
    return "\n".join(lines)


def apply(records: list[dict], organization_id: str) -> int:
    """Write the checked records onto the matching Authority rows."""
    from app.core.database import SessionLocal
    from app.models.civic import Authority, Department
    from scripts.civic_contacts_worksheet import office_id

    db = SessionLocal()
    written = 0
    try:
        by_code = {
            d.code: d
            for d in db.query(Department).filter(
                Department.organization_id == organization_id
            )
        }
        offices = {}
        for a in db.query(Authority).filter(Authority.organization_id == organization_id):
            dept = next((c for c, d in by_code.items() if d.id == a.department_id), None)
            if dept is None:
                continue
            from app.models.civic import LocalBodyType

            lbt = LocalBodyType(a.local_body_type) if a.local_body_type else None
            offices[office_id(dept, a.rung, a.designation_en, lbt)] = a

        for r in records:
            if not (r.get("phone") or r.get("email")):
                continue
            authority = offices.get(r["office_id"])
            if authority is None:
                continue
            authority.email = (r.get("email") or "").strip() or None
            authority.phone = (r.get("phone") or "").strip() or None
            authority.office_name_en = r.get("office_name") or authority.office_name_en
            authority.address_en = r.get("address") or authority.address_en
            authority.source_url = r["source_url"]
            authority.verified_at = datetime.strptime(
                r["verified_at"], "%Y-%m-%d"
            ).replace(tzinfo=timezone.utc)
            written += 1
        db.commit()
    finally:
        db.close()
    return written


def apply_worksheet(db, organization_id, path) -> int:
    """Fill blank contacts from the worksheet, on an existing session.

    Separate from `apply` because this one runs on every boot, and the rules
    are different when nobody is watching:

    * It only fills a contact that is still blank. An organiser who corrected a
      number by hand must not have it reverted on the next deploy by a file
      that was right in August.
    * It takes the caller's session, so a failure rolls back with the rest of
      startup rather than half-committing a directory.

    Returns how many offices it filled, so the boot log can say.
    """
    import json

    from app.models.civic import Authority, Department, LocalBodyType
    from scripts.civic_contacts_worksheet import office_id

    if not path.exists():
        return 0
    records = json.loads(path.read_text())
    if isinstance(records, dict):
        records = records.get("offices") or records.get("rows") or []

    by_code = {
        d.code: d
        for d in db.query(Department).filter(
            Department.organization_id == organization_id
        )
    }
    offices = {}
    for a in db.query(Authority).filter(
        Authority.organization_id == organization_id
    ):
        dept = next((c for c, d in by_code.items() if d.id == a.department_id), None)
        if dept is None:
            continue
        lbt = LocalBodyType(a.local_body_type) if a.local_body_type else None
        offices[office_id(dept, a.rung, a.designation_en, lbt)] = a

    filled = 0
    for r in records:
        phone = (r.get("phone") or "").strip()
        email = (r.get("email") or "").strip()
        if not (phone or email):
            continue
        authority = offices.get(r.get("office_id"))
        if authority is None:
            continue

        touched = False
        if phone and not (authority.phone or "").strip():
            authority.phone = phone
            touched = True
        if email and not (authority.email or "").strip():
            authority.email = email
            touched = True
        if not touched:
            continue

        # Provenance travels with the contact. A number nobody can trace is one
        # nobody can check when it stops working.
        authority.source_url = r.get("source_url") or authority.source_url
        if r.get("verified_at"):
            authority.verified_at = datetime.strptime(
                r["verified_at"], "%Y-%m-%d"
            ).replace(tzinfo=timezone.utc)
        if r.get("office_name") and not authority.office_name_en:
            authority.office_name_en = r["office_name"]
        filled += 1

    if filled:
        db.flush()
    return filled


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument("--report", type=Path, default=Path("civic_contacts_report.md"))
    parser.add_argument(
        "--apply", action="store_true",
        help="write to the database; without it nothing is changed",
    )
    parser.add_argument("--org", help="organization uuid; required with --apply")
    args = parser.parse_args()

    records = json.loads(args.file.read_text())
    known = canonical_ids()
    good, problems = check(records)
    duplicates = find_duplicates(good)
    conflicts = find_conflicts(duplicates)

    text = report(records, good, problems, duplicates, conflicts, known)
    args.report.write_text(text)
    print(text)

    if args.apply:
        if not args.org:
            print("\n--apply needs --org <uuid>", file=sys.stderr)
            return 2
        if problems:
            print(
                f"\nRefusing to apply: {len(problems)} record(s) did not pass. "
                "Fix them or remove them.",
                file=sys.stderr,
            )
            return 1
        written = apply(good, args.org)
        print(f"\nWrote {written} contact(s).")
    else:
        print("\nDry run — nothing was written. Re-run with --apply --org <uuid>.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
