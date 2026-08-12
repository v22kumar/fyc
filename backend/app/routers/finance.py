"""Event finance: campaigns, treasurers, and the money they collect.

Every endpoint here resolves permission through one function
(`finance_access.resolve`) rather than repeating a comparison, and every query
is gated on the caller's organisation. Both are deliberate: cricket answers the
same questions with the same check copy-pasted at four call sites, and the
place to discover that the fifth copy forgot something is not the ledger.
"""
from __future__ import annotations

import csv as _csv
import io as _io
import logging
import uuid
from datetime import date, datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.money import format_paise, paise_to_rupees, rupees_to_paise
from app.dependencies import get_current_user
from app.models.event import Event
from app.models.finance import (METHODS_WITH_REFERENCE, Contribution,
                                FinanceCampaign, FinanceCampaignAssignment)
from app.models.user import User, UserProfile
from app.schemas.finance import (AssignmentCreate, AssignmentOut,
                                 CampaignCreate, CampaignOut, CampaignUpdate,
                                 ContributionCreate, ContributionOut,
                                 ContributionUpdate, DuplicateCandidate,
                                 Resolution, campaign_out, contribution_out)
from app.services import finance_access, finance_ledger, finance_reports

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/finance", tags=["Finance"])


# ── Shared plumbing ─────────────────────────────────────────────────────────

def _campaign_and_access(db: Session, campaign_id: UUID, user: User):
    """Load the campaign for this club, or 404 as if it did not exist.

    A campaign id belonging to another organisation must be indistinguishable
    from one that was never created. Anything else is a way to ask whether a
    given id exists elsewhere.
    """
    campaign = finance_access.load_campaign(db, campaign_id, user)
    if campaign is None:
        raise HTTPException(status_code=404, detail="Campaign not found")
    return campaign, finance_access.resolve(db, campaign, user)


def _names_for(db: Session, contributions) -> dict:
    """One query for every name these rows need, not one per row."""
    ids = set()
    for c in contributions:
        for uid in (c.recorded_by_user_id, c.verified_by_user_id):
            if uid:
                ids.add(uid)
    if not ids:
        return {}
    rows = (db.query(User.id, UserProfile.full_name_en, User.phone_number)
              .outerjoin(UserProfile, UserProfile.user_id == User.id)
              .filter(User.id.in_(ids)).all())
    return {str(uid): (name or phone or "Member") for uid, name, phone in rows}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=message)


# ── Campaigns ───────────────────────────────────────────────────────────────

