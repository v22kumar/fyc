"""The department directory the club maintains by hand.

The seed ships every office and not one contact detail, on purpose — a
fabricated address for a real public official is worse than an empty one,
because the letter goes nowhere and the log says it was delivered. So somebody
has to ring offices and write down what they find, and this is what they use.

The interesting endpoint is `/civic/directory/health`. Filling in forty offices
in no particular order is a chore nobody finishes; filling in the four that
unblock twelve ladders is an afternoon. It answers "what should I do next" with
a number rather than a list.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker, get_current_user
from app.models.civic import (
    Authority, CivicCategory, ContactSuggestion, ContactSuggestionStatus,
    Department, LocalBodyType, RoutingRule, RoutingStep,
)
from app.models.issue import PublicIssue
from app.models.user import User, UserProfile
from app.schemas.civic import (
    AuthorityOut, AuthorityPatch, DepartmentOut, DirectoryHealthOut, GapOut,
    LadderHealthOut, CallLadderOut, LadderRungOut,
)
from app.services.complaint_routing import build_ladder
from app.services.jurisdiction import is_covered
from app.services.jurisdiction import resolve as resolve_jurisdiction
from app.services.jurisdiction import Confidence, Jurisdiction

router = APIRouter(prefix="/civic", tags=["Civic Directory"])

require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_staff = RoleChecker(["VOLUNTEER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

#: How long a checked contact stays trustworthy. Officers transfer; a year-old
#: address is worth re-checking before a complaint is sent to it.
STALE_AFTER = timedelta(days=365)

#: The places a ladder is measured against. Municipality and Town Panchayat
#: share the urban ladder with Corporation, so checking those two answers for
#: all four.
_SAMPLE_PLACES = (LocalBodyType.CORPORATION, LocalBodyType.VILLAGE_PANCHAYAT)


def _is_stale(authority: Authority) -> bool:
    if not authority.verified_at:
        return False
    checked = authority.verified_at
    if checked.tzinfo is None:
        checked = checked.replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc) - checked > STALE_AFTER


def _authority_out(a: Authority) -> AuthorityOut:
    return AuthorityOut(
        id=a.id,
        department_id=a.department_id,
        department_code=a.department.code,
        department_name_en=a.department.name_en,
        rung=a.rung,
        designation_en=a.designation_en,
        designation_ta=a.designation_ta,
        local_body_type=a.local_body_type,
        office_name_en=a.office_name_en,
        email=a.email,
        phone=a.phone,
        address_en=a.address_en,
        source_url=a.source_url,
        verified_at=a.verified_at,
        is_reachable=a.is_reachable,
        is_verified=a.is_verified,
        is_stale=_is_stale(a),
    )


@router.get("/departments", response_model=list[DepartmentOut])
def list_departments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Every government body this club can write to."""
    return (
        db.query(Department)
        .filter(
            Department.organization_id == current_user.organization_id,
            Department.is_active.is_(True),
        )
        .order_by(Department.tier.asc(), Department.name_en.asc())
        .all()
    )


@router.get("/authorities", response_model=list[AuthorityOut])
def list_authorities(
    department_code: Optional[str] = Query(default=None),
    missing_contact: Optional[bool] = Query(
        default=None, description="true to list only offices with nowhere to write"
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The offices, and which of them can currently be reached."""
    q = (
        db.query(Authority)
        .filter(
            Authority.organization_id == current_user.organization_id,
            Authority.is_active.is_(True),
        )
        .order_by(Authority.rung.asc())
    )
    rows = q.all()
    if department_code:
        rows = [a for a in rows if a.department.code == department_code]
    if missing_contact is True:
        rows = [a for a in rows if not a.is_reachable]
    elif missing_contact is False:
        rows = [a for a in rows if a.is_reachable]
    return [_authority_out(a) for a in rows]


@router.patch(
    "/authorities/{authority_id}",
    response_model=AuthorityOut,
    dependencies=[Depends(require_executive)],
)
def update_authority(
    authority_id: UUID,
    payload: AuthorityPatch,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Record a contact, with where it came from.

    A contact without a source is refused. That is not bureaucracy: this
    directory decides where complaints about real people's streets get sent, and
    an entry nobody can trace is an entry nobody can check when it stops
    working. Setting a contact stamps who recorded it and when, which is what
    makes the staleness warning possible a year later.
    """
    authority = (
        db.query(Authority)
        .filter(
            Authority.id == authority_id,
            Authority.organization_id == current_user.organization_id,
        )
        .first()
    )
    if not authority:
        raise HTTPException(status_code=404, detail="Office not found")

    fields = payload.model_dump(exclude_unset=True)
    setting_contact = any(
        fields.get(k) for k in ("email", "phone", "cc_emails")
    )
    source = (fields.get("source_url") or authority.source_url or "").strip()
    if setting_contact and not source:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "A contact needs a source_url — the official page it came from. "
                "An address nobody can trace is one nobody can check when it "
                "stops working."
            ),
        )

    for key, value in fields.items():
        setattr(authority, key, value)

    if setting_contact or fields.get("source_url"):
        authority.verified_at = datetime.now(timezone.utc)
        authority.verified_by_user_id = current_user.id

    db.commit()
    db.refresh(authority)
    return _authority_out(authority)


