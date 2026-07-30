#!/usr/bin/env python3
"""
Scraper for Friends2Support blood donor database.
Scrapes donors from India -> Tamil Nadu -> Kanyakumari district -> all cities/taluks.
Saves results to scripts/friends2support_donors.csv

Usage:
  pip install requests beautifulsoup4 lxml
  $env:PYTHONIOENCODING="utf-8"; python scripts/scrape_friends2support.py
"""

import csv
import time
import re
import sys
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Missing dependencies. Run: pip install requests beautifulsoup4 lxml")
    sys.exit(1)

BASE_URL = "https://friends2support.org"
SEARCH_URL = f"{BASE_URL}/inner/news/searchresult.aspx"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Connection": "keep-alive",
    "Referer": f"{BASE_URL}/",
}

BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]


def parse_callback_options(response_text: str) -> dict[str, str]:
    """
    Parses ASP.NET callback response format:
    'sValue|Text||Value|Text||Value|Text||'
    Returns a dict mapping Text -> Value (e.g., 'Tamil Nadu' -> '24').
    """
    options = {}
    if not response_text.startswith("s"):
        return options
    
    clean_text = response_text[1:]
    parts = clean_text.split("||")
    for part in parts:
        if not part.strip():
            continue
        subparts = part.split("|")
        if len(subparts) >= 2:
            val = subparts[0].strip()
            name = subparts[1].strip()
            if val and name:
                options[name.lower()] = val
    return options


def get_viewstate(soup: BeautifulSoup) -> tuple[str, str]:
    """Extract viewstate and generator tokens from BeautifulSoup."""
    viewstate = soup.find("input", {"id": "__VIEWSTATE"})
    generator = soup.find("input", {"id": "__VIEWSTATEGENERATOR"})
    
    val_vs = viewstate.get("value", "") if viewstate else ""
    val_gen = generator.get("value", "") if generator else ""
    return val_vs, val_gen


def parse_donors_from_soup(soup: BeautifulSoup) -> list[dict]:
    """Parse donor rows from the GridView table."""
    donors = []
    table = soup.find("table", id="dgBloodDonorResults")
    if not table:
        return donors
        
    rows = table.find_all("tr", recursive=False)
    if len(rows) <= 2:
        return donors
        
    start_idx = 2
    end_idx = len(rows)
    
    # Check if the last row is a pager row
    last_row_cells = rows[-1].find_all("td", recursive=False)
    if len(last_row_cells) == 1 and last_row_cells[0].get("colspan"):
        end_idx = len(rows) - 1
        
    for idx in range(start_idx, end_idx):
        cells = [td.get_text(strip=True) for td in rows[idx].find_all("td", recursive=False)]
        if len(cells) < 3:
            continue
        
        name = cells[0]
        avail_str = cells[1].lower()
        mobile = cells[2]
        
        available = "unavailable" not in avail_str and "no" not in avail_str
        
        donors.append({
            "name": name,
            "available": available,
            "phone": mobile,
            "gender": None  # Gender not exposed in table, but mapped for schema
        })
    return donors


def parse_pager_links(table_soup: BeautifulSoup) -> dict:
    """Extract page numbers and targets from pager row."""
    links = {}
    for a in table_soup.find_all("a", href=re.compile(r"__doPostBack")):
        text = a.get_text(strip=True)
        href = a.get("href", "")
        m = re.search(r"__doPostBack\('([^']*)','([^']*)'\)", href)
        if m:
            target = m.group(1)
            if text.isdigit():
                links[int(text)] = target
            elif text == "...":
                links["next" if "ctl10" in target or "ctl34" in target or "ctl35" in target else "prev"] = target
    return links


