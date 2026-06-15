#!/usr/bin/env python3
"""
Scraper for Friends2Support blood donor database.
Scrapes donors from Tamil Nadu (Nagercoil / Kanyakumari district).
Saves results to scripts/friends2support_donors.csv

Usage:
  pip install requests beautifulsoup4 lxml
  python scripts/scrape_friends2support.py

The script searches for all blood groups across Tamil Nadu / Kanyakumari.
Results are deduplicated by phone number before saving.
"""

import csv
import time
import re
import sys
import os
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Missing dependencies. Run: pip install requests beautifulsoup4 lxml")
    sys.exit(1)

BASE_URL = "https://friends2support.org"
SEARCH_URL = f"{BASE_URL}/inner/news/searchresult.aspx"

# Browser-like headers to avoid 403
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Referer": f"{BASE_URL}/",
}

BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

# Search locations — try city-level first, then district, then state
LOCATIONS = [
    "Nagercoil",
    "Kanyakumari",
    "Marthandam",
    "Colachel",
    "Kuzhithurai",
]


def get_viewstate(session: requests.Session, url: str, params: dict | None = None) -> dict:
    """GET the page and extract ASP.NET form tokens."""
    r = session.get(url, params=params, timeout=30)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "lxml")

    tokens = {}
    for field in ["__VIEWSTATE", "__VIEWSTATEGENERATOR", "__EVENTVALIDATION", "__EVENTTARGET", "__EVENTARGUMENT"]:
        tag = soup.find("input", {"name": field})
        if tag:
            tokens[field] = tag.get("value", "")
    return tokens, soup


def parse_donors(soup: BeautifulSoup) -> list[dict]:
    """Parse donor rows from the results page."""
    donors = []

    # Friends2Support results are typically in a table or div grid
    # Try table rows first
    table = soup.find("table", id=re.compile(r"Grid|grid|Result|result|donor|Donor", re.I))
    if not table:
        # Fallback: find any table with donor-like content
        tables = soup.find_all("table")
        for t in tables:
            text = t.get_text()
            if any(bg in text for bg in ["A+", "B+", "O+", "AB+"]):
                table = t
                break

    if not table:
        return donors

    rows = table.find_all("tr")
    for row in rows[1:]:  # skip header
        cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if len(cells) < 3:
            continue

        # Try to identify columns by content heuristics
        donor = {}
        for cell in cells:
            cell_clean = cell.strip()
            if re.match(r"^(A|B|AB|O)[+-]$", cell_clean):
                donor["blood_group"] = cell_clean
            elif re.search(r"\d{10}", cell_clean):
                phone = re.search(r"\d{10}", cell_clean)
                if phone:
                    donor["phone"] = phone.group()
            elif cell_clean.lower() in ("yes", "available", "ready"):
                donor["available"] = True
            elif cell_clean.lower() in ("no", "not available", "unavailable"):
                donor["available"] = False
            elif not donor.get("name") and re.match(r"^[A-Za-z .']{3,60}$", cell_clean):
                donor["name"] = cell_clean
            elif not donor.get("city") and re.match(r"^[A-Za-z ]{3,50}$", cell_clean) and donor.get("name"):
                donor["city"] = cell_clean

        if donor.get("name") or donor.get("phone"):
            donors.append(donor)

    return donors


def get_total_pages(soup: BeautifulSoup) -> int:
    """Try to find pagination and total pages."""
    # Look for pager links like "1 2 3 ... 10"
    pager = soup.find(id=re.compile(r"[Pp]ager|[Pp]ager|[Pp]age"))
    if pager:
        page_links = pager.find_all("a")
        nums = []
        for a in page_links:
            try:
                nums.append(int(a.get_text(strip=True)))
            except ValueError:
                pass
        if nums:
            return max(nums)

    # Try looking for "Page X of Y" text
    m = re.search(r"[Pp]age\s+\d+\s+of\s+(\d+)", soup.get_text())
    if m:
        return int(m.group(1))

    return 1


