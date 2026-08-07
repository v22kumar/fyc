"""The import path must be no softer than the front door.

The PATCH endpoint refuses a contact with no source. A bulk importer that did
not would be a way around the rule that decides where complaints about real
people's streets get sent — and a spreadsheet is exactly where an untraceable
entry creeps in.

These tests hold the refusals, and hold the things that are *not* refusals:
duplicates and disagreements between sources are normal, and choosing between
them is a judgement a person makes.
"""
import json

import pytest

from scripts.civic_contacts_worksheet import build, office_id
from scripts.import_civic_contacts import (
    canonical_ids, check, find_conflicts, find_duplicates, report,
)


@pytest.fixture
def blank():
    """The worksheet as generated: every office, no contacts."""
    return build()


def _record(**over):
    base = {
        "office_id": "COLLECTORATE/50/district_collector",
        "department": "COLLECTORATE",
        "designation_en": "District Collector",
        "phone": None,
        "email": None,
        "source_url": None,
        "verified_at": None,
        "confidence": "not_found",
    }
    base.update(over)
    return base


# ── The worksheet ────────────────────────────────────────────────────────────

def test_the_worksheet_ships_no_contacts(blank):
    """It is a sheet to fill in, not data to trust."""
    assert len(blank) == 39
    for row in blank:
        assert row["phone"] is None and row["email"] is None
        assert row["source_url"] is None
        assert row["confidence"] == "not_found"


def test_every_office_says_where_to_look(blank):
    """A hint is a place to look, not a claimed fact — and a collector with no
    starting URL is a collector who uses a search engine and a random directory.
    """
    assert all(row["source_hint"] for row in blank)


def test_the_worksheet_matches_the_canonical_directory(blank):
    """Generated from the seed rather than typed, so the two cannot drift. Add
    an office to the seed and it appears here, empty."""
    assert {r["office_id"] for r in blank} == set(canonical_ids())


def test_office_ids_are_stable_across_regeneration():
    """A collector part-way through a file must not lose their work because the
    worksheet was regenerated."""
    assert {r["office_id"] for r in build()} == {r["office_id"] for r in build()}


# ── What import refuses ──────────────────────────────────────────────────────

def test_a_contact_with_no_source_is_rejected():
    good, problems = check([
        _record(email="someone@example.invalid", verified_at="2026-08-07",
                confidence="official_government_website")
    ])

    assert good == []
    assert "source_url" in str(problems[0])


def test_a_contact_with_no_date_is_rejected():
    """`verified_at` is what makes the staleness warning possible a year later.
    Without it a contact is un-ageable."""
    good, problems = check([
        _record(email="a@b.gov.in", source_url="https://kanniyakumari.nic.in/",
                confidence="official_government_website")
    ])

    assert good == []
    assert "verified_at" in str(problems[0])


def test_an_unknown_office_is_never_created():
    """Import fills in offices; it does not invent them. A typo in a spreadsheet
    must not silently add a desk that does not exist."""
    good, problems = check([_record(office_id="MADE_UP/99/someone")])

    assert good == []
    assert "canonical" in str(problems[0])


def test_not_found_alongside_a_phone_number_is_rejected():
    """One of the two is wrong and a human should say which."""
    good, problems = check([
        _record(phone="04652-000000", source_url="https://kanniyakumari.nic.in/",
                verified_at="2026-08-07", confidence="not_found")
    ])

    assert good == []
    assert "not_found" in str(problems[0])


def test_claiming_a_source_with_nothing_recorded_is_rejected():
    """The mirror mistake: a row marked as found from an official site, with no
    contact on it."""
    good, problems = check([_record(confidence="official_government_website")])

    assert good == []
    assert "no phone or email" in str(problems[0])


def test_a_malformed_email_is_rejected():
    good, problems = check([
        _record(email="not-an-address", source_url="https://kanniyakumari.nic.in/",
                verified_at="2026-08-07", confidence="official_government_website")
    ])

    assert good == []
    assert "email" in str(problems[0])


def test_a_malformed_date_is_rejected():
    good, problems = check([
        _record(email="a@b.gov.in", source_url="https://kanniyakumari.nic.in/",
                verified_at="7 August 2026", confidence="official_government_website")
    ])

    assert good == []
    assert "YYYY-MM-DD" in str(problems[0])


def test_a_blank_worksheet_passes_with_nothing_to_import(blank):
    """Collecting nothing yet is a legitimate state, not an error."""
    good, problems = check(blank)

    assert problems == []
    assert len(good) == 39
    assert not any(r.get("phone") or r.get("email") for r in good)


def test_a_properly_sourced_contact_is_accepted():
    good, problems = check([
        _record(email="collector@example.invalid", phone="04652-279000",
                source_url="https://kanniyakumari.nic.in/directory/",
                verified_at="2026-08-07", confidence="official_government_website")
    ])

    assert problems == []
    assert len(good) == 1


# ── What import reports instead of refusing ──────────────────────────────────

def test_two_numbers_for_one_office_are_reported_not_rejected():
    """A zone office legitimately has several published numbers."""
    rows = [
        _record(phone="04652-111111", source_url="https://a.gov.in/",
                verified_at="2026-08-07", confidence="official_government_website"),
        _record(phone="04652-222222", source_url="https://b.gov.in/",
                verified_at="2026-08-07", confidence="department_portal"),
    ]
    good, problems = check(rows)
    duplicates = find_duplicates(good)

    assert problems == []
    assert len(duplicates) == 1


def test_sources_that_disagree_are_surfaced_with_both_urls():
    """A stale page is the usual cause. Picking a winner by rule is how the
    wrong number becomes permanent — so both are shown and a person decides."""
    rows = [
        _record(email="old@example.invalid", source_url="https://a.gov.in/",
                verified_at="2026-08-07", confidence="official_government_website"),
        _record(email="new@example.invalid", source_url="https://b.gov.in/",
                verified_at="2026-08-07", confidence="official_government_website"),
    ]
    good, _ = check(rows)
    conflicts = find_conflicts(find_duplicates(good))

    assert len(conflicts) == 1
    values = conflicts["COLLECTORATE/50/district_collector"][0]["values"]
    assert {v["source_url"] for v in values} == {"https://a.gov.in/", "https://b.gov.in/"}


def test_the_report_names_what_is_still_missing(blank):
    good, problems = check(blank)
    text = report(blank, good, problems, {}, {}, canonical_ids())

    assert "Offices still without one: **39**" in text
    assert "COLLECTORATE/50/district_collector" in text
    # The confidence table is the answer to "how much of this can we trust".
    assert "official_government_website" in text
