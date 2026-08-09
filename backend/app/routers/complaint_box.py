"""The Complaint Box — what happens to a report after it is captured.

See docs/civic/complaint-box-architecture.md.

The load-bearing idea: **the server never infers what happened.** In Lane A the
member sends from their own mail, so nobody here can observe whether the letter
went or whether anyone answered. Every statement is recorded with its author,
and the current state is read from those statements rather than maintained by
guesswork. That is why there is no `PATCH /status` here — a status nobody
asserted is a status that can be wrong on screen, in front of somebody standing
at a government counter.
"""
import uuid
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id
from app.models.civic import Authority
from app.models.issue import (
    CallOutcome, ComplaintAuthor, ComplaintEvent, ComplaintEventType,
    ComplaintLane, ComplaintSeverity, IssueStatus, PublicIssue,
)
from app.models.user import User, UserProfile
from app.schemas.complaint_box import (
    CallLogIn, CloseIn, ComplaintEventOut, ComplaintStateOut,
    ComplaintSummaryOut, DraftIn, DraftOut, ReplyIn, SentIn,
)
from app.services.complaint_letter import CallRecord, Recipient, build_letter

router = APIRouter(prefix="/civic/complaints", tags=["Complaint Box"])

#: How long to wait at a rung before the next one is worth trying. Serious
#: complaints wait half as long — the cost of being slow is higher.
WAIT_DAYS = {ComplaintSeverity.ROUTINE.value: 14, ComplaintSeverity.SERIOUS.value: 7}

#: Statements only their author may make. A member cannot record that the club
#: forwarded something; the club cannot record that the member made a call.
_MEMBER_EVENTS = {
    ComplaintEventType.CALLED, ComplaintEventType.DRAFTED,
    ComplaintEventType.SENT, ComplaintEventType.REPLY_RECEIVED,
    ComplaintEventType.RESOLVED, ComplaintEventType.CLOSED,
    ComplaintEventType.REOPENED, ComplaintEventType.HANDED_TO_FYC,
}


def _get_complaint(db: Session, complaint_id: UUID, user: User, tenant_id: UUID) -> PublicIssue:
    issue = (
        db.query(PublicIssue)
        .filter(PublicIssue.id == complaint_id,
                PublicIssue.organization_id == tenant_id)
        .first()
    )
    if not issue:
        raise HTTPException(status_code=404, detail="Complaint not found")
    if issue.reported_by_user_id != user.id and not getattr(user, "is_admin", False):
        raise HTTPException(status_code=403, detail="This is not your complaint")
    return issue


def _record(
    db: Session, issue: PublicIssue, *, author: ComplaintAuthor, user_id,
    event_type: ComplaintEventType, authority_id=None, authority_label=None,
    call_outcome=None, note=None,
) -> ComplaintEvent:
    ev = ComplaintEvent(
        organization_id=issue.organization_id,
        issue_id=issue.id,
        author=author.value,
        author_user_id=user_id,
        event_type=event_type.value,
        authority_id=authority_id,
        authority_label=authority_label,
        call_outcome=call_outcome,
        note=note,
    )
    db.add(ev)
    return ev


