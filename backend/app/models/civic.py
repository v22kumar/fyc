"""Who a civic complaint belongs to, and who it goes to next.

The old model could not express the problem. `ComplaintDepartment` held one row
per category for the whole tenant, so a pothole resolved to the same office
whether it was on a national highway, a corporation street or a village road —
and `POST /issues/{id}/forward` sent one email to that one address, once. The
`ESCALATED` status existed and nothing ever set it.

Two facts decide where a complaint goes, and the old design captured neither:

* **What kind of problem it is.** Roads alone split four ways — NHAI for a
  national highway, State Highways for a state road, the local body for a town
  street, the Panchayat Union for a village road.
* **Where it happened.** Tamil Nadu has four kinds of local body, and they are
  genuinely different offices with different officers. Nagercoil is a
  Corporation; the district also holds municipalities, town panchayats and
  village panchayats.

So the routing key is `(category, jurisdiction)`, and the answer is not one
address but an **ordered ladder** — ward, then section officer, then the head of
the local body, then the district, then the state. Each rung gets its turn and
its own clock. Nothing reaches a District Collector because a timer expired: the
club is asked first, every time.
"""
import enum
import uuid

from sqlalchemy import (
    Boolean, Column, DateTime, ForeignKey, Integer, String, Text,
    UniqueConstraint, Index,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class LocalBodyType(str, enum.Enum):
    """The four kinds of local body in Tamil Nadu.

    Not decoration: a Corporation has a Commissioner and zonal offices, a
    village panchayat has a President and reports to a Block Development
    Officer. A complaint that goes to the wrong one is a complaint that dies.
    """

    CORPORATION = "CORPORATION"
    MUNICIPALITY = "MUNICIPALITY"
    TOWN_PANCHAYAT = "TOWN_PANCHAYAT"
    VILLAGE_PANCHAYAT = "VILLAGE_PANCHAYAT"

    @property
    def is_urban(self) -> bool:
        """Urban local bodies share a ladder shape; rural has its own.

        The three urban types differ in size, not in structure — each has an
        engineering wing, a health wing and an executive head, and each sits
        under the district administration. The village panchayat route runs
        through the Panchayat Union instead, which is a different chain.
        """
        return self is not LocalBodyType.VILLAGE_PANCHAYAT


class JurisdictionScope(str, enum.Enum):
    """Which local bodies a routing rule applies to.

    `ANY` exists because several ladders ignore the local body entirely.
    Electricity runs through TANGEDCO's own section offices, land through the
    Revenue department, crime through the police — the same chain in a city and
    in a village. Writing those rules four times would be four chances to let
    them drift apart.
    """

    URBAN = "URBAN"
    RURAL = "RURAL"
    ANY = "ANY"


class GovTier(str, enum.Enum):
    """Who ultimately answers for a department — and therefore which grievance
    system of last resort applies: the state's CM Helpline, or CPGRAMS."""

    LOCAL_BODY = "LOCAL_BODY"
    STATE = "STATE"
    CENTRAL = "CENTRAL"


class Rung(int, enum.Enum):
    """How far up a ladder an office sits.

    An integer rather than a designation, because the designations differ per
    department while the *height* is comparable: a Corporation Commissioner and
    a Block Development Officer are both "the head of the local body", and both
    should be tried before the district is troubled.

    Stored as a plain Integer column so a department with an unusual chain can
    use an in-between value without a migration.
    """

    WARD = 10          # ward councillor, village panchayat president
    SECTION = 20       # assistant engineer, sanitary inspector, VAO, section office
    LOCAL_HEAD = 30    # commissioner, executive officer, BDO, tahsildar
    SUBDIVISION = 40   # RDO, assistant executive engineer, DSP
    DISTRICT = 50      # collector, superintending engineer, SP, CEO, DDHS
    STATE = 60         # directorate, commissionerate, CM helpline
    CENTRAL = 70       # CPGRAMS, NHAI headquarters


class CivicCategory(str, enum.Enum):
    """What a person can point at.

    Thirteen recognisable things plus OTHER, against the nine the app had — and
    the nine were shaped around which office the code already knew, which is
    backwards. `DRAINAGE` is not `GARBAGE`, and a school complaint had nowhere
    to go at all.

    The `category` column on an issue stays a plain String, so rows written
    under the old names remain readable. `LEGACY_CATEGORIES` maps them forward.
    """

    ROAD = "ROAD"
    STREET_LIGHT = "STREET_LIGHT"
    DRINKING_WATER = "DRINKING_WATER"
    DRAINAGE = "DRAINAGE"
    GARBAGE = "GARBAGE"
    ELECTRICITY = "ELECTRICITY"
    PUBLIC_HEALTH = "PUBLIC_HEALTH"      # stray animals, mosquitoes, hazards
    ENCROACHMENT = "ENCROACHMENT"        # land, illegal construction
    SCHOOL = "SCHOOL"
    HEALTHCARE = "HEALTHCARE"            # PHC, government hospital
    POLLUTION = "POLLUTION"
    TRANSPORT = "TRANSPORT"              # buses, bus stands
    SAFETY = "SAFETY"                    # police, law and order
    OTHER = "OTHER"


#: Old category names → their replacement. Kept so historical issues still route
#: and still display, and so the mobile app can be updated on its own schedule
#: rather than in lockstep with a backend deploy.
LEGACY_CATEGORIES = {
    "ROAD_TRAFFIC": CivicCategory.ROAD,
    "POWER_CUT": CivicCategory.ELECTRICITY,
    "WATER": CivicCategory.DRINKING_WATER,
    "SANITATION": CivicCategory.GARBAGE,
}


def normalise_category(raw: str) -> CivicCategory:
    """Accept any category this app has ever written and return a current one."""
    if not raw:
        return CivicCategory.OTHER
    key = str(raw).strip().upper()
    if key in LEGACY_CATEGORIES:
        return LEGACY_CATEGORIES[key]
    try:
        return CivicCategory(key)
    except ValueError:
        return CivicCategory.OTHER


class Department(Base, TimestampMixin, TenantModelMixin):
    """A government body — not a person, and not an office.

    Deliberately free of contact details. Officers transfer, offices move, and a
    department outlives both. What belongs here is what stays true for years:
    the name, who it answers to, its published grievance portal and helpline.
    """

    __tablename__ = "civic_departments"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    #: Stable identifier used by the seed and by routing rules, e.g. "TANGEDCO".
    #: Rules reference departments by code so a re-seed cannot orphan them.
    code = Column(String(40), nullable=False)
    name_en = Column(String(160), nullable=False)
    name_ta = Column(String(160), nullable=True)
    tier = Column(String(20), nullable=False, default=GovTier.LOCAL_BODY.value)
    #: The department's own published grievance channel. A fact that can be
    #: cited, unlike an officer's email address.
    portal_url = Column(String(300), nullable=True)
    helpline = Column(String(40), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    authorities = relationship(
        "Authority", back_populates="department", cascade="all, delete-orphan"
    )

    __table_args__ = (
        UniqueConstraint("organization_id", "code", name="uq_dept_org_code"),
    )


class Authority(Base, TimestampMixin, TenantModelMixin):
    """One office, at one rung, for one area — where a letter is actually sent.

    An office, never a person: `designation_en` is "Commissioner", not a name.
    The person changes; the desk does not.

    ## Contacts are evidence, not guesses

    `email` is nullable and starts empty on purpose. A fabricated address for a
    real public official is worse than no address: the complaint disappears and
    the club believes it was delivered. Nothing here is filled in by a seed
    script — the club enters each one and records where it came from.

    `source_url` and `verified_at` are what make this a directory rather than a
    rumour. An entry nobody has checked in a year is flagged rather than quietly
    used, because a stale address is a complaint that vanishes silently.
    """

    __tablename__ = "civic_authorities"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    department_id = Column(
        GUID(), ForeignKey("civic_departments.id", ondelete="CASCADE"), nullable=False
    )
    #: Which area this office covers. Null means it covers the whole tenant —
    #: correct for a district- or state-level office.
    geography_id = Column(
        GUID(), ForeignKey("geographic_nodes.id", ondelete="SET NULL"), nullable=True
    )
    #: Narrows an office to one kind of local body where that matters (a
    #: Corporation Commissioner is not a Town Panchayat Executive Officer).
    local_body_type = Column(String(30), nullable=True)
    rung = Column(Integer, nullable=False, default=Rung.LOCAL_HEAD.value, index=True)

    designation_en = Column(String(160), nullable=False)
    designation_ta = Column(String(160), nullable=True)
    office_name_en = Column(String(200), nullable=True)
    office_name_ta = Column(String(200), nullable=True)

    email = Column(String(255), nullable=True)
    cc_emails = Column(String(500), nullable=True)
    phone = Column(String(60), nullable=True)
    address_en = Column(Text, nullable=True)
    address_ta = Column(Text, nullable=True)

    #: Where this contact was found. Required before the entry counts as
    #: verified — see `is_verified`.
    source_url = Column(String(400), nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    verified_by_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    is_active = Column(Boolean, nullable=False, default=True)

    department = relationship("Department", back_populates="authorities")

    __table_args__ = (
        Index("ix_authority_dept_rung", "organization_id", "department_id", "rung"),
    )

    @property
    def is_reachable(self) -> bool:
        """Can a complaint actually be delivered here?

        A rung with no email is not a blocked complaint — the ladder walks past
        it to the next rung that can receive one. This property is what lets it
        do that without pretending the office does not exist.
        """
        return bool(self.is_active and (self.email or "").strip())

    @property
    def is_verified(self) -> bool:
        """A contact somebody checked, against a source, on a date."""
        return bool(self.verified_at and (self.source_url or "").strip())


class RoutingRule(Base, TimestampMixin, TenantModelMixin):
    """The ladder for one kind of problem in one kind of place.

    A row of data, not a branch in Python, so a club can correct a route the
    morning they discover it is wrong instead of waiting for a deploy — which is
    exactly the situation the hardcoded nine-row department list created.
    """

    __tablename__ = "civic_routing_rules"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    category = Column(String(40), nullable=False, index=True)
    #: URBAN, RURAL, or ANY. Resolution prefers the specific rule and falls back
    #: to ANY, so a route that genuinely does not care about the local body is
    #: written once.
    scope = Column(String(10), nullable=False, default=JurisdictionScope.ANY.value)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    steps = relationship(
        "RoutingStep",
        back_populates="rule",
        cascade="all, delete-orphan",
        order_by="RoutingStep.position",
    )

    __table_args__ = (
        UniqueConstraint(
            "organization_id", "category", "scope", name="uq_rule_org_cat_scope"
        ),
    )


class RoutingStep(Base, TimestampMixin, TenantModelMixin):
    """One rung of one ladder: who to try, and how long to wait for them.

    The order lives here rather than on `Authority` because the same office
    appears at different heights in different ladders. A District Collector is
    the last local resort for a drainage complaint and an early one for a land
    dispute; the office has not changed, its position in that particular queue
    has.
    """

    __tablename__ = "civic_routing_steps"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    rule_id = Column(
        GUID(), ForeignKey("civic_routing_rules.id", ondelete="CASCADE"), nullable=False
    )
    position = Column(Integer, nullable=False)
    department_code = Column(String(40), nullable=False)
    rung = Column(Integer, nullable=False)
    #: How long this office gets before the club is asked whether to move up.
    #: Never how long before the app moves up by itself.
    wait_days = Column(Integer, nullable=False, default=7)

    rule = relationship("RoutingRule", back_populates="steps")

    __table_args__ = (
        UniqueConstraint("rule_id", "position", name="uq_step_rule_position"),
    )


class EscalationOutcome(str, enum.Enum):
    """What happened at a rung. `NO_REPLY` is the common one, and the reason the
    ladder exists at all."""

    PENDING = "PENDING"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"
    NO_REPLY = "NO_REPLY"
    UNDELIVERABLE = "UNDELIVERABLE"


class IssueEscalation(Base, TimestampMixin, TenantModelMixin):
    """One rung actually tried, for one issue — the complaint's history.

    Written every time a letter goes out, never overwritten. Six weeks later the
    question "who did we tell, and when, and what did they say" has an answer,
    and a citizen asking the club can be given a straight one.

    `due_at` is when the club is *asked* whether to move up. It is not a trigger:
    no email leaves this system without a person pressing send.
    """

    __tablename__ = "civic_issue_escalations"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    issue_id = Column(
        GUID(), ForeignKey("public_issues.id", ondelete="CASCADE"), nullable=False, index=True
    )
    #: Which rung of the ladder this was — matches RoutingStep.position.
    position = Column(Integer, nullable=False)
    authority_id = Column(
        GUID(), ForeignKey("civic_authorities.id", ondelete="SET NULL"), nullable=True
    )
    #: Kept as text as well as a foreign key, so the record still reads correctly
    #: after an office is renamed or an authority row is removed.
    sent_to_label = Column(String(240), nullable=True)
    sent_to_email = Column(String(255), nullable=True)

    dispatched_at = Column(DateTime(timezone=True), nullable=True)
    due_at = Column(DateTime(timezone=True), nullable=True)
    outcome = Column(String(20), nullable=False, default=EscalationOutcome.PENDING.value)
    response_note = Column(Text, nullable=True)
    #: Who pressed send. Every letter has a person behind it.
    dispatched_by_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        UniqueConstraint("issue_id", "position", name="uq_escalation_issue_position"),
    )


class ContactSuggestionStatus(str, enum.Enum):
    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"


class ContactSuggestion(Base, TimestampMixin, TenantModelMixin):
    """A number or address a member says belongs to an office.

    The directory has forty desks and a contact for barely half of them, and
    the missing ones are the local desks that matter most — the ward
    councillor, the panchayat president, the section office — precisely
    because they are the ones no district web page lists. The people who have
    those numbers are the members standing in front of those offices.

    It does not go straight into the directory. A wrong number here does not
    inconvenience one person; it sends every future complaint about that street
    to a stranger, under the club's name, and nobody finds out for weeks. So a
    suggestion waits for an organiser, and carries where the member got it.
    """

    __tablename__ = "civic_contact_suggestions"
    __table_args__ = (
        Index("ix_contact_suggestions_status", "organization_id", "status"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    authority_id = Column(
        GUID(), ForeignKey("civic_authorities.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    suggested_by_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    phone = Column(String(60), nullable=True)
    email = Column(String(255), nullable=True)

    #: Where they got it — "on the board outside the office", "he gave me his
    #: card". Not a URL, because the people who have these numbers did not read
    #: them on a website, and demanding one would exclude exactly the
    #: contributions worth having.
    how_they_know = Column(Text, nullable=True)

    status = Column(String(12), nullable=False,
                    default=ContactSuggestionStatus.PENDING.value)
    reviewed_by_user_id = Column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    #: Why it was turned down, so the member is told something better than no.
    review_note = Column(Text, nullable=True)