@router.post("/campaigns", response_model=CampaignOut, status_code=201)
def create_campaign(payload: CampaignCreate, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    """Create a collection. Next year, this is the only step that repeats."""
    access_role = (current_user.role or "").upper()
    _require(access_role in ("EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"),
             "Only club officials can create a collection.")

    event_id = payload.event_id
    if event_id:
        exists = db.query(Event.id).filter(
            Event.id == event_id,
            Event.organization_id == current_user.organization_id,
        ).first()
        if not exists:
            raise HTTPException(status_code=404, detail="Event not found")
    elif payload.create_event:
        event_id = _mint_event(db, payload, current_user)

    campaign = FinanceCampaign(
        organization_id=current_user.organization_id,
        event_id=event_id,
        title_en=payload.title_en.strip(),
        # Falling back to the English title rather than refusing: a Tamil title
        # is worth having and not worth blocking a collection over.
        title_ta=(payload.title_ta or payload.title_en).strip(),
        description=payload.description,
        purpose=(payload.purpose or "OTHER").upper(),
        target_amount_paise=(rupees_to_paise(payload.target_amount)
                             if payload.target_amount else None),
        suggested_amount_paise=(rupees_to_paise(payload.suggested_amount)
                                if payload.suggested_amount else None),
        starts_on=payload.starts_on,
        ends_on=payload.ends_on,
        status=(payload.status or "ACTIVE").upper(),
        created_by_user_id=current_user.id,
    )
    db.add(campaign)
    db.commit()
    db.refresh(campaign)

    finance_ledger.record_audit(
        db, user=current_user, action="FINANCE_CAMPAIGN_CREATED",
        contribution_id=campaign.id, table="finance_campaigns",
        new={"title": campaign.title_en, "target_paise": campaign.target_amount_paise},
    )
    db.commit()

    return campaign_out(campaign, finance_access.resolve(db, campaign, current_user))


def _mint_event(db: Session, payload: CampaignCreate, user: User):
    """Create the Event this campaign funds, from the campaign's own details.

    The alternative is telling an admin to go to another screen, create an
    event, come back, and link it — three chances to end up with a collection
    attached to nothing. The Event is a normal Event afterwards: it appears in
    the events list, it can be edited there, and nothing about it is special.
    """
    start = payload.starts_on or date.today()
    end = payload.ends_on or start
    event = Event(
        id=uuid.uuid4(),
        organization_id=user.organization_id,
        title_en=payload.title_en.strip(),
        title_ta=(payload.title_ta or payload.title_en).strip(),
        description_en=payload.description or payload.title_en.strip(),
        description_ta=payload.description or (payload.title_ta or payload.title_en).strip(),
        event_start=datetime.combine(start, datetime.min.time()).replace(tzinfo=timezone.utc),
        event_end=datetime.combine(end, datetime.max.time()).replace(tzinfo=timezone.utc),
        event_kind="CELEBRATION" if (payload.purpose or "").upper() == "ANNIVERSARY" else "OTHER",
        created_by_user_id=user.id,
        is_published=False,
        registration_enabled=False,
        status="active",
    )
    db.add(event)
    db.flush()
    return event.id


@router.get("/campaigns", response_model=List[CampaignOut])
def list_campaigns(status_filter: Optional[str] = Query(None, alias="status"),
                   db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user)):
    """Campaigns this caller may see.

    For an appointed treasurer that is only what they were appointed to. An
    empty list is the right answer for a member with no job, not an error.
    """
    q = finance_access.visible_campaigns(db, current_user)
    if status_filter:
        q = q.filter(FinanceCampaign.status == status_filter.upper())
    campaigns = q.order_by(FinanceCampaign.created_at.desc()).all()
    return [campaign_out(c, finance_access.resolve(db, c, current_user))
            for c in campaigns]


@router.get("/campaigns/{campaign_id}", response_model=CampaignOut)
def get_campaign(campaign_id: UUID, db: Session = Depends(get_db),
                 current_user: User = Depends(get_current_user)):
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_record or access.can_view_all,
             "You are not part of this collection.")
    return campaign_out(campaign, access)


@router.patch("/campaigns/{campaign_id}", response_model=CampaignOut)
def update_campaign(campaign_id: UUID, payload: CampaignUpdate,
                    db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    """Change the collection — including setting or clearing the target.

    The target is deliberately re-settable at any time. A club that raises its
    sights halfway through a collection should not need a developer.
    """
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_manage, "Only club officials can change a collection.")

    before = {"target_paise": campaign.target_amount_paise,
              "suggested_paise": campaign.suggested_amount_paise,
              "status": campaign.status}

    data = payload.model_dump(exclude_unset=True)
    if payload.clear_target:
        campaign.target_amount_paise = None
    elif payload.target_amount is not None:
        campaign.target_amount_paise = rupees_to_paise(payload.target_amount)
    if payload.suggested_amount is not None:
        campaign.suggested_amount_paise = rupees_to_paise(payload.suggested_amount)

    for field in ("title_en", "title_ta", "description", "purpose",
                  "starts_on", "ends_on", "status", "event_id"):
        if field in data and data[field] is not None:
            value = data[field]
            if field in ("purpose", "status"):
                value = str(value).upper()
            if field == "status" and value == "ARCHIVED":
                _require(access.can_archive, "Only an admin can archive a collection.")
            setattr(campaign, field, value)

    db.commit()
    db.refresh(campaign)

    finance_ledger.record_audit(
        db, user=current_user, action="FINANCE_CAMPAIGN_UPDATED",
        contribution_id=campaign.id, table="finance_campaigns",
        old=before,
        new={"target_paise": campaign.target_amount_paise,
             "suggested_paise": campaign.suggested_amount_paise,
             "status": campaign.status},
    )
    db.commit()
    return campaign_out(campaign, access)


