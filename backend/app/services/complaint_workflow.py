"""The journey of one complaint, from a photograph to an officer.

Everything a complaint does — being reviewed, being sent, climbing a rung —
happens here rather than inside a route handler. The old `forward_issue`
endpoint held the whole workflow in its body: resolve a department, draft with
AI, send, log, mutate status. That is why it could only ever do it once.

## The two rules this file exists to keep

**A person always presses send.** `next_due` reports which complaints have run
out their wait. It does not escalate them. A machine that mails a District
Collector unattended will one day mail a District Collector about a duplicate
report of a puddle, and the club's name is on that letter.

**The club reads it first.** `approve` is the only door from NEW to sent, and it
records who opened it.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.civic import Authority, EscalationOutcome, IssueEscalation
from app.models.issue import IssueEmailLog, IssueStatus, PublicIssue
from app.models.user import User
from app.services import mailer
from app.services.complaint_routing import Ladder, Rung, build_ladder
from app.services.issue_lifecycle import THEIRS, check
from app.services.jurisdiction import Confidence, Jurisdiction, resolve

logger = logging.getLogger(__name__)


class NotReady(RuntimeError):
    """The complaint cannot take this step yet, for a reason worth showing."""


def _now() -> datetime:
    return datetime.now(timezone.utc)


def route_for(db: Session, issue: PublicIssue) -> Ladder:
    """The ladder this complaint is on.

    Uses the jurisdiction recorded on the issue once one exists, so a complaint
    already in flight keeps the route it was sent along even if the geography
    tree is reclassified underneath it.
    """
    if issue.local_body_type:
        from app.models.civic import LocalBodyType

        known = Jurisdiction(
            local_body_type=LocalBodyType(issue.local_body_type),
            confidence=Confidence(issue.jurisdiction_confidence or Confidence.GUESSED.value),
            geography_id=issue.geography_id,
            reason=issue.jurisdiction_reason or "",
        )
    else:
        reporter = (
            db.get(User, issue.reported_by_user_id) if issue.reported_by_user_id else None
        )
        known = resolve(
            db,
            geography_id=issue.geography_id,
            reporter_geography_id=getattr(reporter, "geography_id", None),
        )

    ladder = build_ladder(
        db, issue.organization_id, str(issue.category), known
    )
    if not issue.department_code_override:
        return ladder
    return _pin_to_department(db, issue, ladder, issue.department_code_override)


#: How long a substituted office gets. The department the reviewer named has its
#: own chain but no routing rule of its own, so there are no per-rung waits to
#: read; ten days is the middle of what the seeded ladders use.
_OVERRIDE_WAIT_DAYS = 10

#: Rungs kept from the original ladder when a department is substituted. A
#: highway complaint still escalates to the Collector and then the state — the
#: local body drops out, the district does not.
_SHARED_TAIL = ("COLLECTORATE", "CM_HELPLINE", "CPGRAMS")


def _pin_to_department(
    db: Session, issue: PublicIssue, ladder: Ladder, code: str
) -> Ladder:
    """Rebuild the route around a department the reviewer named.

    Road class cannot be derived from a coordinate — a state highway and a
    corporation street look identical to GPS — so a reviewer who recognises the
    road switches the route.

    Filtering the existing ladder cannot do this, and quietly did nothing when
    it was tried: the urban ROAD ladder contains the local body, the Collector
    and the CM Helpline, and no Highways rung at all. Filtering left an empty
    list, the code fell back to the unfiltered ladder, and the complaint went to
    the Assistant Engineer exactly as if nothing had been pinned.

    So the department's own offices are read directly and become the lower
    rungs, with the district and state tail of the original ladder kept on the
    end so the complaint still cannot run out of places to go.
    """
    from app.models.civic import Department as _Dept

    dept = (
        db.query(_Dept)
        .filter(_Dept.organization_id == issue.organization_id, _Dept.code == code)
        .first()
    )
    if dept is None:
        return ladder

    offices = (
        db.query(Authority)
        .filter(
            Authority.organization_id == issue.organization_id,
            Authority.department_id == dept.id,
            Authority.is_active.is_(True),
        )
        .order_by(Authority.rung.asc())
        .all()
    )
    if not offices:
        return ladder

    rungs: list[Rung] = [
        Rung(
            position=position,
            department=dept,
            authority=office,
            wait_days=_OVERRIDE_WAIT_DAYS,
            rung=office.rung,
        )
        for position, office in enumerate(offices, start=1)
    ]
    tail = [r for r in ladder.rungs if r.department.code in _SHARED_TAIL]
    for offset, rung in enumerate(tail, start=len(rungs) + 1):
        rungs.append(Rung(
            position=offset,
            department=rung.department,
            authority=rung.authority,
            wait_days=rung.wait_days,
            rung=rung.rung,
        ))

    return Ladder(
        category=ladder.category,
        scope=ladder.scope,
        jurisdiction=ladder.jurisdiction,
        rungs=rungs,
    )


def remember_jurisdiction(db: Session, issue: PublicIssue) -> Jurisdiction:
    """Work out where this happened and write it onto the complaint."""
    reporter = (
        db.get(User, issue.reported_by_user_id) if issue.reported_by_user_id else None
    )
    found = resolve(
        db,
        geography_id=issue.geography_id,
        reporter_geography_id=getattr(reporter, "geography_id", None),
    )
    issue.local_body_type = found.local_body_type.value
    issue.jurisdiction_confidence = found.confidence.value
    issue.jurisdiction_reason = found.reason
    return found


def approve(db: Session, issue: PublicIssue, reviewer: User, note: Optional[str] = None) -> None:
    """A club member has read it and it is worth an officer's time.

    Approving does not send anything. It opens the door and stops there, so the
    reviewer can look at the drafted letter before it leaves.
    """
    check(issue.status, IssueStatus.ASSIGNED)
    remember_jurisdiction(db, issue)
    issue.status = IssueStatus.ASSIGNED
    issue.reviewed_at = _now()
    issue.reviewed_by_user_id = reviewer.id
    issue.review_note = note
    issue.current_position = 0


def reject(db: Session, issue: PublicIssue, reviewer: User, reason: str) -> None:
    """Declined, with a reason the reporter will read.

    The reason is required. A rejection with none teaches the person only that
    reporting is pointless, and they are the club's supply of reports.
    """
    if not (reason or "").strip():
        raise NotReady("a rejection needs a reason the reporter can read")
    check(issue.status, IssueStatus.REJECTED)
    issue.status = IssueStatus.REJECTED
    issue.reviewed_at = _now()
    issue.reviewed_by_user_id = reviewer.id
    issue.review_note = reason.strip()


def next_rung(ladder: Ladder, after_position: Optional[int]) -> Optional[Rung]:
    """The next office that can actually receive a letter.

    Walks past rungs with no address rather than stopping at them: a club that
    has the Commissioner's email but not the ward councillor's should still be
    able to file.
    """
    floor = after_position or 0
    return next((r for r in ladder.rungs if r.position > floor and r.reachable), None)


@dataclass
class Dispatch:
    """What happened when we tried to send."""

    sent: bool
    rung: Optional[Rung]
    escalation: Optional[IssueEscalation]
    #: Where to point the citizen when nothing could be sent.
    fallback_portal: Optional[str] = None
    fallback_helpline: Optional[str] = None


def compose(issue: PublicIssue, rung: Rung, club_name: str) -> tuple[str, str]:
    """The letter. Plain, complete, and quotable on a phone call."""
    where = issue.location_name or f"GPS {issue.latitude}, {issue.longitude}"
    maps = f"https://maps.google.com/?q={issue.latitude},{issue.longitude}"
    salutation = rung.authority.designation_en if rung.authority else "Sir/Madam"
    subject = f"Civic complaint — {rung.department.name_en} — ref {str(issue.id)[:8]}"
    body = (
        f"To the {salutation},\n"
        f"{rung.department.name_en}\n\n"
        f"{issue.description_en or issue.description_ta}\n\n"
        f"Location: {where}\n"
        f"Map: {maps}\n"
        + (f"Photograph: {issue.photo_url}\n" if issue.photo_url else "")
        + f"\nReference: {issue.id}\n"
        f"Reported by a resident and verified by {club_name}.\n"
    )
    return subject, body


def dispatch(
    db: Session,
    issue: PublicIssue,
    sender: User,
    *,
    club_name: str,
    subject: Optional[str] = None,
    body: Optional[str] = None,
    reply_to: Optional[str] = None,
) -> Dispatch:
    """Send the complaint to the next rung, and record that we did.

    Called for the first letter and for every escalation — they are the same
    action at different heights, and writing them once means an escalation can
    never be logged differently from an original.
    """
    if issue.status not in (IssueStatus.ASSIGNED, IssueStatus.UNDER_REVIEW, IssueStatus.ESCALATED):
        raise NotReady("this complaint has not been approved by a reviewer yet")

    ladder = route_for(db, issue)
    rung = next_rung(ladder, issue.current_position)
    if rung is None:
        fallback = ladder.fallback
        return Dispatch(
            sent=False,
            rung=None,
            escalation=None,
            fallback_portal=fallback.portal_url if fallback else None,
            fallback_helpline=fallback.helpline if fallback else None,
        )

    final_subject, final_body = compose(issue, rung, club_name)
    if subject:
        final_subject = subject
    if body:
        final_body = body

    cc = [
        e.strip()
        for e in ((rung.authority.cc_emails or "") if rung.authority else "").split(",")
        if e.strip()
    ]
    to = rung.authority.email if rung.authority else ""
    # The club is the petitioner: the letter goes out from the club's own
    # mailbox so replies come back to one place and a track record builds up
    # with the same offices over time.
    sent = mailer.send_email(to, final_subject, final_body, cc=cc, reply_to=reply_to)

    escalation = IssueEscalation(
        organization_id=issue.organization_id,
        issue_id=issue.id,
        position=rung.position,
        authority_id=rung.authority.id if rung.authority else None,
        sent_to_label=rung.label,
        sent_to_email=to or None,
        dispatched_at=_now() if sent else None,
        due_at=(_now() + timedelta(days=rung.wait_days)) if sent else None,
        outcome=(
            EscalationOutcome.PENDING.value if sent else EscalationOutcome.UNDELIVERABLE.value
        ),
        dispatched_by_user_id=sender.id,
    )
    db.add(escalation)

    # Kept as well as the escalation row: IssueEmailLog is what the existing
    # app already reads, and losing that history would break the issue screen.
    db.add(IssueEmailLog(
        organization_id=issue.organization_id,
        issue_id=issue.id,
        sent_by_user_id=sender.id,
        authority_email=to or "not-configured",
        subject=final_subject,
        body=final_body,
    ))

    if sent:
        issue.current_position = rung.position
        issue.next_action_due_at = escalation.due_at
        target = (
            IssueStatus.UNDER_REVIEW
            if issue.status == IssueStatus.ASSIGNED
            else IssueStatus.ESCALATED
        )
        check(issue.status, target)
        issue.status = target

    return Dispatch(sent=sent, rung=rung, escalation=escalation)


def next_due(db: Session, organization_id: UUID, *, now: Optional[datetime] = None) -> list[PublicIssue]:
    """Complaints whose current office has run out its wait.

    This is a *reading*, not an action. What it feeds is a line in the club's
    queue that says "14 days, no reply from the Commissioner — send to the
    Collector?" with the next letter already drafted underneath it.
    """
    cutoff = now or _now()
    return (
        db.query(PublicIssue)
        .filter(
            PublicIssue.organization_id == organization_id,
            PublicIssue.status.in_(list(THEIRS)),
            PublicIssue.next_action_due_at.isnot(None),
            PublicIssue.next_action_due_at <= cutoff,
            or_(PublicIssue.deleted_at.is_(None), PublicIssue.deleted_at == None),  # noqa: E711
        )
        .order_by(PublicIssue.next_action_due_at.asc())
        .all()
    )


def history(db: Session, issue: PublicIssue) -> list[IssueEscalation]:
    """Every rung this complaint has been to, oldest first.

    Six weeks later, "who did we tell, and when, and what did they say" has an
    answer, and a citizen asking the club can be given a straight one.
    """
    return (
        db.query(IssueEscalation)
        .filter(IssueEscalation.issue_id == issue.id)
        .order_by(IssueEscalation.position.asc())
        .all()
    )