def _aware(dt):
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _state(db: Session, issue: PublicIssue) -> ComplaintStateOut:
    events = (
        db.query(ComplaintEvent)
        .filter(ComplaintEvent.issue_id == issue.id)
        .order_by(ComplaintEvent.created_at.asc())
        .all()
    )
    names = {}
    ids = {e.author_user_id for e in events if e.author_user_id}
    if ids:
        for uid, en, ta in (
            db.query(UserProfile.user_id, UserProfile.full_name_en,
                     UserProfile.full_name_ta)
            .filter(UserProfile.user_id.in_(ids)).all()
        ):
            names[uid] = en or ta

    closed = issue.status in (IssueStatus.RESOLVED, IssueStatus.CLOSED)

    # "Waiting to hear" is measured from the last thing that left — a letter or
    # a call — not from when the complaint was captured. A report nobody has
    # acted on yet is not waiting for a reply.
    waiting = None
    if not closed:
        last_out = [e for e in events if e.event_type in (
            ComplaintEventType.SENT.value, ComplaintEventType.CALLED.value,
            ComplaintEventType.FYC_FORWARDED.value)]
        if last_out:
            since = _aware(last_out[-1].created_at)
            waiting = max(0, (datetime.now(timezone.utc) - since).days)

    return ComplaintStateOut(
        id=issue.id,
        category=issue.category or "",
        description=issue.description_en or issue.description_ta or "",
        place_name=issue.location_name,
        photo_url=issue.photo_url,
        created_at=issue.created_at,
        lane=issue.lane or ComplaintLane.SELF.value,
        severity=issue.severity or ComplaintSeverity.ROUTINE.value,
        status=issue.status.value if hasattr(issue.status, "value") else str(issue.status),
        waiting_days=waiting,
        is_closed=closed,
        closed_reason=issue.closed_reason,
        events=[
            ComplaintEventOut(
                id=e.id, author=e.author, author_name=names.get(e.author_user_id),
                event_type=e.event_type, authority_label=e.authority_label,
                call_outcome=e.call_outcome, note=e.note, created_at=e.created_at,
            )
            for e in events
        ],
    )


def _reject_if_closed(issue: PublicIssue) -> None:
    """A closed complaint is locked.

    Not pedantry: an ended complaint that keeps accepting events keeps nudging
    and keeps escalating, and a member who has told us they are done should be
    left alone.
    """
    if issue.status in (IssueStatus.RESOLVED, IssueStatus.CLOSED):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This complaint is closed. Reopen it first.",
        )