# ── Treasurers ──────────────────────────────────────────────────────────────

@router.get("/campaigns/{campaign_id}/assignments", response_model=List[AssignmentOut])
def list_assignments(campaign_id: UUID, db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_view_all, "Only club officials can see the treasurer list.")

    rows = (db.query(FinanceCampaignAssignment, UserProfile.full_name_en, User.phone_number)
              .join(User, User.id == FinanceCampaignAssignment.user_id)
              .outerjoin(UserProfile, UserProfile.user_id == User.id)
              .filter(FinanceCampaignAssignment.campaign_id == campaign_id,
                      FinanceCampaignAssignment.revoked_at.is_(None))
              .all())

    totals = {r["user_id"]: r for r in finance_reports.by_treasurer(db, campaign)}
    out = []
    for assignment, name, phone in rows:
        stat = totals.get(str(assignment.user_id), {})
        out.append(AssignmentOut(
            id=assignment.id,
            user_id=assignment.user_id,
            name=name or phone or "Member",
            phone_number=phone,
            capacity=assignment.capacity,
            assigned_at=assignment.created_at,
            recorded_paise=stat.get("amount_paise", 0),
            payments=stat.get("payments", 0),
        ))
    out.sort(key=lambda a: a.recorded_paise, reverse=True)
    return out


@router.post("/campaigns/{campaign_id}/assignments", response_model=AssignmentOut,
             status_code=201)
def assign_treasurer(campaign_id: UUID, payload: AssignmentCreate,
                     db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_manage, "Only club officials can appoint a treasurer.")

    member = db.query(User).filter(
        User.id == payload.user_id,
        User.organization_id == current_user.organization_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if getattr(member, "is_blocked", False):
        raise HTTPException(status_code=400,
                            detail="This member is blocked and cannot collect money.")

    existing = db.query(FinanceCampaignAssignment).filter(
        FinanceCampaignAssignment.campaign_id == campaign_id,
        FinanceCampaignAssignment.user_id == member.id,
    ).order_by(FinanceCampaignAssignment.created_at.desc()).first()

    if existing and existing.revoked_at is None:
        assignment = existing          # already appointed; appointing again is a no-op
    elif existing is not None:
        existing.revoked_at = None     # re-appointing keeps the original row and history
        assignment = existing
    else:
        assignment = FinanceCampaignAssignment(
            campaign_id=campaign_id,
            user_id=member.id,
            capacity=(payload.capacity or "TREASURER").upper(),
            assigned_by_user_id=current_user.id,
        )
        db.add(assignment)

    db.commit()
    db.refresh(assignment)

    finance_ledger.record_audit(
        db, user=current_user, action="FINANCE_TREASURER_ASSIGNED",
        contribution_id=campaign.id, table="finance_campaign_assignments",
        new={"user_id": str(member.id), "capacity": assignment.capacity},
    )
    db.commit()

    profile = db.query(UserProfile).filter(UserProfile.user_id == member.id).first()
    return AssignmentOut(
        id=assignment.id, user_id=member.id,
        name=(profile.full_name_en if profile else None) or member.phone_number or "Member",
        phone_number=member.phone_number,
        capacity=assignment.capacity,
        assigned_at=assignment.created_at,
    )


@router.delete("/campaigns/{campaign_id}/assignments/{user_id}", status_code=200)
def revoke_treasurer(campaign_id: UUID, user_id: UUID,
                     db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    """Stand a treasurer down. The row stays.

    "Who was allowed to take money in August" is a question the club may need
    to answer later, and a deleted row cannot answer it. What they already
    recorded is untouched — it is the club's money either way.
    """
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_manage, "Only club officials can change treasurers.")

    assignment = db.query(FinanceCampaignAssignment).filter(
        FinanceCampaignAssignment.campaign_id == campaign_id,
        FinanceCampaignAssignment.user_id == user_id,
        FinanceCampaignAssignment.revoked_at.is_(None),
    ).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="This member is not a treasurer here")

    assignment.revoked_at = datetime.now(timezone.utc)
    finance_ledger.record_audit(
        db, user=current_user, action="FINANCE_TREASURER_REVOKED",
        contribution_id=campaign.id, table="finance_campaign_assignments",
        old={"user_id": str(user_id)},
    )
    db.commit()
    return {"revoked": True}