def scrape_all_pages(
    session: requests.Session,
    search_payload: dict,
    generator_val: str,
) -> list[dict]:
    """Iteratively scrape all pages of results for a query."""
    donors = []
    
    try:
        r = session.post(SEARCH_URL, data=search_payload, timeout=30)
        r.raise_for_status()
    except Exception as e:
        print(f"[Search failed: {e}]")
        return donors

    soup = BeautifulSoup(r.text, "lxml")
    if "No Records Found" in r.text:
        return donors
        
    page_donors = parse_donors_from_soup(soup)
    donors.extend(page_donors)
    
    # Get initial viewstate for pagination postbacks
    viewstate, _ = get_viewstate(soup)
    
    table = soup.find("table", id="dgBloodDonorResults")
    if not table:
        return donors
        
    pager_links = parse_pager_links(table)
    if not pager_links:
        return donors  # Single page of results
        
    current_page = 1
    scraped_pages = {1}
    
    while True:
        next_page = current_page + 1
        if next_page in pager_links:
            target = pager_links[next_page]
            
            page_payload = {
                "__VIEWSTATE": viewstate,
                "__VIEWSTATEGENERATOR": generator_val,
                "__EVENTTARGET": target,
                "__EVENTARGUMENT": "",
                "dpBloodGroup": search_payload["dpBloodGroup"],
                "dpCountry": search_payload["dpCountry"],
                "dpState": search_payload["dpState"],
                "dpDistrict": search_payload["dpDistrict"],
                "dpCity": search_payload["dpCity"],
            }
            
            try:
                time.sleep(1.2)
                r_page = session.post(SEARCH_URL, data=page_payload, timeout=30)
                r_page.raise_for_status()
            except Exception as e:
                print(f"      [Page {next_page} failed: {e}]")
                break
                
            soup = BeautifulSoup(r_page.text, "lxml")
            viewstate, _ = get_viewstate(soup)
            
            page_donors = parse_donors_from_soup(soup)
            donors.extend(page_donors)
            
            scraped_pages.add(next_page)
            current_page = next_page
            
            table = soup.find("table", id="dgBloodDonorResults")
            if not table:
                break
            pager_links = parse_pager_links(table)
            
        elif "next" in pager_links:
            target = pager_links["next"]
            
            page_payload = {
                "__VIEWSTATE": viewstate,
                "__VIEWSTATEGENERATOR": generator_val,
                "__EVENTTARGET": target,
                "__EVENTARGUMENT": "",
                "dpBloodGroup": search_payload["dpBloodGroup"],
                "dpCountry": search_payload["dpCountry"],
                "dpState": search_payload["dpState"],
                "dpDistrict": search_payload["dpDistrict"],
                "dpCity": search_payload["dpCity"],
            }
            
            try:
                time.sleep(1.2)
                r_page = session.post(SEARCH_URL, data=page_payload, timeout=30)
                r_page.raise_for_status()
            except Exception as e:
                print(f"      [Next page set failed: {e}]")
                break
                
            soup = BeautifulSoup(r_page.text, "lxml")
            viewstate, _ = get_viewstate(soup)
            
            table = soup.find("table", id="dgBloodDonorResults")
            if not table:
                break
            pager_links = parse_pager_links(table)
            
            pager_row = table.find_all("tr", recursive=False)[0]
            active_span = pager_row.find("span")
            if active_span and active_span.get_text(strip=True).isdigit():
                loaded_page = int(active_span.get_text(strip=True))
                if loaded_page not in scraped_pages:
                    page_donors = parse_donors_from_soup(soup)
                    donors.extend(page_donors)
                    scraped_pages.add(loaded_page)
                    current_page = loaded_page
                else:
                    break
            else:
                break
        else:
            break
            
    return donors


def deduplicate(donors: list[dict]) -> list[dict]:
    seen_phones = set()
    unique = []
    for d in donors:
        phone = d.get("phone", "").strip()
        if phone:
            if phone not in seen_phones:
                seen_phones.add(phone)
                unique.append(d)
        else:
            unique.append(d)
    return unique


