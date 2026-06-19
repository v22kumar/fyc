"""
Thirukkural service.

Serves the 1330 Thirukkural couplets (Tamil + English) from a bundled JSON
dataset. The data is universal public content — not tenant-scoped — so this
service holds no database or organization state.

Dataset credit: github.com/tk120404/thirukkural (couplets, meanings and
English translations). Bundled locally so the feature works offline and does
not depend on any third-party runtime API.
"""
import json
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Optional

_DATA_PATH = Path(__file__).resolve().parent.parent / "data" / "thirukkural.json"

TOTAL_KURALS = 1330

# Thirukkural has a fixed canonical structure: 3 paals (sections), each split
# into adhikarams (chapters) of exactly 10 kurals. The paal a kural belongs to
# is therefore derivable from its number alone.
_PAAL_RANGES = [
    (1, 380, "அறத்துப்பால்", "Virtue"),
    (381, 1080, "பொருட்பால்", "Wealth"),
    (1081, 1330, "இன்பத்துப்பால்", "Love"),
]


@lru_cache(maxsize=1)
def _load_kurals() -> dict[int, dict]:
    """Load and index the dataset by kural number. Cached for process lifetime."""
    with open(_DATA_PATH, encoding="utf-8") as f:
        raw = json.load(f)
    return {k["number"]: k for k in raw}


def _paal_for(number: int) -> tuple[str, str]:
    for start, end, ta, en in _PAAL_RANGES:
        if start <= number <= end:
            return ta, en
    return "", ""


def _enrich(entry: dict) -> dict:
    """Add derived structural fields (adhikaram + paal) to a raw entry."""
    number = entry["number"]
    paal_ta, paal_en = _paal_for(number)
    return {
        **entry,
        "adhikaram": (number - 1) // 10 + 1,
        "paal_ta": paal_ta,
        "paal_en": paal_en,
    }


def get_kural(number: int) -> Optional[dict]:
    """Return the kural with the given number (1–1330), or None if out of range."""
    entry = _load_kurals().get(number)
    return _enrich(entry) if entry else None


def daily_kural_number(today: date) -> int:
    """
    Deterministically map a calendar date to a kural number (1–1330).

    Everyone sees the same kural on a given day. Uses a SHA-256 hash of the
    date string so the sequence is non-sequential (feels random) but still
    reproducible and collision-free across all 1330 values.
    """
    import hashlib
    digest = hashlib.sha256(today.isoformat().encode()).hexdigest()
    return int(digest, 16) % TOTAL_KURALS + 1


def get_daily_kural(today: Optional[date] = None) -> dict:
    """Return today's Thirukkural (UTC date by default)."""
    today = today or date.today()
    return get_kural(daily_kural_number(today))  # type: ignore[return-value]
