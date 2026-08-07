"""Turn the scraped Collectorate 'Contact Us' page into a clean directory.

The source is the Kanniyakumari district site's contact page, saved as text.
It is a page meant for human eyes: department headings are bare lines, tables
repeat their header row, emails are obfuscated as `name[at]nic[dot]in`, phone
numbers are written a dozen ways, and a statewide TWAD water-lab list is
appended at the end that has nothing to do with this district.

This reads that once and writes a reviewable JSON file. It does not touch the
database — seeding is a separate, explicit step (seed_complaint_departments.py),
so a re-scrape can be diffed before anyone routes a citizen's complaint at it.

    python scripts/parse_district_contacts.py <scraped.txt> -o data/district_contacts.json
"""
import argparse
import json
import re
import sys
from pathlib import Path

# Headings that are real departments. Anything else picked up between tables is
# an address fragment or a stray line, not a section.
KNOWN_SECTIONS = {
    "Revenue Department", "Education", "RTO", "TWAD", "PWD",
    "Electricity Department", "Fisheries Department", "Health & Family Welfare",
    "Pollution Control", "Horticulture", "Animal Husbandry Department",
    "Agriculture", "Corporation&Municipality", "Fire", "Forest", "Industries",
    "Labour", "Panchayat Union Block Develop", "Police Department",
    "Registration", "Treasury", "Sports", "Social Welfare", "Mines", "Library",
    "Civil Supplies", "Com. Tax", "Welfare (BCW & ADW)", "Cooperative",
    "Tamil Nadu Rural Transformation Project - District Contact Details",
}

# The page's own anti-scraping obfuscation.
def deobfuscate_email(raw: str) -> str | None:
    if not raw:
        return None
    e = raw.strip()
    if e in ("-", "", "NA", "na"):
        return None
    e = (e.replace("[at]", "@").replace("[dot]", ".")
          .replace("[AT]", "@").replace("[DOT]", ".")
          .replace(" ", ""))
    # A few rows carry two addresses in one cell.
    first = re.split(r"[,;/]", e)[0].strip()
    return first if re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", first) else None


def clean_phone(raw: str) -> list[str]:
    """Return every dialable number in a cell.

    Cells hold '9445000930', '04652-279090', '4652279090 / 279091', and prose.
    A 10-digit number starting 6-9 is an Indian mobile; the rest are landlines
    that need the district STD code if they are missing it.
    """
    if not raw or raw.strip() in ("-", "", "NA"):
        return []
    out = []
    for chunk in re.split(r"[,/;&]| and ", raw):
        digits = re.sub(r"\D", "", chunk)
        if not digits:
            continue
        digits = digits.removeprefix("91") if len(digits) > 11 and digits.startswith("91") else digits
        if len(digits) == 10 and digits[0] in "6789":
            out.append(digits)
        elif 6 <= len(digits) <= 12:
            # Landline. The page drops the leading 0 on the STD code.
            out.append(digits if digits.startswith("0") else "0" + digits)
    # Keep order, drop repeats.
    return list(dict.fromkeys(out))


def parse(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    entries, skipped = [], []
    section = "Collectorate"
    pending_heading = None

    for ln in lines:
        if "\t" not in ln:
            t = ln.strip()
            if t in KNOWN_SECTIONS:
                pending_heading = t
            continue

        cells = [c.strip() for c in ln.split("\t")]
        if cells[0] == "S.No":
            # The heading immediately above a table header names that table.
            if pending_heading:
                section = pending_heading
                pending_heading = None
            continue
        if not re.match(r"^\d+$", cells[0] or ""):
            continue

        def cell(i):
            v = cells[i] if len(cells) > i else ""
            return "" if v in ("-", "NA") else v

        name, designation = cell(1), cell(2)
        email = deobfuscate_email(cell(3))
        mobiles = clean_phone(cell(4))
        landlines = clean_phone(cell(5))
        address = cell(6)

        rec = {
            "department": section,
            "name": name or designation,
            "designation": designation or name,
            "email": email,
            "mobiles": mobiles,
            "landlines": landlines,
            "address": address or None,
        }
        # A row with no way to reach anyone is not a contact.
        if not (email or mobiles or landlines):
            skipped.append(rec)
            continue
        entries.append(rec)

    return {"entries": entries, "unreachable": skipped}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path)
    ap.add_argument("-o", "--out", type=Path, required=True)
    args = ap.parse_args()

    data = parse(args.source)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")

    e = data["entries"]
    depts = {}
    for r in e:
        depts.setdefault(r["department"], {"rows": 0, "email": 0})
        depts[r["department"]]["rows"] += 1
        if r["email"]:
            depts[r["department"]]["email"] += 1

    print(f"{len(e)} contacts across {len(depts)} departments -> {args.out}")
    print(f"{sum(1 for r in e if r['email'])} have an email address")
    print(f"{len(data['unreachable'])} rows had no email and no phone (dropped)")
    print()
    print(f"{'department':<52}{'rows':>6}{'email':>7}")
    for d, s in sorted(depts.items(), key=lambda x: -x[1]["rows"]):
        print(f"  {d[:50]:<50}{s['rows']:>6}{s['email']:>7}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
