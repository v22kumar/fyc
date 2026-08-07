"""A complaint has to reach the right office, and the right office depends on
where you are standing.

The system this replaces mapped one category to one office for the whole
district: a pothole in Nagercoil town and a pothole in a village two kilometres
away went to the same address, and only one of them was right. These tests hold
the two facts that fix it — jurisdiction is resolved and admitted, and the route
is a ladder rather than a single name.
"""
import uuid

import pytest

from app.models.civic import (
    Authority, CivicCategory, Department, JurisdictionScope, LocalBodyType,
    RoutingRule, normalise_category,
)
from app.models.geography import GeographicNode, GeoLevel
from app.models.tenant import Organization
from app.services import jurisdiction as juris
from app.services.complaint_routing import build_ladder
from seeds.civic_directory import seed


@pytest.fixture
def org(db):
    o = Organization(
        id=uuid.uuid4(), slug="test-club",
        name_en="Test Club", name_ta="சோதனை கழகம்",
    )
    db.add(o)
    db.commit()
    return o


@pytest.fixture
def seeded(db, org):
    made = seed(db, org.id)
    assert made["departments"] > 0 and made["rules"] > 0
    return org


def _node(db, name, level, local_body_type=None, parent=None):
    n = GeographicNode(
        id=uuid.uuid4(), level=level, name_en=name, name_ta=name,
        local_body_type=local_body_type.value if local_body_type else None,
        parent_id=parent.id if parent else None,
    )
    db.add(n)
    db.commit()
    return n


# ── Jurisdiction ─────────────────────────────────────────────────────────────

def test_a_classified_place_answers_for_itself(db, org):
    ward = _node(db, "Ward 12", GeoLevel.WARD, LocalBodyType.CORPORATION)

    got = juris.resolve(db, geography_id=ward.id)

    assert got.local_body_type is LocalBodyType.CORPORATION
    assert got.confidence is juris.Confidence.DECLARED
    assert got.is_urban
    assert not got.needs_human_check


def test_an_unclassified_street_inherits_from_the_town(db, org):
    """The common real case. Somebody records that Nagercoil is a Corporation
    and never touches the streets beneath it — those streets are still governed
    by a Corporation."""
    town = _node(db, "Nagercoil", GeoLevel.VILLAGE, LocalBodyType.CORPORATION)
    street = _node(db, "Balamore Road", GeoLevel.STREET, None, parent=town)

    got = juris.resolve(db, geography_id=street.id)

    assert got.local_body_type is LocalBodyType.CORPORATION
    assert got.confidence is juris.Confidence.INHERITED
    assert "Nagercoil" in got.reason


def test_a_village_is_not_quietly_treated_as_the_city(db, org):
    village = _node(db, "Thovalai", GeoLevel.VILLAGE, LocalBodyType.VILLAGE_PANCHAYAT)

    got = juris.resolve(db, geography_id=village.id)

    assert got.local_body_type is LocalBodyType.VILLAGE_PANCHAYAT
    assert not got.is_urban


def test_knowing_nothing_is_reported_as_a_guess(db, org):
    """The answer is still usable — but it is labelled, so the club reviewer is
    asked to confirm rather than told a fact that was invented."""
    got = juris.resolve(db)

    assert got.local_body_type is juris.DEFAULT_LOCAL_BODY
    assert got.confidence is juris.Confidence.GUESSED
    assert got.needs_human_check


def test_the_reporters_own_area_is_used_when_the_report_has_none(db, org):
    home = _node(db, "Agasteeswaram", GeoLevel.VILLAGE, LocalBodyType.VILLAGE_PANCHAYAT)

    got = juris.resolve(db, reporter_geography_id=home.id)

    assert got.local_body_type is LocalBodyType.VILLAGE_PANCHAYAT
    # Weaker than a declared answer: they may have reported something elsewhere.
    assert got.confidence is juris.Confidence.INHERITED
    assert not got.needs_human_check


