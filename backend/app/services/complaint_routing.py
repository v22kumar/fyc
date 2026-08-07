"""Turn a complaint into an ordered list of offices to try.

This is the piece the old code had no room for. `_resolve_department(category)`
returned one row and the caller emailed it; there was no second name to try, no
notion that an office might be unreachable, and no record of the sequence.

The ladder produced here is the whole route, computed up front:

* every rung, in order, whether or not it can currently receive an email
* which rungs are reachable, so a complaint is never blocked by an office whose
  address nobody has filled in yet
* how long each gets before the club is asked whether to move up

Nothing here sends anything. It answers "who, in what order" and hands that to a
person.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.civic import (
    Authority, Department, JurisdictionScope, RoutingRule, RoutingStep,
    normalise_category,
)
from app.services.jurisdiction import Jurisdiction


@dataclass(frozen=True)
class Rung:
    """One office on the route."""

    position: int
    department: Department
    authority: Optional[Authority]
    wait_days: int
    #: How high this office sits (see civic.Rung). Comparable across
    #: departments, so a route can be checked for actually climbing.
    rung: int

    @property
    def reachable(self) -> bool:
        """Can a letter actually be delivered to this rung today?"""
        return bool(self.authority and self.authority.is_reachable)

    @property
    def label(self) -> str:
        """How this rung reads in a queue or an audit trail."""
        if self.authority:
            return f"{self.authority.designation_en}, {self.department.name_en}"
        return self.department.name_en


@dataclass(frozen=True)
class Ladder:
    """The full route for one complaint, plus how it was chosen."""

    category: str
    scope: str
    jurisdiction: Jurisdiction
    rungs: list[Rung]

    @property
    def first_reachable(self) -> Optional[Rung]:
        """Where this complaint would go if it were sent right now.

        Skipping past unfilled offices is deliberate. A club that has entered
        the Commissioner's address but not the ward councillor's should still be
        able to file — starting one rung too high is a smaller failure than not
        filing at all, and the gap is visible on the admin screen.
        """
        return next((r for r in self.rungs if r.reachable), None)

    @property
    def unreachable(self) -> list[Rung]:
        """Rungs that need a contact before they can ever be used.

        This list is the club's to-do list, and the reason the directory can be
        seeded honestly with no contact details at all.
        """
        return [r for r in self.rungs if not r.reachable]

    @property
    def fallback(self) -> Optional[Department]:
        """A published portal or helpline to show when no rung is reachable.

        The old code returned `needs_manual: true` and recorded the recipient as
        the string "not-configured". A citizen should get a phone number they
        can ring instead.
        """
        if self.first_reachable:
            return None
        for rung in self.rungs:
            if rung.department.portal_url or rung.department.helpline:
                return rung.department
        return None


def _pick_rule(
    db: Session, org_id: UUID, category: str, jurisdiction: Jurisdiction
) -> Optional[RoutingRule]:
    """The most specific active rule for this category.

    Specific beats general: a rule written for RURAL wins over one written for
    ANY. That ordering is what lets electricity and police be defined once while
    roads and drains differ by where you are standing.
    """
    wanted = (
        JurisdictionScope.URBAN.value
        if jurisdiction.is_urban
        else JurisdictionScope.RURAL.value
    )
    rules = (
        db.query(RoutingRule)
        .filter(
            RoutingRule.organization_id == org_id,
            RoutingRule.category == category,
            RoutingRule.is_active.is_(True),
        )
        .all()
    )
    by_scope = {r.scope: r for r in rules}
    return by_scope.get(wanted) or by_scope.get(JurisdictionScope.ANY.value)


def _pick_authority(
    candidates: list[Authority], jurisdiction: Jurisdiction
) -> Optional[Authority]:
    """The office that best matches this place, among those at the right rung.

    Preference order, most important first:

    1. It can actually be written to. An office with an address beats a better-
       matching one without, because the alternative is a rung that silently
       does nothing.
    2. It is scoped to this kind of local body. A Corporation Commissioner and a
       Town Panchayat Executive Officer sit at the same height and are not
       interchangeable.
    """
    if not candidates:
        return None

    def rank(a: Authority) -> tuple:
        matches_body = a.local_body_type == jurisdiction.local_body_type.value
        generic = a.local_body_type is None
        return (
            0 if a.is_reachable else 1,
            0 if matches_body else (1 if generic else 2),
        )

    return sorted(candidates, key=rank)[0]


def build_ladder(
    db: Session, org_id: UUID, raw_category: str, jurisdiction: Jurisdiction
) -> Ladder:
    """Compute the whole route for a complaint.

    Returns an empty ladder rather than raising when no rule exists — a missing
    rule is a directory gap for an admin to fix, not an error to show a citizen
    who has just photographed a broken drain.
    """
    category = normalise_category(raw_category).value
    rule = _pick_rule(db, org_id, category, jurisdiction)
    if rule is None:
        return Ladder(category=category, scope="", jurisdiction=jurisdiction, rungs=[])

    steps: list[RoutingStep] = sorted(rule.steps, key=lambda s: s.position)
    codes = {s.department_code for s in steps}
    departments = {
        d.code: d
        for d in db.query(Department).filter(
            Department.organization_id == org_id, Department.code.in_(codes)
        )
    }
    dept_ids = [d.id for d in departments.values()]
    authorities: list[Authority] = (
        db.query(Authority)
        .filter(
            Authority.organization_id == org_id,
            Authority.department_id.in_(dept_ids),
            Authority.is_active.is_(True),
        )
        .all()
        if dept_ids
        else []
    )

    rungs: list[Rung] = []
    for step in steps:
        dept = departments.get(step.department_code)
        if dept is None:
            # A rule naming a department that no longer exists. Skip it rather
            # than break the route; the admin screen can report the dangling
            # reference separately.
            continue
        at_rung = [
            a for a in authorities
            if a.department_id == dept.id and a.rung == step.rung
        ]
        rungs.append(Rung(
            position=step.position,
            department=dept,
            authority=_pick_authority(at_rung, jurisdiction),
            wait_days=step.wait_days,
            rung=step.rung,
        ))

    return Ladder(
        category=category,
        scope=rule.scope,
        jurisdiction=jurisdiction,
        rungs=rungs,
    )