# ── Contributions ───────────────────────────────────────────────────────────

@router.post("/campaigns/{campaign_id}/contributions", response_model=ContributionOut,
             status_code=201)
def record_contribution(campaign_id: UUID, payload: ContributionCreate,
                        db: Session = Depends(get_db),
                        current_user: User = Depends(get_current_user)):
    """Record one payment. The hot path — a treasurer does this fifty times."""
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_record, "You are not collecting for this campaign.")

    if campaign.status != "ACTIVE" and not access.can_manage:
        raise HTTPException(
            status_code=400,
            detail=f"This collection is {campaign.status.lower()} — ask a club "
                   f"official to reopen it.")

    # Layer 1: this exact request already succeeded. Not an error; the same
    # answer, returned again. A double tap and a replayed offline entry look
    # identical from here and both mean "one payment".
    already = finance_ledger.find_by_client_id(
        db, campaign_id, current_user.id, payload.client_contribution_id)
    if already is not None:
        return contribution_out(already, _names_for(db, [already]))

    contributor_user_id, name, phone = _resolve_contributor(db, payload, current_user)
    amount_paise = rupees_to_paise(payload.amount)
    method = payload.method.upper()
    reference = finance_ledger.normalise_reference(payload.reference_no)

    # Cash never needs a reference — demanding one for a note handed across a
    # table is the fastest way to make a treasurer stop using the app — and it
    # must not keep one either. The entry screen deliberately holds on to the
    # method and clears the rest between entries, so a reference left in the
    # field after switching to cash would attach a real UTR to a cash row and
    # then block the UPI entry that legitimately carries it. Every other
    # method may hold a reference: a cheque number and a receipt-book number
    # are both worth keeping.
    if method == "CASH":
        reference = None

    # Layer 2: a UTR is unique in the real world, so two of them is always an
    # error — refused outright, naming the row that already has it.
    if reference:
        clash = finance_ledger.find_by_reference(db, campaign_id, reference)
        if clash is not None:
            raise HTTPException(status_code=409, detail=_duplicate_body(
                db, "reference",
                f"{reference} is already recorded — {format_paise(clash.amount_paise)} "
                f"from {clash.contributor_name}.",
                [clash], can_confirm=False))

    key = finance_ledger.contributor_key(contributor_user_id, phone, name)

    # Layer 3: same giver, same amount, minutes ago. Might be a mistake, might
    # be two neighbours who each gave ₹500. Only a human knows, so ask — and
    # let them say it is a different payment.
    if not payload.confirm_duplicate:
        similar = finance_ledger.find_similar(db, campaign_id, key, amount_paise)
        if similar:
            raise HTTPException(status_code=409, detail=_duplicate_body(
                db, "similar",
                f"You recorded {format_paise(amount_paise)} from {name} a few "
                f"minutes ago. Is this the same payment?",
                similar, can_confirm=True))

    contribution = Contribution(
        campaign_id=campaign_id,
        organization_id=current_user.organization_id,
        contributor_user_id=contributor_user_id,
        contributor_name=name,
        contributor_phone=phone,
        contributor_key=key,
        amount_paise=amount_paise,
        currency=campaign.currency or "INR",
        method=method,
        reference_no=reference,
        paid_on=payload.paid_on or date.today(),
        status="RECORDED",
        recorded_by_user_id=current_user.id,
        notes=payload.notes,
        client_contribution_id=payload.client_contribution_id,
    )
    db.add(contribution)
    try:
        db.commit()
    except IntegrityError:
        # Two requests carrying the same client id raced. The database settled
        # it; return the row that won rather than an error the member cannot
        # act on. A check-then-insert would have let both through.
        db.rollback()
        won = finance_ledger.find_by_client_id(
            db, campaign_id, current_user.id, payload.client_contribution_id)
        if won is not None:
            return contribution_out(won, _names_for(db, [won]))
        raise HTTPException(status_code=409,
                            detail="That contribution was already recorded.")

    db.refresh(contribution)
    finance_ledger.record_audit(
        db, user=current_user, action="CONTRIBUTION_RECORDED",
        contribution_id=contribution.id,
        new=finance_ledger.snapshot(contribution),
    )
    db.commit()
    return contribution_out(contribution, _names_for(db, [contribution]))


