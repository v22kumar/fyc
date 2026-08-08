"""The local work index.

See docs/work/01-architecture.md and 02-screens.md.

Two rules run through everything here.

**Looking does not need an account.** Somebody with a broken door should not
have to register to find a carpenter. Listing requires an account; searching
does not.

**Nothing here is a rating.** Trust is assembled from facts that accumulate
without anybody's judgement — a verified number, how long they have been a
member, how many jobs somebody else confirmed. There is no approval queue,
because gatekeeping costs an organiser's evening every week forever; there is
a report queue instead, and it acts on its own before anybody is awake.
"""
import uuid
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user
from app.models.user import User, UserProfile
from app.models.work import (
    Listing, ListingKind, ListingReport, ReportReason, ReportStatus,
    WorkCategory, WorkRecord,
)

router = APIRouter(prefix="/work", tags=["Work"])

#: Two upheld reports hide a listing, automatically.
#:
#: One is never enough — an angry customer must not be able to remove a
#: competitor from the village index. But a rule that waits for an organiser
#: to be free does not work at 9pm on a Sunday, which is exactly when it
#: matters.
HIDE_AFTER_UPHELD = 2

_REVIEWER_ROLES = {"EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN", "PRESIDENT",
                   "SECRETARY"}


# ── Wire shapes ───────────────────────────────────────────────────────────────

class CategoryOut(BaseModel):
    code: str
    count: int


class TrustOut(BaseModel):
    """What is simply true about a listing, for the person deciding.

    Deliberately not a score. A five-star average in a town this size is a
    popularity contest with a feud attached, and the research is clear that
    people do not believe them anyway.
    """

    phone_verified: bool
    member_since_year: Optional[int] = None
    jobs_confirmed: int
    #: True when nothing has happened yet. Said out loud rather than left
    #: blank, because letting an empty record look like a good one is how a
    #: directory spends the only trust it has.
    is_new: bool


class ListingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    kind: str
    display_name: str
    category: str
    about: Optional[str] = None
    area: Optional[str] = None
    phone: str
    whatsapp: Optional[str] = None
    address: Optional[str] = None
    hours: Optional[str] = None
    trust: TrustOut
    #: A club-seeded example. The app shows it as one and will not dial it.
    is_sample: bool = False


class ListingIn(BaseModel):
    display_name: str = Field(min_length=2, max_length=120)
    category: str
    about: Optional[str] = Field(default=None, max_length=2000)
    area: Optional[str] = Field(default=None, max_length=120)
    phone: str = Field(min_length=6, max_length=20)
    whatsapp: Optional[str] = Field(default=None, max_length=20)
    kind: str = ListingKind.PERSON.value
    address: Optional[str] = Field(default=None, max_length=500)
    hours: Optional[str] = Field(default=None, max_length=120)


class MyListingOut(ListingOut):
    """What the owner sees, and the reason they come back.

    Somebody who listed once and heard nothing concludes it did not work. The
    view count is the only honest thing the app can show them.
    """

    view_count: int
    is_active: bool
    is_hidden: bool


class ReportIn(BaseModel):
    reason: str
    note: Optional[str] = Field(default=None, max_length=1000)


class RecordIn(BaseModel):
    what: str = Field(min_length=2, max_length=500)
    client_user_id: Optional[UUID] = None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _org_of(request_user: Optional[User], db: Session) -> Optional[UUID]:
    return request_user.organization_id if request_user else None


def _trust(db: Session, listing: Listing) -> TrustOut:
    confirmed = (
        db.query(func.count(WorkRecord.id))
        .filter(WorkRecord.listing_id == listing.id,
                WorkRecord.confirmed_at.isnot(None))
        .scalar()
    ) or 0

    owner = db.get(User, listing.owner_user_id)
    year = None
    if owner is not None and owner.created_at:
        year = owner.created_at.year

    return TrustOut(
        # They did an OTP to sign in at all, so this is already true — it costs
        # nothing to show and it is the single fact people most want.
        phone_verified=bool(owner and getattr(owner, "is_verified", False)),
        member_since_year=year,
        jobs_confirmed=confirmed,
        is_new=(confirmed == 0),
    )


