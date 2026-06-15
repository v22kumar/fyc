from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.issue import PublicIssue, IssueStatus, VALID_TRANSITIONS
from app.models.user import User
from app.models.audit import AuditLog
from app.schemas.issue import IssueCreate, IssueStatusUpdate, IssueOut
from app.dependencies import get_current_user, RoleChecker, get_current_token_payload
from app.middleware.tenant import get_current_tenant_id

router = APIRouter(prefix="/issues", tags=["Public Issues"])

require_staff = RoleChecker(["VOLUNTEER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

@router.post("", response_model=IssueOut, status_code=status.HTTP_201_CREATED)
def submit_issue(
    payload: IssueCreate,
    request: Request,
    db: Session = Depends(get_db),
    authorization: Optional[str] = None
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
    auth_header = request.headers.get("Authorization")
    if auth_header:
        try:
            from app.core.security import decode_token
            parts = auth_header.split()
            if len(parts) == 2 and parts[0].lower() == "bearer":
                payload_token = decode_token(parts[1])
                reported_by_user_id = UUID(payload_token["sub"])
        except Exception:
            pass  # Anonymous submission if token invalid

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
        status=IssueStatus.NEW
    )
    db.add(issue)
    db.commit()
    db.refresh(issue)
    return issue

@router.get("", response_model=List[IssueOut])
def list_issues(
    issue_status: Optional[IssueStatus] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """List issues scoped to current tenant. Supports filtering by status and category."""
    tenant_id = get_current_tenant_id()
    query = db.query(PublicIssue)
    if tenant_id:
        query = query.filter(PublicIssue.organization_id == tenant_id)
    if issue_status:
        query = query.filter(PublicIssue.status == issue_status)
    if category:
        query = query.filter(PublicIssue.category == category.upper())
    return query.order_by(PublicIssue.created_at.desc()).all()

@router.get("/{issue_id}", response_model=IssueOut)
def get_issue(issue_id: UUID, db: Session = Depends(get_db)):
    """Get a single issue by ID."""
    issue = db.query(PublicIssue).filter(PublicIssue.id == issue_id).first()
    if not issue:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")
    return issue

@router.patch("/{issue_id}/status", response_model=IssueOut)
def update_issue_status(
    issue_id: UUID,
    payload: IssueStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff)
):
    """
    Transition an issue through the state machine.
    Volunteers can move to UNDER_REVIEW/RESOLVED; Admins/Executives control full lifecycle.
    """
    issue = db.query(PublicIssue).filter(PublicIssue.id == issue_id).first()
    if not issue:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")

    current_status = issue.status
    new_status = payload.status

    # Enforce state machine transitions
    allowed = VALID_TRANSITIONS.get(current_status, set())
    if new_status not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid transition from '{current_status}' to '{new_status}'. "
                   f"Allowed: {[s.value for s in allowed]}"
        )

    # Volunteers can only move to UNDER_REVIEW or RESOLVED on their own assigned issues
    if current_user.role == "VOLUNTEER":
        if new_status not in {IssueStatus.UNDER_REVIEW, IssueStatus.RESOLVED}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Volunteers may only update to UNDER_REVIEW or RESOLVED"
            )
        if issue.assigned_volunteer_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only update issues assigned to you"
            )

    old_status = issue.status.value if hasattr(issue.status, 'value') else str(issue.status)
    issue.status = new_status

    if payload.assigned_volunteer_id:
        issue.assigned_volunteer_id = payload.assigned_volunteer_id
    if payload.verification_photo_url:
        issue.verification_photo_url = payload.verification_photo_url

    # Audit log
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
    return issue