def test_a_cycle_in_the_tree_does_not_hang(db, org):
    """Defensive. A self-referential tree with a bad parent link would otherwise
    walk forever inside a request."""
    a = _node(db, "A", GeoLevel.VILLAGE)
    b = _node(db, "B", GeoLevel.STREET, parent=a)
    a.parent_id = b.id
    db.commit()

    got = juris.resolve(db, geography_id=b.id)

    assert got.confidence is juris.Confidence.GUESSED


# ── The ladder ───────────────────────────────────────────────────────────────

def _at(db, org_id, local_body_type):
    return juris.Jurisdiction(
        local_body_type=local_body_type,
        confidence=juris.Confidence.DECLARED,
    )


def test_the_same_pothole_routes_differently_in_town_and_village(db, seeded):
    """The defect that motivated all of this."""
    town = build_ladder(db, seeded.id, "ROAD", _at(db, seeded.id, LocalBodyType.CORPORATION))
    village = build_ladder(db, seeded.id, "ROAD", _at(db, seeded.id, LocalBodyType.VILLAGE_PANCHAYAT))

    assert town.scope == JurisdictionScope.URBAN.value
    assert village.scope == JurisdictionScope.RURAL.value

    town_depts = [r.department.code for r in town.rungs]
    village_depts = [r.department.code for r in village.rungs]

    assert "ULB_ENGINEERING" in town_depts
    assert "PANCHAYAT_UNION" in village_depts
    assert "PANCHAYAT_UNION" not in town_depts
    assert "ULB_ENGINEERING" not in village_depts


def test_a_ladder_climbs_and_ends_somewhere_final(db, seeded):
    ladder = build_ladder(db, seeded.id, "ROAD", _at(db, seeded.id, LocalBodyType.CORPORATION))

    assert [r.position for r in ladder.rungs] == list(range(1, len(ladder.rungs) + 1))
    # It genuinely climbs: no rung is lower than the one before it.
    heights = [r.rung for r in ladder.rungs]
    assert heights == sorted(heights), heights
    # Local first, state last — nobody's first letter goes to the Secretariat.
    assert ladder.rungs[0].department.code == "WARD_OFFICE"
    assert ladder.rungs[-1].department.code == "CM_HELPLINE"


def test_departments_with_their_own_chain_are_defined_once(db, seeded):
    """Electricity and police run the same offices in a city and a village.
    Writing those ladders twice would be two chances to let them drift."""
    urban = build_ladder(db, seeded.id, "ELECTRICITY", _at(db, seeded.id, LocalBodyType.CORPORATION))
    rural = build_ladder(db, seeded.id, "ELECTRICITY", _at(db, seeded.id, LocalBodyType.VILLAGE_PANCHAYAT))

    assert urban.scope == JurisdictionScope.ANY.value
    assert [r.department.code for r in urban.rungs] == [r.department.code for r in rural.rungs]


def test_a_seeded_directory_can_reach_nobody_yet(db, seeded):
    """The seed writes no contact details at all, on purpose.

    A fabricated address for a real official is worse than an empty one: the
    letter goes nowhere and the log says it was delivered.
    """
    ladder = build_ladder(db, seeded.id, "GARBAGE", _at(db, seeded.id, LocalBodyType.CORPORATION))

    assert ladder.first_reachable is None
    assert len(ladder.unreachable) == len(ladder.rungs)
    # And the citizen still gets somewhere to go.
    assert ladder.fallback is not None
    assert ladder.fallback.portal_url or ladder.fallback.helpline


def test_one_filled_in_office_makes_the_ladder_usable(db, seeded):
    """A club that has entered the Commissioner's address but not the ward
    councillor's can still file. Starting a rung too high beats not filing."""
    dept = db.query(Department).filter(
        Department.organization_id == seeded.id, Department.code == "ULB_HEALTH"
    ).one()
    officer = db.query(Authority).filter(
        Authority.department_id == dept.id,
        Authority.designation_en == "City Health Officer",
    ).one()
    officer.email = "filled-in-by-the-club@example.invalid"
    db.commit()

    ladder = build_ladder(db, seeded.id, "GARBAGE", _at(db, seeded.id, LocalBodyType.CORPORATION))
    first = ladder.first_reachable

    assert first is not None
    assert first.department.code == "ULB_HEALTH"
    # It skipped the earlier rungs rather than stopping at them.
    assert first.position > 1
    assert ladder.fallback is None