def _resolve_contributor(db: Session, payload, current_user):
    """Who paid — a member, or somebody who is not one.

    The name is stored either way. If the member's account is ever removed the
    ledger still reads correctly, which matters more here than anywhere else in
    the app: a financial record with a dangling reference and no name is a row
    nobody can explain.
    """
    if payload.contributor_user_id:
        member = db.query(User).filter(
            User.id == payload.contributor_user_id,
            User.organization_id == current_user.organization_id,
        ).first()
        if not member:
            raise HTTPException(status_code=404, detail="Member not found")
        profile = db.query(UserProfile).filter(UserProfile.user_id == member.id).first()
        name = (payload.contributor_name
                or (profile.full_name_en if profile else None)
                or member.phone_number or "Member")
        return member.id, name.strip()[:150], (payload.contributor_phone
                                               or member.phone_number)

    name = (payload.contributor_name or "").strip()
    if not name:
        raise HTTPException(status_code=422,
                            detail="Who is this contribution from?")
    return None, name[:150], payload.contributor_phone


def _duplicate_body(db: Session, kind: str, message: str, rows, *, can_confirm: bool):
    names = _names_for(db, rows)
    return {
        "detail": message,
        "kind": kind,
        "can_confirm": can_confirm,
        "candidates": [DuplicateCandidate(
            id=r.id,
            contributor_name=r.contributor_name,
            amount_display=format_paise(r.amount_paise),
            method=r.method,
            reference_no=r.reference_no,
            recorded_by_name=names.get(str(r.recorded_by_user_id)),
            created_at=r.created_at,
        ).model_dump(mode="json") for r in rows],
    }


@router.get("/campaigns/{campaign_id}/contributions", response_model=List[ContributionOut])
def list_contributions(
    campaign_id: UUID,
    q: Optional[str] = Query(None, description="Contributor name or phone"),
    status_filter: Optional[str] = Query(None, alias="status"),
    method: Optional[str] = None,
    recorded_by: Optional[UUID] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    min_amount: Optional[float] = None,
    max_amount: Optional[float] = None,
    sort: str = Query("latest", pattern="^(latest|amount|name|treasurer)$"),
    limit: int = Query(100, le=500),
    offset: int = 0,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_record or access.can_view_all,
             "You are not part of this collection.")

    query = db.query(Contribution).filter(
        Contribution.campaign_id == campaign_id,
        # Belt and braces. The campaign was already gated on the caller's
        # organisation; this makes a contribution row unreachable across clubs
        # even if a future change loses that gate.
        Contribution.organization_id == current_user.organization_id,
    )

    # A treasurer sees their own collection, not the club's contributor list.
    # That list is a list of who has money and their phone numbers.
    if access.scope_is_own:
        query = query.filter(Contribution.recorded_by_user_id == current_user.id)

    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(Contribution.contributor_name.ilike(like),
                                 Contribution.contributor_phone.ilike(like),
                                 Contribution.reference_no.ilike(like)))
    if status_filter:
        query = query.filter(Contribution.status == status_filter.upper())
    if method:
        query = query.filter(Contribution.method == method.upper())
    if recorded_by:
        query = query.filter(Contribution.recorded_by_user_id == recorded_by)
    if from_date:
        query = query.filter(Contribution.paid_on >= from_date)
    if to_date:
        query = query.filter(Contribution.paid_on <= to_date)
    if min_amount is not None:
        query = query.filter(Contribution.amount_paise >= rupees_to_paise(min_amount))
    if max_amount is not None:
        query = query.filter(Contribution.amount_paise <= rupees_to_paise(max_amount))

    order = {
        "latest": Contribution.created_at.desc(),
        "amount": Contribution.amount_paise.desc(),
        "name": Contribution.contributor_name.asc(),
        "treasurer": Contribution.recorded_by_user_id.asc(),
    }[sort]

    rows = query.order_by(order).offset(offset).limit(limit).all()
    names = _names_for(db, rows)
    return [contribution_out(c, names) for c in rows]


