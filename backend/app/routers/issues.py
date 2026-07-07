from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Request
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.issue import PublicIssue, IssueStatus, IssueEmailLog
from app.models.user import User
from app.models.audit import AuditLog
from app.schemas.issue import IssueCreate, IssueStatusUpdate, IssueOut, IssueStats, IssueEmailCreate, IssueEmailOut
from app.dependencies import get_current_user, RoleChecker, get_current_token_payload
from app.middleware.tenant import get_current_tenant_id, require_tenant_id
from app.services.notifications import notify_issue_assigned, notify_issue_resolved

router = APIRouter(prefix="/issues", tags=["Public Issues"])

require_staff = RoleChecker(["VOLUNTEER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

# Category → department label mapping (used in notifications)
_DEPT_MAP = {
    "ROAD_TRAFFIC": "Traffic Police / PWD",
    "POWER_CUT": "TNEB",
    "WATER":        "Water Supply Board",
    "STREET_LIGHT": "Electricity Board / Municipality",
    "GARBAGE":      "Sanitation Department",
    "SAFETY":       "Police / Fire & Rescue",
    "OTHER":        "General Administration",
}


@router.get("/stats", response_model=IssueStats)
def get_issue_stats(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Public stats for the home screen header — no auth required."""
    base = db.query(PublicIssue).filter(PublicIssue.organization_id == tenant_id)
    total = base.count()
    resolved = base.filter(
        PublicIssue.status.in_([IssueStatus.RESOLVED, IssueStatus.CLOSED])
    ).count()
    resolution_rate = round(resolved * 100 / total) if total else 0

    # Avg days from created_at to updated_at for resolved issues
    resolved_q = base.filter(
        PublicIssue.status.in_([IssueStatus.RESOLVED, IssueStatus.CLOSED])
    ).all()
    if resolved_q:
        total_days = sum(
            (i.updated_at - i.created_at).total_seconds() / 86400
            for i in resolved_q
        )
        avg_days = round(total_days / len(resolved_q), 1)
    else:
        avg_days = 0.0

    # "Active citizens" = distinct reporters (rough proxy)
    active = (
        db.query(func.count(func.distinct(PublicIssue.reported_by_user_id)))
        .filter(
            PublicIssue.organization_id == tenant_id,
            PublicIssue.reported_by_user_id.isnot(None),
        )
        .scalar()
        or 0
    )

    return IssueStats(
        total=total,
        resolved=resolved,
        resolution_rate=resolution_rate,
        avg_response_days=avg_days,
        active_citizens=active,
    )


@router.post("", response_model=IssueOut, status_code=status.HTTP_201_CREATED)
def submit_issue(
    payload: IssueCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Submit a public issue. Can be called anonymously (no auth required).
    If a valid token is present, the issue is linked to the submitting user.
    """
    tenant_id = get_current_tenant_id()
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Organization-ID header is required to submit an issue"
        )

    # Attempt to extract user from token (optional auth)
    reported_by_user_id = None
    reporter_fcm_token = None
    auth_header = request.headers.get("Authorization")
    if auth_header:
        try:
            from app.core.security import decode_token
            parts = auth_header.split()
            if len(parts) == 2 and parts[0].lower() == "bearer":
                payload_token = decode_token(parts[1])
                uid = UUID(payload_token["sub"])
                reported_by_user_id = uid
                user = db.query(User).filter(User.id == uid).first()
                if user:
                    reporter_fcm_token = getattr(user, "fcm_token", None)
        except Exception:
            pass

    issue = PublicIssue(
        organization_id=tenant_id,
        reported_by_user_id=reported_by_user_id,
        category=payload.category,
        description_ta=payload.description_ta,
        description_en=payload.description_en,
        latitude=float(payload.latitude),
        longitude=float(payload.longitude),
        geography_id=payload.geography_id,
        photo_url=payload.photo_url,
        is_emergency=payload.is_emergency,
        status=IssueStatus.NEW,
    )
    db.add(issue)
    db.commit()
    db.refresh(issue)

    # Notify reporter: issue received
    if reporter_fcm_token:
        try:
            dept = _DEPT_MAP.get(payload.category.value if hasattr(payload.category, 'value') else payload.category, "the relevant department")
            notify_issue_assigned(
                fcm_token=reporter_fcm_token,
                issue_id=str(issue.id),
                category=dept,
            )
        except Exception:
            pass  # Non-critical

    return issue


@router.get("", response_model=List[IssueOut])
def list_issues(
    issue_status: Optional[IssueStatus] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """List issues scoped to current tenant. Supports filtering by status and category."""
    query = db.query(PublicIssue).filter(PublicIssue.organization_id == tenant_id)
    if issue_status:
        query = query.filter(PublicIssue.status == issue_status)
    if category:
        query = query.filter(PublicIssue.category == category.upper())
    return query.order_by(PublicIssue.created_at.desc()).all()


@router.get("/{issue_id}", response_model=IssueOut)
def get_issue(
    issue_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Get a single issue by ID, scoped to current tenant."""
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == tenant_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")
    return issue


@router.patch("/{issue_id}/status", response_model=IssueOut)
def update_issue_status(
    issue_id: UUID,
    payload: IssueStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff),
):
    """
    Transition an issue through the state machine.
    Volunteers can move to UNDER_REVIEW/RESOLVED on their assigned issues.
    """
    # Tenant scoping: never allow mutating an issue outside the caller's org.
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == current_user.organization_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")

    # Volunteers may only act on issues assigned to them; staff/admins are unrestricted.
    if current_user.role == "VOLUNTEER" and issue.assigned_volunteer_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only update issues assigned to you.",
        )

    new_status = payload.status

    # Relaxed transition rules - community decides when it's resolved or in progress.
    old_status = issue.status.value if hasattr(issue.status, 'value') else str(issue.status)
    issue.status = new_status

    if payload.assigned_volunteer_id:
        issue.assigned_volunteer_id = payload.assigned_volunteer_id
    if payload.verification_photo_url:
        issue.verification_photo_url = payload.verification_photo_url

    log = AuditLog(
        organization_id=current_user.organization_id,
        user_id=current_user.id,
        action_type="STATUS_CHANGE_ISSUE",
        target_table="public_issues",
        target_id=issue_id,
        old_values={"status": old_status},
        new_values={"status": new_status.value if hasattr(new_status, 'value') else str(new_status)}
    )
    db.add(log)
    db.commit()
    db.refresh(issue)

    # Notify reporter when issue is resolved
    if new_status in {IssueStatus.RESOLVED, IssueStatus.CLOSED} and issue.reported_by_user_id:
        try:
            reporter = db.query(User).filter(User.id == issue.reported_by_user_id).first()
            fcm = getattr(reporter, "fcm_token", None) if reporter else None
            if fcm:
                notify_issue_resolved(fcm_token=fcm, issue_id=str(issue.id))
        except Exception:
            pass

    return issue


class IssueAssignRequest(BaseModel):
    volunteer_id: UUID


@router.patch("/{issue_id}/assign", response_model=IssueOut)
def assign_issue_volunteer(
    issue_id: UUID,
    payload: IssueAssignRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive),
):
    """
    Assign a volunteer to an issue (Executive Member, Admin, Super Admin only).
    Automatically transitions status from NEW -> ASSIGNED.
    """
    tenant_id = get_current_tenant_id()
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == tenant_id
    ).first()
    if not issue:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")

    old_values = {
        "assigned_volunteer_id": str(issue.assigned_volunteer_id) if issue.assigned_volunteer_id else None,
        "status": issue.status.value if hasattr(issue.status, "value") else str(issue.status),
    }

    issue.assigned_volunteer_id = payload.volunteer_id
    if issue.status == IssueStatus.NEW:
        issue.status = IssueStatus.ASSIGNED

    log = AuditLog(
        organization_id=current_user.organization_id,
        user_id=current_user.id,
        action_type="ISSUE_ASSIGNED",
        target_table="public_issues",
        target_id=issue_id,
        old_values=old_values,
        new_values={
            "assigned_volunteer_id": str(payload.volunteer_id),
            "status": issue.status.value if hasattr(issue.status, "value") else str(issue.status),
        },
    )
    db.add(log)
    db.commit()
    db.refresh(issue)

    # Notify assigned volunteer
    try:
        volunteer = db.query(User).filter(User.id == payload.volunteer_id).first()
        fcm = getattr(volunteer, "fcm_token", None) if volunteer else None
        if fcm:
            dept = _DEPT_MAP.get(
                issue.category.value if hasattr(issue.category, 'value') else str(issue.category),
                "General"
            )
            notify_issue_assigned(fcm_token=fcm, issue_id=str(issue.id), category=dept)
    except Exception:
        pass

    return issue

@router.post("/{issue_id}/email", response_model=IssueEmailOut)
def log_issue_email(
    issue_id: UUID,
    payload: Optional[IssueEmailCreate] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Log and simulate sending an email to a concerned authority about an issue.
    The body is optional — a one-tap "log email sent" records sensible defaults.
    """
    payload = payload or IssueEmailCreate()
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id,
        PublicIssue.organization_id == current_user.organization_id,
    ).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")

    dept = _DEPT_MAP.get(
        issue.category.value if hasattr(issue.category, "value") else str(issue.category),
        "Concerned Authority",
    )
    email_log = IssueEmailLog(
        organization_id=current_user.organization_id,
        issue_id=issue_id,
        sent_by_user_id=current_user.id,
        authority_email=payload.authority_email or "authority@local.gov",
        subject=payload.subject or f"Public issue forwarded to {dept}",
        body=payload.body or "An email regarding this issue was sent to the concerned authority.",
    )
    db.add(email_log)
    db.commit()
    db.refresh(email_log)
    
    # In a real app, integrate SES/SendGrid here to dispatch the email.
    
    return email_log

@router.get("/{issue_id}/email", response_model=List[IssueEmailOut])
def list_issue_emails(
    issue_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Get the history of emails sent for an issue.
    """
    return db.query(IssueEmailLog).filter(
        IssueEmailLog.issue_id == issue_id,
        IssueEmailLog.organization_id == tenant_id
    ).order_by(IssueEmailLog.created_at.desc()).all()
