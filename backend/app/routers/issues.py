from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Request, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db, SessionLocal
from app.models.issue import PublicIssue, IssueStatus, IssueEmailLog, ComplaintDepartment
from app.models.user import User
from app.models.audit import AuditLog
from app.schemas.issue import (
    IssueCreate, IssueStatusUpdate, IssueOut, IssueStats, IssueEmailCreate, IssueEmailOut,
    DepartmentOut, DepartmentUpsert, DepartmentPatch,
    ComplaintDraftIn, ComplaintDraftOut, ForwardIn, ForwardOut,
)
from app.dependencies import get_current_user, RoleChecker, get_current_token_payload
from app.middleware.tenant import get_current_tenant_id, require_tenant_id
from app.services.notifications import notify_issue_assigned, notify_issue_resolved
from app.services.geocoding import reverse_geocode
from app.services import mailer
from app.services.ai_service import AIService

router = APIRouter(prefix="/issues", tags=["Public Issues"])

require_staff = RoleChecker(["VOLUNTEER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


# ── Complaint routing directory ──────────────────────────────────────────────
# Seeded with the REAL public grievance channels for Kanyakumari / Tamil Nadu
# (TN CM Helpline 1100, TANGEDCO 1912, TWAD, Police 100, TN health 104). Emails
# are intentionally left blank — admins fill in the actual local officer email so
# complaints dispatch by SMTP; until then the app shows the phone/portal so a
# citizen is never left with a dead end. (No official emails are fabricated.)
_DEFAULT_DEPARTMENTS = [
    # category, name_en, name_ta, phone, helpline, portal_url
    ("ROAD_TRAFFIC", "Highways Department / PWD", "நெடுஞ்சாலைத் துறை / பொதுப்பணித் துறை", None, "1100", "https://kanniyakumari.nic.in/department/highways-department/"),
    ("POWER_CUT", "TANGEDCO (Electricity Board)", "மின்சார வாரியம் (TANGEDCO)", "1912", "1912", "https://www.tnebnet.org/"),
    ("WATER", "TWAD / Municipal Water Supply", "குடிநீர் வடிகால் வாரியம் (TWAD)", "9445802145", "1100", "https://twadboard.tn.gov.in/"),
    ("SANITATION", "Municipality — Sanitation", "நகராட்சி — துப்புரவுத் துறை", None, "1100", "https://kanniyakumari.nic.in/"),
    ("STREET_LIGHT", "Municipality / TANGEDCO", "நகராட்சி / மின்வாரியம்", None, "1100", None),
    ("PUBLIC_HEALTH", "Public Health Department", "பொது சுகாதாரத் துறை", "104", "104", None),
    ("ENCROACHMENT", "Municipality / Revenue", "நகராட்சி / வருவாய்த் துறை", None, "1100", None),
    ("SAFETY", "Police", "காவல் துறை", "100", "100", None),
    ("OTHER", "District Collectorate — CM Helpline", "மாவட்ட ஆட்சியர் — முதலமைச்சர் உதவி மையம்", None, "1100", "https://kanniyakumari.nic.in/"),
]


def _seed_departments(db: Session, tenant_id: UUID) -> None:
    for cat, en, ta, phone, helpline, portal in _DEFAULT_DEPARTMENTS:
        db.add(ComplaintDepartment(
            organization_id=tenant_id, category=cat, name_en=en, name_ta=ta,
            phone=phone, helpline=helpline, portal_url=portal, is_active=True,
        ))
    db.commit()


def _resolve_department(db: Session, tenant_id: UUID, category: str) -> Optional[ComplaintDepartment]:
    """Find the department for a category, seeding org defaults on first use and
    falling back to the OTHER (Collectorate/CM-Helpline) entry."""
    existing = db.query(ComplaintDepartment).filter(
        ComplaintDepartment.organization_id == tenant_id
    ).count()
    if existing == 0:
        try:
            _seed_departments(db, tenant_id)
        except Exception:
            db.rollback()

    def _pick(cat):
        return (
            db.query(ComplaintDepartment)
            .filter(
                ComplaintDepartment.organization_id == tenant_id,
                ComplaintDepartment.category == cat,
                ComplaintDepartment.is_active == True,  # noqa: E712
            )
            .first()
        )

    return _pick(category) or _pick("OTHER")


def _geocode_and_store(issue_id: UUID, lat: float, lng: float) -> None:
    """Background: reverse-geocode and store the address (own DB session)."""
    name = reverse_geocode(lat, lng)
    if not name:
        return
    db = SessionLocal()
    try:
        iss = db.query(PublicIssue).filter(PublicIssue.id == issue_id).first()
        if iss and not iss.location_name:
            iss.location_name = name
            db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()

# Category → department label mapping (used in notifications)
_DEPT_MAP = {
    "ROAD_TRAFFIC": "Traffic Police / PWD",
    "ROAD":         "Traffic Police / PWD",  # legacy alias (pre-v2.0 rows)
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
    background_tasks: BackgroundTasks,
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
        # Store the plain string value (column is String now, not an enum).
        category=payload.category.value,
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

    # Reverse-geocode the GPS into a readable address (best-effort, off the
    # request path) so the complaint + department email carry a real location.
    background_tasks.add_task(
        _geocode_and_store, issue.id, float(payload.latitude), float(payload.longitude)
    )

    # Notify reporter: issue received
    if reporter_fcm_token:
        try:
            dept = _DEPT_MAP.get(payload.category.value, "the relevant department")
            background_tasks.add_task(
                notify_issue_assigned,
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


@router.post("/draft", response_model=ComplaintDraftOut)
def draft_complaint(
    payload: ComplaintDraftIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Preview a well-worded, bilingual complaint for a category + location, with
    the resolved department — before it is submitted / forwarded."""
    location_name = None
    if payload.latitude is not None and payload.longitude is not None:
        location_name = reverse_geocode(payload.latitude, payload.longitude)
    dept = _resolve_department(db, tenant_id, payload.category.value)
    dept_label = dept.name_en if dept else "the concerned department"
    ai = AIService(db).draft_complaint(dept_label, payload.description, location_name, payload.is_emergency)
    if ai:
        return ComplaintDraftOut(
            subject=ai["subject"], body_en=ai["body_en"], body_ta=ai.get("body_ta"),
            location_name=location_name,
            department=DepartmentOut.model_validate(dept) if dept else None,
            ai_used=True,
        )
    # AI unavailable → echo the description so the flow still works.
    return ComplaintDraftOut(
        subject=f"Civic complaint — {dept_label}",
        body_en=payload.description, body_ta=None, location_name=location_name,
        department=DepartmentOut.model_validate(dept) if dept else None, ai_used=False,
    )


@router.get("/departments", response_model=List[DepartmentOut])
def list_departments(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """The complaint routing directory (seeded on first use)."""
    _resolve_department(db, tenant_id, "OTHER")  # ensures this org is seeded
    return (
        db.query(ComplaintDepartment)
        .filter(ComplaintDepartment.organization_id == tenant_id)
        .order_by(ComplaintDepartment.category)
        .all()
    )


@router.post("/departments", response_model=DepartmentOut, dependencies=[Depends(require_executive)])
def upsert_department(
    payload: DepartmentUpsert,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Admin: create or replace the department for a category (set the officer email)."""
    dept = (
        db.query(ComplaintDepartment)
        .filter(
            ComplaintDepartment.organization_id == tenant_id,
            ComplaintDepartment.category == payload.category,
        )
        .first()
    )
    if not dept:
        dept = ComplaintDepartment(organization_id=tenant_id, category=payload.category)
        db.add(dept)
    for f in ("name_en", "name_ta", "email", "cc_emails", "phone", "helpline", "portal_url", "is_active"):
        setattr(dept, f, getattr(payload, f))
    db.commit()
    db.refresh(dept)
    return dept


@router.patch("/departments/{dept_id}", response_model=DepartmentOut, dependencies=[Depends(require_executive)])
def patch_department(
    dept_id: UUID,
    payload: DepartmentPatch,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    dept = db.query(ComplaintDepartment).filter(
        ComplaintDepartment.id == dept_id,
        ComplaintDepartment.organization_id == tenant_id,
    ).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    for f, v in payload.model_dump(exclude_unset=True).items():
        setattr(dept, f, v)
    db.commit()
    db.refresh(dept)
    return dept


@router.post("/{issue_id}/forward", response_model=ForwardOut)
def forward_issue(
    issue_id: UUID,
    payload: Optional[ForwardIn] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Compose and DISPATCH the complaint email to the concerned department. AI-
    drafts the body unless one is supplied; attaches the address, a map link and
    the photo. When the department has no email configured yet, records the
    attempt and tells the app to surface the helpline/portal (never a dead end)."""
    payload = payload or ForwardIn()
    tenant_id = current_user.organization_id
    issue = db.query(PublicIssue).filter(
        PublicIssue.id == issue_id, PublicIssue.organization_id == tenant_id
    ).first()
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")

    category = issue.category.value if hasattr(issue.category, "value") else str(issue.category)
    dept = _resolve_department(db, tenant_id, category)
    dept_label = dept.name_en if dept else "the concerned department"

    if not issue.location_name:
        issue.location_name = reverse_geocode(float(issue.latitude), float(issue.longitude))
        if issue.location_name:
            db.commit()

    if payload.subject and payload.body:
        subject, body = payload.subject, payload.body
    else:
        ai = (
            AIService(db).draft_complaint(dept_label, issue.description_en, issue.location_name, bool(issue.is_emergency))
            if payload.use_ai else None
        )
        if ai:
            subject = ai["subject"]
            body = ai["body_en"] + (("\n\n— தமிழில் —\n" + ai["body_ta"]) if ai.get("body_ta") else "")
        else:
            subject = f"Civic complaint — {dept_label}"
            body = issue.description_en

    loc = issue.location_name or f"GPS {issue.latitude}, {issue.longitude}"
    maps = f"https://maps.google.com/?q={issue.latitude},{issue.longitude}"
    full_body = (
        f"{body}\n\n"
        f"Location: {loc}\n"
        f"Map: {maps}\n"
        + (f"Photo evidence: {issue.photo_url}\n" if issue.photo_url else "")
        + f"\nReference ID: {issue.id}\n"
        "Submitted via FYC Connect — Friends Youth Club, Nagercoil."
    )

    recipient = ((dept.email or "").strip() if dept else "")
    cc = [e.strip() for e in (((dept.cc_emails or "") if dept else "").split(",")) if e.strip()]
    sent = mailer.send_email(recipient, subject, full_body, cc=cc, reply_to=current_user.email) if recipient else False

    log = IssueEmailLog(
        organization_id=tenant_id,
        issue_id=issue.id,
        sent_by_user_id=current_user.id,
        authority_email=recipient or ((dept.portal_url or dept.helpline) if dept else None) or "not-configured",
        subject=subject,
        body=full_body,
    )
    db.add(log)
    if sent and issue.status == IssueStatus.NEW:
        issue.status = IssueStatus.UNDER_REVIEW
    db.commit()
    db.refresh(log)

    return ForwardOut(
        sent=sent,
        recipient=recipient or None,
        department=DepartmentOut.model_validate(dept) if dept else None,
        needs_manual=not sent,
        helpline=dept.helpline if dept else None,
        portal_url=dept.portal_url if dept else None,
        subject=subject,
        email_log_id=log.id,
    )


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
    background_tasks: BackgroundTasks,
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
                background_tasks.add_task(notify_issue_resolved, fcm_token=fcm, issue_id=str(issue.id))
        except Exception:
            pass

    return issue


class IssueAssignRequest(BaseModel):
    volunteer_id: UUID


@router.patch("/{issue_id}/assign", response_model=IssueOut)
def assign_issue_volunteer(
    issue_id: UUID,
    payload: IssueAssignRequest,
    background_tasks: BackgroundTasks,
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
            background_tasks.add_task(notify_issue_assigned, fcm_token=fcm, issue_id=str(issue.id), category=dept)
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