@router.get("/contributions/{contribution_id}", response_model=ContributionOut)
def get_contribution(contribution_id: UUID, db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    contribution, access = _contribution_and_access(db, contribution_id, current_user)
    if access.scope_is_own and str(contribution.recorded_by_user_id) != str(current_user.id):
        raise HTTPException(status_code=404, detail="Contribution not found")
    return contribution_out(contribution, _names_for(db, [contribution]))


def _contribution_and_access(db: Session, contribution_id: UUID, user: User):
    contribution = db.query(Contribution).filter(
        Contribution.id == contribution_id,
        Contribution.organization_id == user.organization_id,
    ).first()
    if contribution is None:
        raise HTTPException(status_code=404, detail="Contribution not found")
    campaign = finance_access.load_campaign(db, contribution.campaign_id, user)
    if campaign is None:
        raise HTTPException(status_code=404, detail="Contribution not found")
    return contribution, finance_access.resolve(db, campaign, user)


@router.patch("/contributions/{contribution_id}", response_model=ContributionOut)
def update_contribution(contribution_id: UUID, payload: ContributionUpdate,
                        db: Session = Depends(get_db),
                        current_user: User = Depends(get_current_user)):
    """Correct a record.

    A treasurer owns what they recorded, and only while it is still a claim.
    Once an executive has verified it, it is the club's record — changing it is
    an executive's decision, and either way the previous values go to the audit
    log rather than being overwritten out of existence.
    """
    contribution, access = _contribution_and_access(db, contribution_id, current_user)
    if not finance_access.can_touch_contribution(access, contribution):
        raise HTTPException(
            status_code=403,
            detail="This record has been verified — ask a club official to change it."
            if contribution.status == "VERIFIED"
            else "You can only change contributions you recorded.")
    if contribution.status in ("CANCELLED", "REJECTED"):
        raise HTTPException(status_code=400,
                            detail=f"This contribution is {contribution.status.lower()}.")

    before = finance_ledger.snapshot(contribution)
    data = payload.model_dump(exclude_unset=True)

    if payload.amount is not None:
        contribution.amount_paise = rupees_to_paise(payload.amount)
    if payload.method is not None:
        contribution.method = payload.method.upper()
    if "reference_no" in data:
        reference = finance_ledger.normalise_reference(payload.reference_no)
        if reference:
            clash = finance_ledger.find_by_reference(db, contribution.campaign_id, reference)
            if clash is not None and str(clash.id) != str(contribution.id):
                raise HTTPException(status_code=409,
                                    detail=f"{reference} is already recorded here.")
        contribution.reference_no = reference
    for field in ("contributor_name", "contributor_phone", "paid_on", "notes"):
        if field in data:
            setattr(contribution, field, data[field])

    # The identity key is derived, so it has to move when the identity does —
    # otherwise the contributor count silently keeps counting the old spelling.
    contribution.contributor_key = finance_ledger.contributor_key(
        contribution.contributor_user_id, contribution.contributor_phone,
        contribution.contributor_name)

    db.commit()
    db.refresh(contribution)
    finance_ledger.record_audit(
        db, user=current_user, action="CONTRIBUTION_UPDATED",
        contribution_id=contribution.id, old=before,
        new=finance_ledger.snapshot(contribution))
    db.commit()
    return contribution_out(contribution, _names_for(db, [contribution]))


@router.post("/contributions/{contribution_id}/verify", response_model=ContributionOut)
def verify_contribution(contribution_id: UUID, db: Session = Depends(get_db),
                        current_user: User = Depends(get_current_user)):
    """Turn a treasurer's claim into the club's record."""
    contribution, access = _contribution_and_access(db, contribution_id, current_user)
    _require(access.can_verify, "Only club officials can verify a contribution.")
    if contribution.status == "VERIFIED":
        return contribution_out(contribution, _names_for(db, [contribution]))
    if contribution.status in ("CANCELLED", "REJECTED"):
        raise HTTPException(status_code=400,
                            detail=f"This contribution is {contribution.status.lower()}.")

    before = finance_ledger.snapshot(contribution)
    contribution.status = "VERIFIED"
    contribution.verified_by_user_id = current_user.id
    contribution.verified_at = datetime.now(timezone.utc)
    # Allowed, because a club of five cannot always find two pairs of eyes —
    # but counted and shown, rather than indistinguishable from a real check.
    contribution.self_verified = (
        str(contribution.recorded_by_user_id or "") == str(current_user.id))

    db.commit()
    db.refresh(contribution)
    finance_ledger.record_audit(
        db, user=current_user, action="CONTRIBUTION_VERIFIED",
        contribution_id=contribution.id, old=before,
        new=finance_ledger.snapshot(contribution))
    db.commit()
    return contribution_out(contribution, _names_for(db, [contribution]))


@router.post("/contributions/{contribution_id}/reject", response_model=ContributionOut)
def reject_contribution(contribution_id: UUID, payload: Resolution,
                        db: Session = Depends(get_db),
                        current_user: User = Depends(get_current_user)):
    """This payment never really happened — a wrong entry, a bounced cheque."""
    return _resolve(db, contribution_id, current_user, "REJECTED", payload.reason,
                    "CONTRIBUTION_REJECTED")


@router.post("/contributions/{contribution_id}/cancel", response_model=ContributionOut)
def cancel_contribution(contribution_id: UUID, payload: Resolution,
                        db: Session = Depends(get_db),
                        current_user: User = Depends(get_current_user)):
    """It happened and has been withdrawn — refunded, or given back.

    Distinct from rejection on purpose: "this was never real" and "this was
    real and has been undone" are different facts about the club's money, and
    collapsing them loses the only information that would explain the total.
    """
    return _resolve(db, contribution_id, current_user, "CANCELLED", payload.reason,
                    "CONTRIBUTION_CANCELLED")


def _resolve(db: Session, contribution_id: UUID, user: User, new_status: str,
             reason: str, action: str):
    contribution, access = _contribution_and_access(db, contribution_id, user)
    _require(access.can_verify,
             "Only club officials can withdraw a contribution.")
    if contribution.status == new_status:
        return contribution_out(contribution, _names_for(db, [contribution]))

    before = finance_ledger.snapshot(contribution)
    contribution.status = new_status
    contribution.resolution_reason = reason.strip()[:300]
    db.commit()
    db.refresh(contribution)
    finance_ledger.record_audit(
        db, user=user, action=action, contribution_id=contribution.id,
        old=before, new=finance_ledger.snapshot(contribution))
    db.commit()
    return contribution_out(contribution, _names_for(db, [contribution]))


# ── Reporting ───────────────────────────────────────────────────────────────

@router.get("/campaigns/{campaign_id}/summary")
def campaign_summary(campaign_id: UUID, db: Session = Depends(get_db),
                     current_user: User = Depends(get_current_user)):
    """The numbers, derived from the rows. There is no stored total anywhere."""
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_record or access.can_view_all,
             "You are not part of this collection.")

    data = finance_reports.summary(db, campaign)
    data["display"] = {
        "target": format_paise(data["target_paise"]) if data["target_paise"] else None,
        "collected": format_paise(data["collected_paise"]),
        "verified": format_paise(data["verified_paise"]),
        "pending": format_paise(data["pending_paise"]),
        "remaining": (format_paise(data["remaining_paise"])
                      if data["remaining_paise"] is not None else None),
        "average": format_paise(data["average_paise"]),
    }
    # A treasurer gets the campaign total *and* their own, in one request —
    # the two numbers they actually compare.
    if not access.can_view_all:
        data["mine"] = finance_reports.my_summary(db, campaign, current_user)
    return data


