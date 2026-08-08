"""Applying collected contacts on boot.

The directory was seeded with forty offices and every contact blank, and the
worksheet that fills them was parsed, validated and committed weeks before it
was ever applied to a running database. Nobody noticed, because a dry run and a
deploy look identical in a terminal — and the symptom was a Complaint Box that
answers "who do I call" with four rows of "no contact collected yet".
"""
import json
import uuid

import pytest

from app.models.civic import Authority, Department
from app.models.tenant import Organization
from scripts.import_civic_contacts import apply_worksheet
from seeds.civic_directory import seed


@pytest.fixture
def club(db):
    org = Organization(id=uuid.uuid4(), slug="boot-club",
                       name_en="Club", name_ta="கழகம்")
    db.add(org)
    db.commit()
    seed(db, org.id)
    return org


def _worksheet(tmp_path, rows):
    p = tmp_path / "contacts.json"
    p.write_text(json.dumps(rows))
    return p


def _an_office(db, club, code):
    dept = (db.query(Department)
              .filter(Department.organization_id == club.id,
                      Department.code == code).first())
    return (db.query(Authority)
              .filter(Authority.organization_id == club.id,
                      Authority.department_id == dept.id)
              .order_by(Authority.rung.asc()).first())


def _office_id_of(db, club, authority):
    from app.models.civic import LocalBodyType
    from scripts.civic_contacts_worksheet import office_id
    dept = db.get(Department, authority.department_id)
    lbt = (LocalBodyType(authority.local_body_type)
           if authority.local_body_type else None)
    return office_id(dept.code, authority.rung, authority.designation_en, lbt)


def test_a_blank_office_gets_its_number(db, club, tmp_path):
    a = _an_office(db, club, "ULB_ELECTRICAL")
    assert not (a.phone or "").strip(), "starts blank, as the seed leaves it"

    path = _worksheet(tmp_path, [{
        "office_id": _office_id_of(db, club, a),
        "phone": "9443132365",
        "email": "ae@nagercoil.gov.in",
        "source_url": "https://kanniyakumari.nic.in/contact-us/",
        "verified_at": "2026-08-07",
    }])
    assert apply_worksheet(db, club.id, path) == 1
    db.refresh(a)
    assert a.phone == "9443132365"
    assert a.source_url, "a number nobody can trace is one nobody can check"


def test_it_never_overwrites_what_an_organiser_corrected(db, club, tmp_path):
    """The whole reason this is safe to run on every boot.

    Somebody who fixes a wrong number by hand must not have it reverted on the
    next deploy by a file that was right in August.
    """
    a = _an_office(db, club, "ULB_ELECTRICAL")
    a.phone = "9876543210"
    db.commit()

    path = _worksheet(tmp_path, [{
        "office_id": _office_id_of(db, club, a),
        "phone": "9443132365",
        "source_url": "https://kanniyakumari.nic.in/contact-us/",
        "verified_at": "2026-08-07",
    }])
    apply_worksheet(db, club.id, path)
    db.refresh(a)
    assert a.phone == "9876543210"


def test_running_it_twice_changes_nothing_the_second_time(db, club, tmp_path):
    a = _an_office(db, club, "ULB_ELECTRICAL")
    path = _worksheet(tmp_path, [{
        "office_id": _office_id_of(db, club, a),
        "phone": "9443132365",
        "source_url": "https://x.invalid", "verified_at": "2026-08-07",
    }])
    assert apply_worksheet(db, club.id, path) == 1
    assert apply_worksheet(db, club.id, path) == 0


def test_a_missing_worksheet_is_not_an_error(db, club, tmp_path):
    """Boot must not fail because a data file is absent."""
    assert apply_worksheet(db, club.id, tmp_path / "nope.json") == 0


def test_an_unknown_office_is_skipped_not_created(db, club, tmp_path):
    path = _worksheet(tmp_path, [{
        "office_id": "NOT_A_REAL/99/desk", "phone": "9443132365",
        "source_url": "https://x.invalid", "verified_at": "2026-08-07",
    }])
    assert apply_worksheet(db, club.id, path) == 0
