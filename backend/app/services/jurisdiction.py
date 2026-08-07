"""Which local body governs the place a complaint came from.

The app already captures GPS on every report. What it never did was ask the
question that decides everything downstream: *is this a city street, a town, or
a village?* Nagercoil is a Municipal Corporation; the same district holds
municipalities, town panchayats and hundreds of village panchayats, and they are
different offices with different officers and different chains of command.

## Why this is a resolver and not a lookup

There are no boundary polygons here. The geographic tree stores names and a
parent link, not shapes, and no official shapefile for Kanniyakumari's local
bodies is bundled with this app. Pretending otherwise — snapping a point to the
nearest node and calling it certain — would produce confident wrong answers,
which in this system means a letter to the wrong office and a citizen told their
complaint was filed.

So resolution is a cascade of decreasingly reliable sources, and it reports how
it got there. The club review gate that every complaint passes through is the
right place for a human to correct a low-confidence guess, and it can only do
that if the guess admits to being one.
"""
from __future__ import annotations

import enum
from dataclasses import dataclass
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.civic import LocalBodyType
from app.models.geography import GeographicNode


class Confidence(str, enum.Enum):
    """How much the answer below should be trusted.

    `DECLARED` means somebody recorded it against this place. `INHERITED` means
    we walked up the tree to a parent that had been classified. `GUESSED` means
    we fell back to the organisation's default and a reviewer should look.
    """

    DECLARED = "DECLARED"
    INHERITED = "INHERITED"
    GUESSED = "GUESSED"


@dataclass(frozen=True)
class Jurisdiction:
    """The answer, with its provenance attached."""

    local_body_type: LocalBodyType
    confidence: Confidence
    #: The node the answer came from, when it came from one.
    geography_id: Optional[UUID] = None
    #: Human-readable trail, for the reviewer screen and for debugging a
    #: complaint that went somewhere strange.
    reason: str = ""

    @property
    def is_urban(self) -> bool:
        return self.local_body_type.is_urban

    @property
    def needs_human_check(self) -> bool:
        """A reviewer should confirm before this decides where a letter goes."""
        return self.confidence is Confidence.GUESSED


#: Where a complaint lands when nothing else is known. Nagercoil is a Municipal
#: Corporation, and it is where this club is — but a guess is still labelled a
#: guess rather than quietly promoted to a fact.
DEFAULT_LOCAL_BODY = LocalBodyType.CORPORATION

#: How far up the tree to walk before giving up. A district is not a local body,
#: so an answer inherited from that height is not worth having.
_MAX_WALK = 6


def _coerce(raw: Optional[str]) -> Optional[LocalBodyType]:
    if not raw:
        return None
    try:
        return LocalBodyType(str(raw).strip().upper())
    except ValueError:
        return None


def resolve_from_node(db: Session, geography_id: Optional[UUID]) -> Optional[Jurisdiction]:
    """Read the local body off a place, or off the nearest ancestor that knows.

    Walking up matters because classification is patchy in practice: somebody
    will record that Nagercoil is a Corporation and never touch the sixty street
    nodes beneath it. Those streets are still governed by a Corporation, and a
    complaint from one of them should route as such.
    """
    if not geography_id:
        return None

    node = db.get(GeographicNode, geography_id)
    if node is None:
        return None

    declared = _coerce(node.local_body_type)
    if declared:
        return Jurisdiction(
            local_body_type=declared,
            confidence=Confidence.DECLARED,
            geography_id=node.id,
            reason=f"{node.name_en} is recorded as a {declared.value.replace('_', ' ').lower()}",
        )

    seen: set = {node.id}
    current, hops = node, 0
    while current.parent_id and hops < _MAX_WALK:
        # Defensive: a cycle in a self-referential tree would otherwise spin.
        if current.parent_id in seen:
            break
        seen.add(current.parent_id)
        parent = db.get(GeographicNode, current.parent_id)
        if parent is None:
            break
        inherited = _coerce(parent.local_body_type)
        if inherited:
            return Jurisdiction(
                local_body_type=inherited,
                confidence=Confidence.INHERITED,
                geography_id=parent.id,
                reason=(
                    f"{node.name_en} is not classified; inherited from "
                    f"{parent.name_en}"
                ),
            )
        current, hops = parent, hops + 1

    return None


def resolve(
    db: Session,
    *,
    geography_id: Optional[UUID] = None,
    reporter_geography_id: Optional[UUID] = None,
    default: LocalBodyType = DEFAULT_LOCAL_BODY,
) -> Jurisdiction:
    """Decide the jurisdiction for a report, best source first.

    1. The place the issue was tagged with.
    2. The place the person who reported it belongs to. Weaker — somebody can
       report a pothole outside their own ward — but far better than nothing,
       and it is right the great majority of the time.
    3. The organisation's default, labelled a guess so a reviewer looks.

    Coordinates are deliberately absent from this signature. The app has them,
    but turning a latitude into a local body needs boundary data this project
    does not have; when that data exists it becomes step 1 and everything below
    stays exactly as it is.
    """
    answer = resolve_from_node(db, geography_id)
    if answer:
        return answer

    answer = resolve_from_node(db, reporter_geography_id)
    if answer:
        return Jurisdiction(
            local_body_type=answer.local_body_type,
            # One step weaker than however we learned it: this is the reporter's
            # own area, not necessarily the pothole's.
            confidence=Confidence.INHERITED,
            geography_id=answer.geography_id,
            reason=f"taken from the reporter's own area — {answer.reason}",
        )

    return Jurisdiction(
        local_body_type=default,
        confidence=Confidence.GUESSED,
        geography_id=None,
        reason=(
            "no area recorded on the report or the reporter; "
            f"assumed {default.value.replace('_', ' ').lower()}"
        ),
    )
