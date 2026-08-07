"""The rebuilt complaint workflow: one description, a reviewed gate, a ladder.

Its own module, and its own router, for a reason that is not tidiness.
`issues.py` declares `GET /issues/{issue_id}` early, and FastAPI matches routes
in declaration order — so `GET /issues/queue` appended to the end of that file
never runs. The request matches `{issue_id}`, fails to parse "queue" as a UUID,
and returns 422 with no clue as to why.

This router is included *before* the legacy one in main.py, so its literal paths
win. The old endpoints keep working untouched: the app in people's hands calls
them, and it gets updated on its own schedule rather than in lockstep with a
backend deploy.
"""
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import RoleChecker, get_current_user
from app.models.civic import Department
from app.models.issue import IssueStatus, PublicIssue
from app.models.tenant import Organization
from app.models.user import User
from app.routers.issues import _geocode_and_store
from app.schemas.issue import (
    DispatchIn, DispatchOut, EscalationOut, IssueCreateV2, IssueOut, QueueItemOut,
    QueueOut, ReviewIn, RouteOut, RouteRungOut,
)
from app.services import complaint_workflow as workflow
from app.services.issue_lifecycle import OURS, THEIRS

router = APIRouter(prefix="/issues", tags=["Public Issues"])

require_staff = RoleChecker(["VOLUNTEER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


def _club_name(db: Session, tenant_id: UUID) -> str:
    org = db.get(Organization, tenant_id)
    return (org.name_en if org else None) or "Friends Youth Club"


def _route_out(ladder) -> RouteOut:
    return RouteOut(
        category=ladder.category,
        scope=ladder.scope,
        local_body_type=ladder.jurisdiction.local_body_type.value,
        jurisdiction_confidence=ladder.jurisdiction.confidence.value,
        jurisdiction_reason=ladder.jurisdiction.reason,
        needs_human_check=ladder.jurisdiction.needs_human_check,
        rungs=[
            RouteRungOut(
                position=r.position,
                department_code=r.department.code,
                department_name_en=r.department.name_en,
                department_name_ta=r.department.name_ta,
                designation_en=r.authority.designation_en if r.authority else None,
                designation_ta=r.authority.designation_ta if r.authority else None,
                rung=r.rung,
                wait_days=r.wait_days,
                reachable=r.reachable,
            )
            for r in ladder.rungs
        ],
        fallback_portal=ladder.fallback.portal_url if ladder.fallback else None,
        fallback_helpline=ladder.fallback.helpline if ladder.fallback else None,
    )


@router.post("/v2", response_model=IssueOut, status_code=status.HTTP_201_CREATED)
def submit_issue_v2(
    payload: IssueCreateV2,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Report something, having written about it once.

    Both description columns are still populated, because the letter to an
    officer is in English and the app displays Tamil — but the person is asked
    in their own language and nothing else. Until translation is wired in, the
    text they wrote is used for both and `description_lang` records which one
    came from a human, so nothing is ever passed off as a translation that is
    not one.
    """
    tenant_id = current_user.organization_id
    text = payload.description.strip()
    lang = (payload.description_lang or "ta").lower()

    issue = PublicIssue(
        organization_id=tenant_id,
        reported_by_user_id=current_user.id,
        category=payload.category,
        description_ta=text,
        description_en=text,
        description_lang=lang,
        latitude=payload.latitude,
        longitude=payload.longitude,
        geography_id=payload.geography_id,
        photo_url=payload.photo_url,
        is_emergency=payload.is_emergency,
        status=IssueStatus.NEW,
    )
    db.add(issue)
    db.commit()
    db.refresh(issue)

    # Work out the jurisdiction now, while the reporter's context is at hand, so
    # a reviewer opening the queue sees the route rather than waiting for it.
    workflow.remember_jurisdiction(db, issue)
    db.commit()
    db.refresh(issue)

    background_tasks.add_task(
        _geocode_and_store, issue.id, float(issue.latitude), float(issue.longitude)
    )
    return issue


@router.get("/queue", response_model=QueueOut, dependencies=[Depends(require_staff)])
def review_queue(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The reviewer's screen: waiting on us, waiting on them, overdue.

    A queue rather than a list. The old app showed every issue in one stream
    ordered by date, which answers no question a reviewer actually has.
    """
    tenant_id = current_user.organization_id
    now = datetime.now(timezone.utc)
    rows = (
        db.query(PublicIssue)
        .filter(
            PublicIssue.organization_id == tenant_id,
            PublicIssue.status.in_(list(OURS) + list(THEIRS)),
        )
        .order_by(PublicIssue.created_at.asc())
        .all()
    )

    def item(issue: PublicIssue, bucket: str) -> QueueItemOut:
        overdue_days = None
        if issue.next_action_due_at:
            due = issue.next_action_due_at
            if due.tzinfo is None:
                due = due.replace(tzinfo=timezone.utc)
            if due <= now:
                overdue_days = max(0, (now - due).days)
        return QueueItemOut(
            id=issue.id,
            category=str(issue.category),
            status=issue.status.value,
            description=issue.description_ta or issue.description_en or "",
            created_at=issue.created_at,
            bucket=bucket,
            current_position=issue.current_position,
            next_action_due_at=issue.next_action_due_at,
            days_overdue=overdue_days,
        )

    ours, theirs, overdue = [], [], []
    for issue in rows:
        if issue.status in OURS:
            ours.append(item(issue, "waiting_on_us"))
            continue
        due = issue.next_action_due_at
        if due is not None:
            if due.tzinfo is None:
                due = due.replace(tzinfo=timezone.utc)
            if due <= now:
                overdue.append(item(issue, "overdue"))
                continue
        theirs.append(item(issue, "waiting_on_them"))

    return QueueOut(waiting_on_us=ours, waiting_on_them=theirs, overdue=overdue)


@router.get("/{issue_id}/route", response_model=RouteOut)
def issue_route(
    issue_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Where this complaint would go, and where it would go next after that.

    Readable before anything is sent, so the person who reported it can see the
    ladder rather than being told "submitted" and hearing nothing again.
    """
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == current_user.organization_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")
    return _route_out(workflow.route_for(db, issue))


@router.post("/{issue_id}/review", response_model=IssueOut, dependencies=[Depends(require_staff)])
def review_issue(
    issue_id: UUID,
    payload: ReviewIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The gate. Nothing reaches a government office without passing through it."""
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == current_user.organization_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")

    try:
        if payload.approve:
            if payload.department_code_override:
                exists = db.query(Department).filter(
                    Department.organization_id == issue.organization_id,
                    Department.code == payload.department_code_override,
                ).first()
                if not exists:
                    raise HTTPException(
                        status_code=400,
                        detail=f"No department with code {payload.department_code_override}",
                    )
                issue.department_code_override = payload.department_code_override
            workflow.approve(db, issue, current_user, payload.reason)
        else:
            workflow.reject(db, issue, current_user, payload.reason or "")
    except workflow.NotReady as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:  # IllegalTransition and anything else with a message
        raise HTTPException(status_code=409, detail=str(e))

    db.commit()
    db.refresh(issue)
    return issue


@router.post("/{issue_id}/dispatch", response_model=DispatchOut, dependencies=[Depends(require_staff)])
def dispatch_issue(
    issue_id: UUID,
    payload: Optional[DispatchIn] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send the letter to the next office on the ladder.

    The same endpoint sends the first letter and every escalation, because they
    are the same action at different heights — which is what stops an escalation
    from being recorded differently from an original.

    A human calls this. The clock never does.
    """
    payload = payload or DispatchIn()
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == current_user.organization_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")

    try:
        result = workflow.dispatch(
            db, issue, current_user,
            club_name=_club_name(db, issue.organization_id),
            subject=payload.subject,
            body=payload.body,
            reply_to=current_user.email,
        )
    except workflow.NotReady as e:
        raise HTTPException(status_code=409, detail=str(e))

    db.commit()
    return DispatchOut(
        sent=result.sent,
        position=result.rung.position if result.rung else None,
        sent_to=result.rung.label if result.rung else None,
        due_at=result.escalation.due_at if result.escalation else None,
        fallback_portal=result.fallback_portal,
        fallback_helpline=result.fallback_helpline,
    )


@router.get("/{issue_id}/history", response_model=List[EscalationOut])
def issue_history(
    issue_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Every rung this complaint has been to — who, when, and what came back."""
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == current_user.organization_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")
    return workflow.history(db, issue)