@router.get("/campaigns/{campaign_id}/my-summary")
def my_collection(campaign_id: UUID, db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    """What this caller has collected. Four numbers and nothing else."""
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_record, "You are not collecting for this campaign.")
    data = finance_reports.my_summary(db, campaign, current_user)
    data["display"] = {
        "recorded": format_paise(data["recorded_paise"]),
        "verified": format_paise(data["verified_paise"]),
        "pending": format_paise(data["pending_paise"]),
    }
    return data


@router.get("/campaigns/{campaign_id}/breakdown")
def campaign_breakdown(campaign_id: UUID,
                       by: str = Query("treasurer", pattern="^(treasurer|method|day)$"),
                       db: Session = Depends(get_db),
                       current_user: User = Depends(get_current_user)):
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_view_all, "Only club officials can see the full breakdown.")

    rows = {
        "treasurer": finance_reports.by_treasurer,
        "method": finance_reports.by_method,
        "day": finance_reports.by_day,
    }[by](db, campaign)
    for row in rows:
        row["amount_display"] = format_paise(row["amount_paise"])
    return {"by": by, "rows": rows}


@router.get("/campaigns/{campaign_id}/contributions.csv")
def export_contributions_csv(campaign_id: UUID, db: Session = Depends(get_db),
                             current_user: User = Depends(get_current_user)):
    """The whole ledger as a spreadsheet, for the club's own records.

    Admin-gated exactly like the registrations export, because a contributor
    list is a list of who in the village has money and their phone numbers.
    Amounts export as plain rupees — a spreadsheet should be able to add them
    up without parsing a currency symbol.
    """
    campaign, access = _campaign_and_access(db, campaign_id, current_user)
    _require(access.can_view_all, "Only club officials can export contributions.")

    rows = (db.query(Contribution)
              .filter(Contribution.campaign_id == campaign_id)
              .order_by(Contribution.created_at.asc()).all())
    names = _names_for(db, rows)

    out = _io.StringIO()
    w = _csv.writer(out)
    w.writerow(["Contributor", "Phone", "Amount (INR)", "Method", "Reference",
                "Paid on", "Status", "Recorded by", "Verified by", "Verified at",
                "Reason", "Notes", "Recorded at"])
    for c in rows:
        w.writerow([
            c.contributor_name or "",
            c.contributor_phone or "",
            str(paise_to_rupees(c.amount_paise)),
            c.method or "",
            c.reference_no or "",
            c.paid_on.isoformat() if c.paid_on else "",
            c.status or "",
            names.get(str(c.recorded_by_user_id), ""),
            names.get(str(c.verified_by_user_id), ""),
            c.verified_at.isoformat() if c.verified_at else "",
            c.resolution_reason or "",
            (c.notes or "").replace("\n", " "),
            c.created_at.isoformat() if c.created_at else "",
        ])
    out.seek(0)
    fname = f"contributions_{campaign.title_en}".replace(" ", "_")[:60]
    return StreamingResponse(
        iter([out.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{fname}.csv"'},
    )