def test_the_office_matching_this_kind_of_local_body_wins(db, seeded):
    """A Corporation Commissioner and a Town Panchayat Executive Officer sit at
    the same height and are not interchangeable."""
    dept = db.query(Department).filter(
        Department.organization_id == seeded.id, Department.code == "ULB_ENGINEERING"
    ).one()
    for a in db.query(Authority).filter(Authority.department_id == dept.id):
        a.email = f"{a.designation_en.replace(' ', '-').lower()}@example.invalid"
    db.commit()

    town = build_ladder(db, seeded.id, "ROAD", _at(db, seeded.id, LocalBodyType.TOWN_PANCHAYAT))
    heads = [r for r in town.rungs if r.department.code == "ULB_ENGINEERING" and r.position == 3]

    assert heads and heads[0].authority.designation_en == "Executive Officer"


def test_every_category_a_person_can_pick_has_a_route(db, seeded):
    """Nine categories used to exist and most resolved to a helpline. A citizen
    should never choose something the system cannot route."""
    for category in CivicCategory:
        for body in (LocalBodyType.CORPORATION, LocalBodyType.VILLAGE_PANCHAYAT):
            ladder = build_ladder(db, seeded.id, category.value, _at(db, seeded.id, body))
            assert ladder.rungs, f"{category.value} has no route in a {body.value}"
            assert ladder.rungs[-1].department.code in {"CM_HELPLINE", "CPGRAMS"}, (
                f"{category.value} can run out of places to go"
            )


def test_issues_filed_under_the_old_category_names_still_route(db, seeded):
    """Rows written before this redesign must not become unroutable."""
    for old, new in [("ROAD_TRAFFIC", "ROAD"), ("POWER_CUT", "ELECTRICITY"),
                     ("WATER", "DRINKING_WATER"), ("SANITATION", "GARBAGE")]:
        assert normalise_category(old).value == new
        ladder = build_ladder(db, seeded.id, old, _at(db, seeded.id, LocalBodyType.CORPORATION))
        assert ladder.rungs, f"legacy category {old} lost its route"
        assert ladder.category == new


def test_an_unknown_category_is_routed_rather_than_dropped(db, seeded):
    ladder = build_ladder(db, seeded.id, "SOMETHING_NOBODY_ANTICIPATED",
                          _at(db, seeded.id, LocalBodyType.CORPORATION))

    assert ladder.category == CivicCategory.OTHER.value
    assert ladder.rungs


# ── The seed itself ──────────────────────────────────────────────────────────

def test_seeding_twice_changes_nothing(db, seeded):
    before = (
        db.query(Department).count(),
        db.query(Authority).count(),
        db.query(RoutingRule).count(),
    )

    again = seed(db, seeded.id)

    assert again == {"departments": 0, "authorities": 0, "rules": 0}
    assert before == (
        db.query(Department).count(),
        db.query(Authority).count(),
        db.query(RoutingRule).count(),
    )


def test_reseeding_never_erases_a_contact_somebody_verified(db, seeded):
    """Re-seeding must not undo an evening of somebody phoning offices."""
    officer = db.query(Authority).filter(
        Authority.organization_id == seeded.id,
        Authority.designation_en == "District Collector",
    ).one()
    officer.email = "checked@example.invalid"
    officer.source_url = "https://kanniyakumari.nic.in/"
    db.commit()

    seed(db, seeded.id)
    db.refresh(officer)

    assert officer.email == "checked@example.invalid"
    assert officer.source_url == "https://kanniyakumari.nic.in/"


def test_the_seed_ships_no_contact_details(db, seeded):
    """The rule, as a test, so it cannot be relaxed by accident later."""
    seeded_offices = db.query(Authority).filter(
        Authority.organization_id == seeded.id
    ).all()

    assert seeded_offices
    for office in seeded_offices:
        assert not office.email, f"{office.designation_en} shipped an email address"
        assert not office.phone, f"{office.designation_en} shipped a phone number"
        assert not office.verified_at
        assert not office.is_verified
