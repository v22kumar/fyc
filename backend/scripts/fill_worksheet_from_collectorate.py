"""Fill the civic worksheet from the Collectorate contact page.

The collection pipeline was written on the assumption that nobody here could
reach a government site — and nobody could. But the page was fetched anyway, by
a person, and saved. That closes the gap the pipeline was built around, so long
as the provenance rules it enforces are honoured rather than worked around.

So this does not invent anything:

  * `--source-url` is required. The scrape came from one page and only the
    person who fetched it knows which; guessing it would put an unread URL
    beside a real phone number, which is the exact failure the schema exists to
    stop.
  * `--verified-at` is the day that person read the page, not the day this runs.
  * An office the page does not cover keeps `not_found`. A blank stays blank.

    python scripts/parse_district_contacts.py <saved page>.txt \
        -o seeds/sources/collectorate_contacts.parsed.json
    python scripts/fill_worksheet_from_collectorate.py \
        --source-url https://... --verified-at 2026-08-07
"""
import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

SEEDS = Path(__file__).resolve().parent.parent / "seeds"

# Which scraped department, and which designation within it, answers for each
# canonical office. Matching is on the designation text the page uses, which is
# terse and inconsistent ("JD", "SP", "Commissioner"), so each rule is explicit
# rather than fuzzy — a wrong match here misroutes a real complaint.
RULES: dict[str, tuple[str, str]] = {
    # office_id: (scraped department, regex matching that page's designation)
    "COLLECTORATE/50/district_collector": ("Collectorate", r"^District Collector$"),
    "POLICE/50/superintendent_of_police": ("Police Department", r"^SP$"),
    "POLICE/40/deputy_superintendent_of_police": ("Police Department", r"^(ADSP|DSP)"),
    "TANGEDCO/50/executive_engineer": ("Electricity Department", r"^Executive Engineer"),
    "TANGEDCO/40/assistant_executive_engineer": ("Electricity Department", r"^Assistant Executive Engineer"),
    "TWAD/50/executive_engineer": ("TWAD", r"Executive Engineer"),
    "REVENUE/40/revenue_divisional_officer": ("Revenue Department", r"^(RDO|Sub-Collector)"),
    "REVENUE/30/tahsildar": ("Revenue Department", r"^Tahsildar"),
    "ULB_ENGINEERING/30/commissioner@CORPORATION": ("Corporation&Municipality", r"^Commissioner$"),
    "ULB_WATER/30/commissioner@CORPORATION": ("Corporation&Municipality", r"^Commissioner$"),
    "ULB_ELECTRICAL/30/commissioner@CORPORATION": ("Corporation&Municipality", r"^Commissioner$"),
    "ULB_HEALTH/30/city_health_officer@CORPORATION": ("Corporation&Municipality", r"City Health Officer"),
    "ULB_ENGINEERING/20/assistant_engineer": ("Corporation&Municipality", r"City Engineer|^Assistant Engineer"),
    "HEALTH_SERVICES/50/deputy_director_of_health_services": ("Health & Family Welfare", r"^DD$"),
    "PANCHAYAT_UNION/30/block_development_officer": ("Panchayat Union Block Develop", r"BDO|Block Development"),
    "SCHOOL_EDUCATION/50/chief_educational_officer": ("Education", r"^CEO$|Chief Educational"),
    "TNPCB/50/district_environmental_engineer": ("Pollution Control", r"Environmental Engineer|^DEE$"),
    "HIGHWAYS/50/divisional_engineer": ("PWD", r"^Executive Engineer"),
}


def best(entries: list[dict], department: str, pattern: str) -> dict | None:
    """The first row of that department whose designation matches.

    Preference goes to a row carrying an email, because a routing target that
    can only be phoned is a weaker target — but a phone-only match is still
    returned rather than dropped.
    """
    rx = re.compile(pattern, re.I)
    hits = [r for r in entries
            if r["department"] == department and rx.search(r["designation"] or "")]
    if not hits:
        return None
    return next((h for h in hits if h["email"]), hits[0])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-url", required=True,
                    help="the exact page the contacts were read from")
    ap.add_argument("--verified-at", default=date.today().isoformat(),
                    help="YYYY-MM-DD, the day a human read that page")
    ap.add_argument("--parsed", type=Path,
                    default=SEEDS / "sources" / "collectorate_contacts.parsed.json")
    ap.add_argument("--worksheet", type=Path,
                    default=SEEDS / "civic_contacts.worksheet.json")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not re.match(r"^https?://", args.source_url):
        print("source-url must be the real page URL", file=sys.stderr)
        return 2
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", args.verified_at):
        print("verified-at must be YYYY-MM-DD", file=sys.stderr)
        return 2

    entries = json.loads(args.parsed.read_text(encoding="utf-8"))["entries"]
    sheet = json.loads(args.worksheet.read_text(encoding="utf-8"))

    filled, already, unmatched = 0, 0, []
    for row in sheet:
        oid = row["office_id"]
        if oid not in RULES:
            continue
        if row.get("phone") or row.get("email"):
            already += 1
            continue

        department, pattern = RULES[oid]
        hit = best(entries, department, pattern)
        if not hit:
            unmatched.append((oid, department))
            continue

        phones = hit["mobiles"] + hit["landlines"]
        row["phone"] = ", ".join(phones[:2]) or None
        row["email"] = hit["email"]
        row["address"] = hit.get("address") or row.get("address")
        row["source_url"] = args.source_url
        row["verified_at"] = args.verified_at
        row["confidence"] = "official_government_website"
        row["notes"] = (f"From the Collectorate contact page, department "
                        f"\"{department}\", listed as \"{hit['designation']}\".")
        filled += 1

    print(f"{filled} office(s) filled, {already} already had a contact, "
          f"{len(sheet) - filled - already} still empty")
    if unmatched:
        print("\nNo row on that page matched these offices:")
        for oid, dept in unmatched:
            print(f"  {oid}  (looked in \"{dept}\")")

    covered = {o for o in RULES}
    print(f"\nThe page can only speak for {len(covered)} of the {len(sheet)} offices. "
          "The rest — ward councillors, village panchayats, section offices —\n"
          "are not on a district contact page and still need collecting.")

    if args.dry_run:
        print("\ndry run — worksheet not written")
    else:
        args.worksheet.write_text(
            json.dumps(sheet, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"\nwrote {args.worksheet}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