def _out(db: Session, listing: Listing) -> ListingOut:
    return ListingOut(
        id=listing.id, kind=listing.kind, display_name=listing.display_name,
        category=listing.category, about=listing.about, area=listing.area,
        phone=listing.phone, whatsapp=listing.whatsapp,
        address=listing.address, hours=listing.hours,
        trust=_trust(db, listing),
        is_sample=bool(listing.is_sample),
    )


def _visible(q):
    return q.filter(Listing.is_active.is_(True), Listing.is_hidden.is_(False))


def _require_reviewer(user: User) -> None:
    role = getattr(getattr(user, "role", ""), "value", getattr(user, "role", ""))
    if role not in _REVIEWER_ROLES:
        raise HTTPException(status_code=403,
                            detail="Only club organisers can review reports")


# ── Finding somebody ──────────────────────────────────────────────────────────

@router.get("/categories", response_model=list[CategoryOut])
def categories(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The categories that actually have somebody in them.

    Empty ones are dropped rather than shown with a zero. A person who taps
    "Plumbing" and finds nothing concludes the whole app is empty and does not
    come back — so an empty tile is an advertisement against the product.
    """
    rows = (
        _visible(db.query(Listing.category, func.count(Listing.id)))
        .filter(Listing.organization_id == current_user.organization_id)
        .group_by(Listing.category)
        .all()
    )
    return [CategoryOut(code=c, count=n) for c, n in rows if n > 0]


@router.get("/listings", response_model=list[ListingOut])
def search_listings(
    q: Optional[str] = Query(default=None, description="free text"),
    category: Optional[str] = Query(default=None),
    area: Optional[str] = Query(default=None),
    limit: int = Query(default=50, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Search, which is what people actually arrive wanting.

    The free text matches the name and the words they wrote about themselves,
    because "interlock brick" is never going to be a category and is exactly
    what somebody types.
    """
    query = _visible(
        db.query(Listing).filter(
            Listing.organization_id == current_user.organization_id
        )
    )
    if category:
        query = query.filter(Listing.category == category)
    if area:
        query = query.filter(Listing.area.ilike(f"%{area}%"))
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            Listing.display_name.ilike(like) | Listing.about.ilike(like)
        )

    rows = query.all()

    # Proven work first, then the newest.
    #
    # Ordering by recency alone — which is what this did — puts a listing
    # created five minutes ago above somebody with nine confirmed jobs, so the
    # first thing a searcher sees is the least proven option on the screen.
    #
    # But sorting purely by confirmed jobs is the other trap: nobody new is
    # ever seen, so nobody new is ever hired, so nobody new ever accumulates
    # jobs, and the index cannot bootstrap. Grouping rather than ranking gets
    # both — anybody with a confirmed job is above anybody without one, and
    # inside each group the newest is first, so a new listing is on the same
    # screen rather than buried on page three.
    def _rank(listing: Listing):
        confirmed = (
            db.query(func.count(WorkRecord.id))
            .filter(WorkRecord.listing_id == listing.id,
                    WorkRecord.confirmed_at.isnot(None))
            .scalar()
        ) or 0
        return (0 if confirmed > 0 else 1, -(listing.created_at.timestamp()))

    rows.sort(key=_rank)
    return [_out(db, r) for r in rows[offset:offset + limit]]