@router.get("", response_model=list[ComplaintSummaryOut])
def my_complaints(
    include_closed: bool = True,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """The member's own complaints, with where each one actually stands.

    The old tracking screen listed issues by a status column the server
    maintained by guessing. This lists them by what somebody said: the last
    authored event, and how long it has been since anything left. Closed ones
    are included but sort last — a list that hides them looks like work
    disappeared, and a list that mixes them in is mostly dead rows.
    """
    issues = (
        db.query(PublicIssue)
        .filter(PublicIssue.organization_id == tenant_id,
                PublicIssue.reported_by_user_id == current_user.id)
        .order_by(PublicIssue.created_at.desc())
        .all()
    )
    if not issues:
        return []

    # One query for every complaint's events rather than one per complaint.
    ids = [i.id for i in issues]
    events = (
        db.query(ComplaintEvent)
        .filter(ComplaintEvent.issue_id.in_(ids))
        .order_by(ComplaintEvent.created_at.asc())
        .all()
    )
    by_issue: dict = {}
    for e in events:
        by_issue.setdefault(e.issue_id, []).append(e)

    now = datetime.now(timezone.utc)
    out: list[ComplaintSummaryOut] = []
    for issue in issues:
        closed = issue.status in (IssueStatus.RESOLVED, IssueStatus.CLOSED)
        if closed and not include_closed:
            continue

        mine = by_issue.get(issue.id, [])
        waiting = None
        if not closed:
            outbound = [e for e in mine if e.event_type in (
                ComplaintEventType.SENT.value,
                ComplaintEventType.CALLED.value,
                ComplaintEventType.FYC_FORWARDED.value)]
            if outbound:
                waiting = max(
                    0, (now - _aware(outbound[-1].created_at)).days)

        last = mine[-1] if mine else None
        out.append(ComplaintSummaryOut(
            id=issue.id,
            category=issue.category,
            description=(issue.description_en or issue.description_ta or ""),
            place_name=issue.location_name,
            photo_url=issue.photo_url,
            lane=issue.lane or ComplaintLane.SELF.value,
            severity=issue.severity or ComplaintSeverity.ROUTINE.value,
            status=(issue.status.value if hasattr(issue.status, "value")
                    else str(issue.status)),
            is_closed=closed,
            closed_reason=issue.closed_reason,
            waiting_days=waiting,
            last_event=(last.event_type if last else None),
            last_event_at=(last.created_at if last else None),
            created_at=issue.created_at,
        ))

    # Open first, then closed. Inside each, the ones waiting longest first —
    # a complaint nobody has answered in three weeks is the one that needs
    # somebody to look at it.
    out.sort(key=lambda c: (
        c.is_closed,
        -(c.waiting_days if c.waiting_days is not None else -1),
    ))
    return out


@router.get("/{complaint_id}", response_model=ComplaintStateOut)
def get_complaint(
    complaint_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """The complaint, and everything anybody has said about it."""
    return _state(db, _get_complaint(db, complaint_id, current_user, tenant_id))


@router.post("/{complaint_id}/calls", response_model=ComplaintStateOut)
def log_call(
    complaint_id: UUID,
    payload: CallLogIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """The member says they rang somebody.

    Worth more than it looks: this becomes the opening line of any letter that
    follows, and "I spoke to the Assistant Engineer on the 5th, who said it
    would be seen to" is what makes a letter land with his supervisor.
    """
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    _reject_if_closed(issue)
    if payload.outcome not in {o.value for o in CallOutcome}:
        raise HTTPException(status_code=422, detail="Unknown call outcome")

    label = payload.authority_label
    if payload.authority_id and not label:
        a = db.get(Authority, payload.authority_id)
        if a:
            label = f"{a.designation_en}, {a.department.name_en}"

    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=ComplaintEventType.CALLED, authority_id=payload.authority_id,
            authority_label=label, call_outcome=payload.outcome, note=payload.note)
    db.commit()
    return _state(db, issue)


@router.post("/{complaint_id}/sent", response_model=ComplaintStateOut)
def mark_sent(
    complaint_id: UUID,
    payload: SentIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """The member says they sent the letter.

    The app asks once and believes the answer. It never marks a letter sent on
    its own — it handed the draft to another application and genuinely does not
    know. With the club's blind copy on, the copy arriving records this instead
    and nobody is asked at all.
    """
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    _reject_if_closed(issue)
    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=ComplaintEventType.SENT,
            authority_id=payload.authority_id,
            authority_label=payload.authority_label, note=payload.note)
    if issue.status == IssueStatus.NEW:
        issue.status = IssueStatus.UNDER_REVIEW
    db.commit()
    return _state(db, issue)


@router.post("/{complaint_id}/reply", response_model=ComplaintStateOut)
def mark_reply(
    complaint_id: UUID,
    payload: ReplyIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Somebody answered. Only the member can know this in Lane A — reading
    their inbox would need a restricted Gmail scope we have deliberately not
    taken."""
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    _reject_if_closed(issue)
    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=ComplaintEventType.REPLY_RECEIVED, note=payload.note)
    db.commit()
    return _state(db, issue)


@router.post("/{complaint_id}/close", response_model=ComplaintStateOut)
def close_complaint(
    complaint_id: UUID,
    payload: CloseIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """End it, whatever we know.

    Available at any time and never gated on the app having observed anything.
    Somebody who fixed the problem by walking into the office must be able to
    say so, and a complaint that can only be closed by an event we can see
    stays open forever — which makes the whole list useless.
    """
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    issue.status = IssueStatus.RESOLVED if payload.resolved else IssueStatus.CLOSED
    issue.closed_reason = payload.reason
    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=(ComplaintEventType.RESOLVED if payload.resolved
                        else ComplaintEventType.CLOSED),
            note=payload.reason)
    db.commit()
    return _state(db, issue)


@router.post("/{complaint_id}/reopen", response_model=ComplaintStateOut)
def reopen_complaint(
    complaint_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """One tap back, because people close things by mistake."""
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    issue.status = IssueStatus.UNDER_REVIEW
    issue.closed_reason = None
    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=ComplaintEventType.REOPENED)
    db.commit()
    return _state(db, issue)


@router.post("/{complaint_id}/handover", response_model=ComplaintStateOut)
def hand_to_club(
    complaint_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Lane B. The member would rather not deal with an office at all, which is
    a reasonable preference and not a failure on their part."""
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    _reject_if_closed(issue)
    issue.lane = ComplaintLane.VIA_CLUB.value
    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=ComplaintEventType.HANDED_TO_FYC)
    db.commit()
    return _state(db, issue)


@router.post("/{complaint_id}/draft", response_model=DraftOut)
def draft_letter(
    complaint_id: UUID,
    payload: DraftIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Write the letter, ready to hand to the member's own mail app.

    The skeleton is code and the model fills two slots — a subject and a few
    sentences. When the model is unavailable the member's own words go in the
    body and the letter still sends, which is the whole reason for not asking
    it to write the document.

    Any calls the member logged become a paragraph. That paragraph is why a
    letter to an Executive Engineer lands: it says the ladder has already been
    climbed, with dates.
    """
    issue = _get_complaint(db, complaint_id, current_user, tenant_id)
    _reject_if_closed(issue)

    authority = db.get(Authority, payload.authority_id) if payload.authority_id else None
    if authority is not None and authority.organization_id != tenant_id:
        raise HTTPException(status_code=404, detail="Unknown office")

    recipient = Recipient(
        designation=(authority.designation_en if authority else "Sir / Madam"),
        office=(authority.department.name_en if authority else ""),
        email=((authority.email or "").strip() or None) if authority else None,
    )

    description = issue.description_en or issue.description_ta or ""
    subject = f"Complaint — {issue.category}"
    ai_written = False
    if payload.use_ai:
        try:
            from app.services.ai_service import AIService

            drafted = AIService(db).draft_complaint(
                recipient.line, description, issue.location_name,
                bool(issue.is_emergency),
            )
            if drafted and drafted.get("subject") and drafted.get("body_en"):
                subject = drafted["subject"]
                description = drafted["body_en"]
                ai_written = True
        except Exception:
            # A model that is down must not stop somebody complaining about a
            # broken drain. Their own words are a perfectly good letter.
            ai_written = False

    calls = [
        CallRecord(
            office=e.authority_label or "the office",
            on=_aware(e.created_at).date(),
            outcome=e.call_outcome or CallOutcome.REACHED.value,
        )
        for e in (
            db.query(ComplaintEvent)
            .filter(ComplaintEvent.issue_id == issue.id,
                    ComplaintEvent.event_type == ComplaintEventType.CALLED.value)
            .order_by(ComplaintEvent.created_at.asc())
            .all()
        )
    ]

    profile = (db.query(UserProfile)
                 .filter(UserProfile.user_id == current_user.id).first())
    reporter_name = (profile.full_name_en or profile.full_name_ta) if profile else "A resident"

    subject, body = build_letter(
        recipient=recipient,
        subject=subject,
        body=description,
        reporter_name=reporter_name,
        reporter_phone=current_user.phone_number,
        place_name=issue.location_name,
        latitude=issue.latitude,
        longitude=issue.longitude,
        photo_url=issue.photo_url,
        reference=str(issue.id)[:8].upper(),
        reported_on=_aware(issue.created_at).date() if issue.created_at else None,
        calls=calls,
    )

    # Serious complaints copy the next rung up from the start, so the
    # supervisor sees it at the same time as the officer rather than weeks
    # later. Routine ones do not — copying a Collector about a single bulb is
    # how a club stops being taken seriously.
    cc: list[str] = []
    if (issue.severity or "") == ComplaintSeverity.SERIOUS.value and authority is not None:
        higher = (
            db.query(Authority)
            .filter(Authority.organization_id == tenant_id,
                    Authority.department_id == authority.department_id,
                    Authority.rung > authority.rung,
                    Authority.is_active.is_(True))
            .order_by(Authority.rung.asc())
            .first()
        )
        if higher and (higher.email or "").strip():
            cc.append(higher.email.strip())

    issue.bcc_club = bool(payload.bcc_club)
    _record(db, issue, author=ComplaintAuthor.MEMBER, user_id=current_user.id,
            event_type=ComplaintEventType.DRAFTED,
            authority_id=(authority.id if authority else None),
            authority_label=recipient.line)
    db.commit()

    bcc: list[str] = []
    if payload.bcc_club:
        from app.core.config import settings as _s
        club = (getattr(_s, "CLUB_COMPLAINT_BCC", "") or "").strip()
        if club:
            bcc.append(club)

    return DraftOut(
        to_email=recipient.email, to_label=recipient.line, cc=cc, bcc=bcc,
        subject=subject, body=body, ai_written=ai_written,
    )