def scrape_by_location_and_group(
    session: requests.Session,
    location: str,
    blood_group: str,
) -> list[dict]:
    """Search for donors in a location with a specific blood group."""
    print(f"  Searching: {location} / {blood_group}", end=" ", flush=True)

    try:
        tokens, soup = get_viewstate(session, SEARCH_URL)
    except Exception as e:
        print(f"[GET failed: {e}]")
        return []

    # Build form payload — field names based on typical Friends2Support form inspection
    # Common field names discovered from the ASP.NET form
    payload = {
        **tokens,
        "__EVENTTARGET": "",
        "__EVENTARGUMENT": "",
        # Try common field name patterns for blood group and city
        "ctl00$ContentPlaceHolder1$ddlBloodGroup": blood_group,
        "ctl00$ContentPlaceHolder1$txtCity": location,
        "ctl00$ContentPlaceHolder1$txtState": "Tamil Nadu",
        "ctl00$ContentPlaceHolder1$btnSearch": "Search",
        # Alternate field names
        "ddlBloodGroup": blood_group,
        "txtCity": location,
        "txtState": "Tamil Nadu",
        "btnSearch": "Search",
    }

    try:
        r = session.post(SEARCH_URL, data=payload, timeout=30)
        r.raise_for_status()
    except Exception as e:
        print(f"[POST failed: {e}]")
        return []

    soup = BeautifulSoup(r.text, "lxml")
    donors = parse_donors(soup)
    total_pages = get_total_pages(soup)
    print(f"→ page 1/{total_pages}, {len(donors)} donors")

    # Handle pagination
    for page in range(2, total_pages + 1):
        time.sleep(1.5)
        # ASP.NET paging often via __doPostBack with page event target
        page_payload = {
            **tokens,
            "__EVENTTARGET": f"ctl00$ContentPlaceHolder1$GridView1",
            "__EVENTARGUMENT": f"Page${page}",
            "ctl00$ContentPlaceHolder1$ddlBloodGroup": blood_group,
            "ctl00$ContentPlaceHolder1$txtCity": location,
            "ctl00$ContentPlaceHolder1$txtState": "Tamil Nadu",
        }
        try:
            r = session.post(SEARCH_URL, data=page_payload, timeout=30)
            r.raise_for_status()
            page_soup = BeautifulSoup(r.text, "lxml")
            page_donors = parse_donors(page_soup)
            print(f"    page {page}/{total_pages}: {len(page_donors)} donors")
            donors.extend(page_donors)
            # Refresh viewstate from this response for next page
            for field in ["__VIEWSTATE", "__VIEWSTATEGENERATOR", "__EVENTVALIDATION"]:
                tag = page_soup.find("input", {"name": field})
                if tag:
                    tokens[field] = tag.get("value", "")
        except Exception as e:
            print(f"    page {page} failed: {e}")
            break

    for d in donors:
        d.setdefault("source_location", location)
        d.setdefault("blood_group", blood_group)
        d.setdefault("available", True)

    return donors


def deduplicate(donors: list[dict]) -> list[dict]:
    seen_phones = set()
    seen_names = set()
    unique = []
    for d in donors:
        phone = d.get("phone", "").strip()
        name = d.get("name", "").strip().lower()
        key = phone if phone else name
        if key and key not in seen_phones:
            seen_phones.add(key)
            unique.append(d)
        elif not key:
            # No phone or name — include anyway to not lose data
            unique.append(d)
    return unique


def save_csv(donors: list[dict], path: str) -> None:
    fields = ["name", "blood_group", "phone", "city", "available", "source_location"]
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(donors)
    print(f"\nSaved {len(donors)} donors → {path}")


def main():
    output_path = Path(__file__).parent / "friends2support_donors.csv"

    session = requests.Session()
    session.headers.update(HEADERS)

    # Warm up session with homepage to get cookies
    print("Connecting to Friends2Support...")
    try:
        session.get(BASE_URL, timeout=20)
        time.sleep(1)
    except Exception as e:
        print(f"Warning: homepage fetch failed ({e}), continuing anyway...")

    all_donors: list[dict] = []

    for location in LOCATIONS:
        for blood_group in BLOOD_GROUPS:
            donors = scrape_by_location_and_group(session, location, blood_group)
            all_donors.extend(donors)
            time.sleep(2)  # polite delay between requests

    print(f"\nTotal raw records: {len(all_donors)}")
    unique = deduplicate(all_donors)
    print(f"After deduplication: {len(unique)}")

    if not unique:
        print("\nNo donors found. The site's form field names may differ from expected.")
        print("Try inspecting the live page HTML at:")
        print(f"  {SEARCH_URL}")
        print("Look for <input> and <select> name attributes in the search form,")
        print("then update the payload field names in scrape_by_location_and_group().")
        # Still save an empty CSV so the file exists
        save_csv([], str(output_path))
        return

    save_csv(unique, str(output_path))

    # Print summary
    by_group: dict[str, int] = {}
    for d in unique:
        g = d.get("blood_group", "Unknown")
        by_group[g] = by_group.get(g, 0) + 1
    print("\nBreakdown by blood group:")
    for g, count in sorted(by_group.items()):
        print(f"  {g:4s}: {count}")


if __name__ == "__main__":
    main()
