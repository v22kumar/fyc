"""Blood donor matching: group compatibility, donation eligibility, and distance.

Pure, dependency-free helpers shared by the donor search / nearby / emergency
endpoints. Kept out of the router so they can be unit-tested in isolation and
reused by the emergency fan-out.
"""
from __future__ import annotations

import math
from datetime import date, timedelta
from typing import Optional

# RBC compatibility — for a RECIPIENT of group X, the donor groups whose blood
# they can safely receive. (O- is the universal donor; AB+ the universal
# recipient.) Used so a request for A+ also surfaces A-, O+ and O- donors.
COMPATIBLE_DONORS: dict[str, list[str]] = {
    "O-": ["O-"],
    "O+": ["O-", "O+"],
    "A-": ["O-", "A-"],
    "A+": ["O-", "O+", "A-", "A+"],
    "B-": ["O-", "B-"],
    "B+": ["O-", "O+", "B-", "B+"],
    "AB-": ["O-", "A-", "B-", "AB-"],
    "AB+": ["O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"],
}

# Whole-blood donation interval. India's NBTC guideline is 90 days (3 months)
# for men and 120 for women; we use the conservative 90-day default and can
# refine per-donor later if sex is captured.
ELIGIBILITY_DAYS = 90


def compatible_donor_groups(recipient_group: str) -> list[str]:
    """Donor groups that can give to a recipient of `recipient_group`.
    Unknown/blank input falls back to an exact match so we never widen wrongly."""
    if not recipient_group:
        return []
    g = recipient_group.strip().upper()
    return COMPATIBLE_DONORS.get(g, [g])


def eligible_on(last_donation_date: Optional[date]) -> Optional[date]:
    """The date a donor becomes eligible again. None → eligible now (never
    donated / unknown)."""
    if last_donation_date is None:
        return None
    return last_donation_date + timedelta(days=ELIGIBILITY_DAYS)


def is_eligible(last_donation_date: Optional[date], today: Optional[date] = None) -> bool:
    """True if the donor can donate today (cooldown elapsed or never donated)."""
    nxt = eligible_on(last_donation_date)
    if nxt is None:
        return True
    return (today or date.today()) >= nxt


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres between two lat/lng points."""
    r = 6371.0  # Earth radius, km
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    )
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))