@router.get("/listings/{listing_id}", response_model=ListingOut)
def get_listing(
    listing_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    listing = db.get(Listing, listing_id)
    if (listing is None
            or listing.organization_id != current_user.organization_id
            or not listing.is_active or listing.is_hidden):
        raise HTTPException(status_code=404, detail="Listing not found")
    return _out(db, listing)


@router.post("/listings/{listing_id}/view", status_code=204)
def record_view(
    listing_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Somebody opened it.

    Fires the number behind "seen by 12 people this week", which is the only
    honest thing to show a member who listed once and heard nothing.
    """
    listing = db.get(Listing, listing_id)
    if listing is None or listing.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Listing not found")
    listing.view_count = (listing.view_count or 0) + 1
    db.commit()


# ── Being findable ────────────────────────────────────────────────────────────

@router.post("/listings", response_model=MyListingOut, status_code=201)
def create_listing(
    payload: ListingIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List what you do. Short enough to finish standing up."""
    if payload.category not in {c.value for c in WorkCategory}:
        raise HTTPException(status_code=422, detail="Unknown category")
    if payload.kind not in {k.value for k in ListingKind}:
        raise HTTPException(status_code=422, detail="Unknown kind")

    listing = Listing(
        organization_id=current_user.organization_id,
        owner_user_id=current_user.id,
        kind=payload.kind,
        display_name=payload.display_name.strip(),
        category=payload.category,
        about=(payload.about or "").strip() or None,
        area=(payload.area or "").strip() or None,
        phone=payload.phone.strip(),
        whatsapp=(payload.whatsapp or "").strip() or None,
        address=(payload.address or "").strip() or None,
        hours=(payload.hours or "").strip() or None,
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return _my_out(db, listing)


def _my_out(db: Session, listing: Listing) -> MyListingOut:
    base = _out(db, listing)
    return MyListingOut(**base.model_dump(), view_count=listing.view_count or 0,
                        is_active=listing.is_active, is_hidden=listing.is_hidden)


@router.get("/my", response_model=list[MyListingOut])
def my_listings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (db.query(Listing)
              .filter(Listing.owner_user_id == current_user.id)
              .order_by(Listing.created_at.desc()).all())
    return [_my_out(db, r) for r in rows]


@router.patch("/listings/{listing_id}", response_model=MyListingOut)
def update_listing(
    listing_id: UUID,
    payload: ListingIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    listing = db.get(Listing, listing_id)
    if listing is None or listing.owner_user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Listing not found")
    if payload.category not in {c.value for c in WorkCategory}:
        raise HTTPException(status_code=422, detail="Unknown category")

    listing.display_name = payload.display_name.strip()
    listing.category = payload.category
    listing.about = (payload.about or "").strip() or None
    listing.area = (payload.area or "").strip() or None
    listing.phone = payload.phone.strip()
    listing.whatsapp = (payload.whatsapp or "").strip() or None
    listing.address = (payload.address or "").strip() or None
    listing.hours = (payload.hours or "").strip() or None
    db.commit()
    db.refresh(listing)
    return _my_out(db, listing)


# ── The record, which is the point of the whole thing ─────────────────────────

@router.post("/listings/{listing_id}/records", status_code=201)
def add_record(
    listing_id: UUID,
    payload: RecordIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """A job was done.

    Recorded, but not counted. It becomes part of the trust line only when the
    person who received the work confirms it — an unconfirmed self-report is
    the same claim as before, wearing a number.
    """
    listing = db.get(Listing, listing_id)
    if listing is None or listing.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Listing not found")

    record = WorkRecord(
        organization_id=current_user.organization_id,
        listing_id=listing_id,
        client_user_id=payload.client_user_id or (
            None if current_user.id == listing.owner_user_id else current_user.id
        ),
        what=payload.what.strip(),
        # A job the client themselves is recording is already confirmed — they
        # are the person the confirmation would be asked of.
        confirmed_at=(datetime.now(timezone.utc)
                      if current_user.id != listing.owner_user_id else None),
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return {"id": str(record.id),
            "confirmed": record.confirmed_at is not None}


@router.post("/records/{record_id}/confirm", status_code=200)
def confirm_record(
    record_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The person who received the work says it happened.

    Only they can. The whole value of the record is that somebody other than
    the person it flatters put their name to it.
    """
    record = db.get(WorkRecord, record_id)
    if record is None or record.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Record not found")
    if record.client_user_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the person who received the work can confirm it")
    if record.confirmed_at is None:
        record.confirmed_at = datetime.now(timezone.utc)
        db.commit()
    return {"confirmed": True}


# ── Reporting, the only line of defence ───────────────────────────────────────

@router.post("/listings/{listing_id}/report", status_code=201)
def report_listing(
    listing_id: UUID,
    payload: ReportIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Anyone can report. Not only members, not only people who hired.

    There is no approval queue in front of this feature, so this is the whole
    safety mechanism. It has to work without waiting for an organiser to be
    awake.
    """
    if payload.reason not in {r.value for r in ReportReason}:
        raise HTTPException(status_code=422, detail="Unknown reason")

    listing = db.get(Listing, listing_id)
    if listing is None or listing.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Listing not found")

    db.add(ListingReport(
        organization_id=current_user.organization_id,
        listing_id=listing_id,
        reported_by_user_id=current_user.id,
        reason=payload.reason,
        note=(payload.note or "").strip() or None,
    ))
    db.commit()
    return {"received": True}


def _apply_hide_rule(db: Session, listing: Listing) -> None:
    """Two upheld reports hide a listing, on their own.

    One is never enough: an angry customer must not be able to remove a
    competitor from the village index. But a rule that waits for somebody to
    be free does not work at 9pm on a Sunday, which is when it matters.

    Hiding is separate from the owner's own active flag, so a listing that is
    later cleared comes back exactly as it was.
    """
    # The status just set on this report is still pending; without flushing it
    # the count sees the state from before the decision and the rule is always
    # one report behind.
    db.flush()
    upheld = (db.query(func.count(ListingReport.id))
                .filter(ListingReport.listing_id == listing.id,
                        ListingReport.status == ReportStatus.UPHELD.value)
                .scalar()) or 0
    listing.is_hidden = upheld >= HIDE_AFTER_UPHELD


class ReportOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    listing_id: UUID
    listing_name: Optional[str] = None
    reason: str
    note: Optional[str] = None
    status: str
    reported_by: Optional[str] = None
    created_at: datetime


@router.get("/reports", response_model=list[ReportOut])
def list_reports(
    status_filter: str = Query(default=ReportStatus.OPEN.value, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The organiser queue. Same shape as the complaint reviewer's, because it
    is the same job: read what a member said, decide, record why."""
    _require_reviewer(current_user)
    rows = (db.query(ListingReport)
              .filter(ListingReport.organization_id == current_user.organization_id,
                      ListingReport.status == status_filter)
              .order_by(ListingReport.created_at.asc()).all())

    out = []
    for r in rows:
        listing = db.get(Listing, r.listing_id)
        name = None
        if r.reported_by_user_id:
            row = (db.query(UserProfile.full_name_en, UserProfile.full_name_ta)
                     .filter(UserProfile.user_id == r.reported_by_user_id).first())
            if row:
                name = row[0] or row[1]
        out.append(ReportOut(
            id=r.id, listing_id=r.listing_id,
            listing_name=(listing.display_name if listing else None),
            reason=r.reason, note=r.note, status=r.status,
            reported_by=name, created_at=r.created_at,
        ))
    return out


class ReportReviewIn(BaseModel):
    uphold: bool
    note: Optional[str] = Field(default=None, max_length=1000)


@router.post("/reports/{report_id}/review", response_model=ReportOut)
def review_report(
    report_id: UUID,
    payload: ReportReviewIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Uphold it or dismiss it, and let the hide rule recount."""
    _require_reviewer(current_user)
    report = db.get(ListingReport, report_id)
    if report is None or report.organization_id != current_user.organization_id:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != ReportStatus.OPEN.value:
        raise HTTPException(status_code=409, detail="Already reviewed")

    report.status = (ReportStatus.UPHELD.value if payload.uphold
                     else ReportStatus.DISMISSED.value)
    report.reviewed_by_user_id = current_user.id
    report.reviewed_at = datetime.now(timezone.utc)
    report.review_note = payload.note

    listing = db.get(Listing, report.listing_id)
    if listing is not None:
        _apply_hide_rule(db, listing)
    db.commit()
    db.refresh(report)

    return ReportOut(
        id=report.id, listing_id=report.listing_id,
        listing_name=(listing.display_name if listing else None),
        reason=report.reason, note=report.note, status=report.status,
        created_at=report.created_at,
    )