def main():
    output_path = Path(__file__).parent / "friends2support_donors.csv"
    session = requests.Session()
    session.headers.update(HEADERS)
    
    print("Connecting to Friends2Support...")
    try:
        r = session.get(SEARCH_URL, timeout=30)
        r.raise_for_status()
    except Exception as e:
        print(f"Critical error connecting to Friends2Support: {e}")
        sys.exit(1)
        
    soup = BeautifulSoup(r.text, "lxml")
    viewstate, generator = get_viewstate(soup)
    
    all_scraped_donors = []
    
    TARGETS = [
        ("Tamil Nadu", "Kanyakumari"),
        ("Kerala", "Thiruvananthapuram")
    ]
    
    for state_name, district_name in TARGETS:
        print(f"\n==================================================")
        print(f"Resolving: {state_name} -> {district_name}")
        print(f"==================================================")
        
        # 1. Resolve Country -> India (1|dpCountry)
        print("Resolving Country dropdown...")
        callback_payload = {
            "__VIEWSTATE": viewstate,
            "__VIEWSTATEGENERATOR": generator,
            "__CALLBACKID": "__Page",
            "__CALLBACKPARAM": "1|dpCountry"
        }
        try:
            r_cb = session.post(SEARCH_URL, data=callback_payload, timeout=30)
            states = parse_callback_options(r_cb.text)
        except Exception as e:
            print(f"Failed to resolve state list: {e}")
            continue
            
        state_val = states.get(state_name.lower())
        if not state_val:
            print(f"Error: Could not resolve '{state_name}' state value.")
            continue
        print(f"Resolved State: '{state_name}' -> ID {state_val}")
        
        # 2. Resolve State -> ID|dpState
        print("Resolving District dropdown...")
        callback_payload["__CALLBACKPARAM"] = f"{state_val}|dpState"
        try:
            r_cb = session.post(SEARCH_URL, data=callback_payload, timeout=30)
            districts = parse_callback_options(r_cb.text)
        except Exception as e:
            print(f"Failed to resolve district list: {e}")
            continue
            
        district_val = districts.get(district_name.lower())
        if not district_val:
            print(f"Error: Could not resolve '{district_name}' district value.")
            continue
        print(f"Resolved District: '{district_name}' -> ID {district_val}")
        
        # 3. Resolve District -> ID|dpDistrict
        print("Resolving City/Taluk dropdown...")
        callback_payload["__CALLBACKPARAM"] = f"{district_val}|dpDistrict"
        try:
            r_cb = session.post(SEARCH_URL, data=callback_payload, timeout=30)
            cities = parse_callback_options(r_cb.text)
        except Exception as e:
            print(f"Failed to resolve city list: {e}")
            continue
            
        print(f"Resolved {len(cities)} cities/taluks in {district_name} district.")
        
        # We will loop through all cities and all blood groups
        sorted_cities = sorted(cities.items())
        
        for city_name, city_id in sorted_cities:
            # Skip the "ALL" placeholder option if it exists
            if city_name == "all" or city_name == "select":
                continue
                
            print(f"\nScraping city: {city_name.upper()} (ID: {city_id})...")
            for bg in BLOOD_GROUPS:
                print(f"  Blood Group: {bg}", end=" ", flush=True)
                
                search_payload = {
                    "__VIEWSTATE": viewstate,
                    "__VIEWSTATEGENERATOR": generator,
                    "__EVENTTARGET": "",
                    "__EVENTARGUMENT": "",
                    "dpBloodGroup": bg,
                    "dpCountry": "1|dpCountry",
                    "dpState": f"{state_val}|dpState",
                    "dpDistrict": f"{district_val}|dpDistrict",
                    "dpCity": f"{city_id}",
                    "btnSearchDonor": "Search"
                }
                
                city_donors = scrape_all_pages(session, search_payload, generator)
                print(f"-> {len(city_donors)} donors found")
                
                # Map location hierarchy fields for output CSV
                for d in city_donors:
                    d["blood_group"] = bg
                    d["country"] = "INDIA"
                    d["state"] = state_name
                    d["district"] = district_name
                    d["city"] = city_name.title()
                    
                all_scraped_donors.extend(city_donors)
                time.sleep(1.5)  # Polite delay
            
    print(f"\nTotal raw records scraped: {len(all_scraped_donors)}")
    unique_donors = deduplicate(all_scraped_donors)
    print(f"After deduplication: {len(unique_donors)}")
    
    # Save to CSV
    fields = ["name", "blood_group", "phone", "available", "country", "state", "district", "city", "gender"]
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(unique_donors)
        
    print(f"Saved {len(unique_donors)} donors → {output_path}")


if __name__ == "__main__":
    main()