@router.get(
    "/directory/health",
    response_model=DirectoryHealthOut,
    dependencies=[Depends(require_staff)],
)
def directory_health(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """What still needs doing, ordered by what it buys.

    Every category is walked against an urban and a rural place, and each
    resulting ladder is asked one question: can a complaint filed here reach
    anybody at all? The offices are then ranked by how many blocked ladders each
    one would open.
    """
    org_id = current_user.organization_id

    offices = (
        db.query(Authority)
        .filter(Authority.organization_id == org_id, Authority.is_active.is_(True))
        .all()
    )

    ladders: list[LadderHealthOut] = []
    #: authority_id -> [is the ladder it appears on currently blocked]
    appearances: dict[UUID, list[bool]] = {}

    for category in CivicCategory:
        for place in _SAMPLE_PLACES:
            here = Jurisdiction(
                local_body_type=place, confidence=Confidence.DECLARED
            )
            ladder = build_ladder(db, org_id, category.value, here)
            if not ladder.rungs:
                continue
            first = ladder.first_reachable
            blocked = first is None
            ladders.append(LadderHealthOut(
                category=category.value,
                local_body_type=place.value,
                total_rungs=len(ladder.rungs),
                reachable_rungs=sum(1 for r in ladder.rungs if r.reachable),
                first_reachable=first.label if first else None,
                blocked=blocked,
            ))
            for rung in ladder.rungs:
                if rung.authority is not None:
                    appearances.setdefault(rung.authority.id, []).append(blocked)

    by_id = {a.id: a for a in offices}
    gaps: list[GapOut] = []
    for authority_id, blocked_flags in appearances.items():
        authority = by_id.get(authority_id)
        if authority is None or authority.is_reachable:
            continue
        gaps.append(GapOut(
            authority_id=authority.id,
            department_code=authority.department.code,
            designation_en=authority.designation_en,
            designation_ta=authority.designation_ta,
            rung=authority.rung,
            local_body_type=authority.local_body_type,
            appears_on_ladders=len(blocked_flags),
            would_unblock=sum(1 for b in blocked_flags if b),
        ))
    # Most unblocking first; a tie goes to the office that appears more often,
    # then to the lowest rung — start at the bottom of the ladder, where a
    # complaint should start too.
    gaps.sort(key=lambda g: (-g.would_unblock, -g.appears_on_ladders, g.rung))

    return DirectoryHealthOut(
        offices_total=len(offices),
        offices_reachable=sum(1 for a in offices if a.is_reachable),
        offices_verified=sum(1 for a in offices if a.is_verified),
        offices_stale=sum(1 for a in offices if _is_stale(a)),
        ladders_total=len(ladders),
        ladders_blocked=sum(1 for l in ladders if l.blocked),
        top_gaps=gaps[:10],
        ladders=ladders,
    )


# ── The ladder a member sees before they do anything ─────────────────────────

#: How each rung reads to someone deciding who to ring. The directory knows the
#: office; this is what it *covers*, which is the part that makes the choice
#: informed rather than a guess.
_COVERS = {
    10: ("your ward", "உங்கள் வார்டு"),
    20: ("your area", "உங்கள் பகுதி"),
    30: ("the local body", "உள்ளாட்சி"),
    40: ("the division", "கோட்டம்"),
    50: ("the district", "மாவட்டம்"),
    60: ("the state", "மாநிலம்"),
    70: ("national", "தேசிய"),
}


@router.get("/ladder", response_model=CallLadderOut)
def call_ladder(
    category: str = Query(description="what the complaint is about"),
    geography_id: Optional[UUID] = Query(default=None),
    complaint_id: Optional[UUID] = Query(
        default=None,
        description="the complaint this ladder is for, so it is built from "
                    "where the thing actually is",
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Every office worth trying for this complaint, nearest first.

    The whole list, on purpose. Handing a member one "correct" officer is worse
    than handing them nothing: when that officer does not pick up, or listens
    and does nothing, there is no visible next step and they stop. Seeing the
    ladder from the first screen means the next step is always obvious — and
    they can judge for themselves who is worth ringing, because they know
    things about the local office that this directory never will.

    Unreachable rungs are returned too, marked. Hiding an office we have no
    number for would hide the gap; showing it greyed is how it gets filled.
    """
    org_id = current_user.organization_id

    # Where the thing actually is, when we were told which complaint this is
    # about. Without it the ladder was built from the *reporter's* home area,
    # which is the one piece of context that is wrong precisely when it matters
    # — somebody reporting a problem while away from home.
    issue = None
    if complaint_id is not None:
        issue = db.get(PublicIssue, complaint_id)
        if issue is not None and (
            issue.organization_id != org_id
            or (issue.reported_by_user_id != current_user.id
                and not getattr(current_user, "is_admin", False))
        ):
            issue = None

    # Is this even our district? Asked before anything is built, because the
    # answer "here are four officers in Nagercoil" is worse than no answer at
    # all for a pothole in Bengaluru: it is confidently wrong, it wastes the
    # member's afternoon, and it teaches an office that this club sends noise.
    if issue is not None and not is_covered(issue.latitude, issue.longitude):
        return CallLadderOut(
            category=category,
            rungs=[],
            covered=False,
            outside_place=issue.location_name,
        )

    # The reporter's own place is the fallback when the report has no tag —
    # someone can report a pothole outside their ward, but it is right far more
    # often than a district-wide guess.
    jurisdiction = resolve_jurisdiction(
        db,
        geography_id=(geography_id
                      or (issue.geography_id if issue is not None else None)),
        reporter_geography_id=getattr(current_user, "geography_id", None),
    )
    ladder = build_ladder(db, org_id, category, jurisdiction)

    rungs = []
    for r in ladder.rungs:
        covers_en, covers_ta = _COVERS.get(r.rung, ("", None))
        a = r.authority
        rungs.append(
            LadderRungOut(
                position=r.position,
                authority_id=(a.id if a else None),
                department_code=r.department.code,
                department_name_en=r.department.name_en,
                department_name_ta=r.department.name_ta,
                designation_en=a.designation_en if a else None,
                designation_ta=a.designation_ta if a else None,
                covers_en=covers_en,
                covers_ta=covers_ta,
                phone=(a.phone if a else None) or None,
                email=(a.email if a else None) or None,
                can_call=bool((a.phone or "").strip()) if a else False,
                can_write=r.reachable,
                wait_days=r.wait_days,
            )
        )

    fallback = ladder.fallback
    return CallLadderOut(
        category=ladder.category,
        local_body_type=getattr(jurisdiction.local_body_type, "value", None),
        place_name=jurisdiction.place_name,
        rungs=rungs,
        fallback_helpline=fallback.helpline if fallback else None,
        fallback_portal_url=fallback.portal_url if fallback else None,
    )


# ── Members filling the gaps in the directory ────────────────────────────────

class ContactSuggestionIn(BaseModel):
    phone: Optional[str] = Field(default=None, max_length=60)
    email: Optional[str] = Field(default=None, max_length=255)
    #: Where they got it, in their own words. Deliberately not a URL — the
    #: people who have a ward councillor's number read it off a board outside
    #: his office, not a website, and demanding a link would exclude exactly
    #: the contributions worth having.
    how_they_know: Optional[str] = Field(default=None, max_length=500)


class ContactSuggestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    authority_id: UUID
    designation: Optional[str] = None
    department: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    how_they_know: Optional[str] = None
    status: str
    suggested_by: Optional[str] = None
    created_at: datetime


@router.post("/authorities/{authority_id}/suggest-contact",
             response_model=ContactSuggestionOut, status_code=201)
def suggest_contact(
    authority_id: UUID,
    payload: ContactSuggestionIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """A member offers a contact for an office that has none.

    The directory's blanks are the local desks — ward councillor, panchayat
    president, section office — and they are blank precisely because no
    district web page lists them. The people who have those numbers are the
    members standing in front of those offices.

    It waits for an organiser. A wrong number does not inconvenience one
    person: it sends every future complaint about that street to a stranger,
    under the club's name, and nobody finds out for weeks.
    """
    if not ((payload.phone or "").strip() or (payload.email or "").strip()):
        raise HTTPException(status_code=422,
                            detail="Give a phone number or an email address")

    authority = db.get(Authority, authority_id)
    if authority is None or authority.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Unknown office")

    suggestion = ContactSuggestion(
        organization_id=current_user.organization_id,
        authority_id=authority_id,
        suggested_by_user_id=current_user.id,
        phone=(payload.phone or "").strip() or None,
        email=(payload.email or "").strip() or None,
        how_they_know=(payload.how_they_know or "").strip() or None,
        status=ContactSuggestionStatus.PENDING.value,
    )
    db.add(suggestion)
    db.commit()
    db.refresh(suggestion)
    return _suggestion_out(db, suggestion)


def _suggestion_out(db: Session, s: ContactSuggestion) -> ContactSuggestionOut:
    a = db.get(Authority, s.authority_id)
    name = None
    if s.suggested_by_user_id:
        row = (db.query(UserProfile.full_name_en, UserProfile.full_name_ta)
                 .filter(UserProfile.user_id == s.suggested_by_user_id).first())
        if row:
            name = row[0] or row[1]
    return ContactSuggestionOut(
        id=s.id, authority_id=s.authority_id,
        designation=(a.designation_en if a else None),
        department=(a.department.name_en if a and a.department else None),
        phone=s.phone, email=s.email, how_they_know=s.how_they_know,
        status=s.status, suggested_by=name, created_at=s.created_at,
    )


@router.get("/contact-suggestions", response_model=list[ContactSuggestionOut])
def list_contact_suggestions(
    status_filter: str = Query(default="PENDING", alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The queue an organiser works through."""
    _require_reviewer(current_user)
    rows = (db.query(ContactSuggestion)
              .filter(ContactSuggestion.organization_id == current_user.organization_id,
                      ContactSuggestion.status == status_filter)
              .order_by(ContactSuggestion.created_at.asc())
              .all())
    return [_suggestion_out(db, s) for s in rows]


class SuggestionReviewIn(BaseModel):
    accept: bool
    note: Optional[str] = Field(default=None, max_length=500)


@router.post("/contact-suggestions/{suggestion_id}/review",
             response_model=ContactSuggestionOut)
def review_contact_suggestion(
    suggestion_id: UUID,
    payload: SuggestionReviewIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Accept it into the directory, or turn it down with a reason.

    Accepting writes the contact onto the office and records who vouched for
    it, because the same rule applies to a member's number as to a scraped
    one: an entry nobody can trace is one nobody can check when it stops
    working.
    """
    _require_reviewer(current_user)
    s = db.get(ContactSuggestion, suggestion_id)
    if s is None or s.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Unknown suggestion")
    if s.status != ContactSuggestionStatus.PENDING.value:
        raise HTTPException(status_code=409, detail="Already reviewed")

    if payload.accept:
        a = db.get(Authority, s.authority_id)
        if a is None:
            raise HTTPException(status_code=404, detail="Office no longer exists")
        if s.phone:
            a.phone = s.phone
        if s.email:
            a.email = s.email
        a.source_url = f"member-suggestion:{s.id}"
        a.verified_at = datetime.now(timezone.utc)

    s.status = (ContactSuggestionStatus.ACCEPTED.value if payload.accept
                else ContactSuggestionStatus.REJECTED.value)
    s.reviewed_by_user_id = current_user.id
    s.reviewed_at = datetime.now(timezone.utc)
    s.review_note = payload.note
    db.commit()
    db.refresh(s)
    return _suggestion_out(db, s)


def _require_reviewer(user: User) -> None:
    """Only an organiser decides what the directory says.

    This is the gate the whole feature rests on: without it, one wrong
    submission quietly redirects every future complaint about a street to a
    stranger, over the club's name.
    """
    allowed = {"EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN", "PRESIDENT",
               "SECRETARY"}
    role = getattr(user, "role", "")
    role = getattr(role, "value", role)
    if role not in allowed:
        raise HTTPException(status_code=403,
                            detail="Only club organisers can review contacts")
