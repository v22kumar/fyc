from decimal import Decimal
from typing import List, Optional
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.etag import etag_not_modified, set_etag
from app.models.event import Event, EventAttendance, EventRegistration
from app.models.user import User, VolunteerMetadata
from app.schemas.event import EventCreate, EventUpdate, EventOut, EventCheckinOut, EventCheckoutOut, EventRegistrationCreate, EventRegistrationOut, EventRegistrantsOut
from app.dependencies import get_current_user, get_current_user_optional, RoleChecker
from app.middleware.tenant import require_tenant_id
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/events", tags=["Events"])

require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_member = RoleChecker(["VOLUNTEER", "CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


def _attach_registration_counts(db: Session, events):
    """Attach a transient `registration_count` to each Event for EventOut."""
    if not events:
        return events
    ids = [e.id for e in events]
    rows = (
        db.query(EventRegistration.event_id, func.count(EventRegistration.id))
        .filter(EventRegistration.event_id.in_(ids))
        .group_by(EventRegistration.event_id)
        .all()
    )
    counts = {eid: c for eid, c in rows}
    for e in events:
        e.registration_count = counts.get(e.id, 0)
    return events

@router.post("", response_model=EventOut, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive)
):
    """Create a new event (Executive Member, Admin, or Super Admin)."""
    if payload.event_end <= payload.event_start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="event_end must be after event_start"
        )

    event = Event(
        organization_id=current_user.organization_id,
        title_ta=payload.title_ta,
        title_en=payload.title_en,
        description_ta=payload.description_ta,
        description_en=payload.description_en,
        event_start=payload.event_start,
        event_end=payload.event_end,
        banner_url=payload.banner_url,
        geography_id=payload.geography_id,
        is_published=payload.is_published,
        registration_enabled=payload.registration_enabled,
        registration_deadline=payload.registration_deadline,
        max_participants=payload.max_participants,
        registration_type=payload.registration_type,
        status="active",
        competition_categories=payload.competition_categories,
        created_by_user_id=current_user.id
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    # Notify the tenant only when the event is actually published (drafts stay
    # silent). Best-effort — never fails the create. Published events also go
    # onto the notice board automatically.
    if payload.is_published:
        from app.services.auto_announce import auto_announce
        from app.models.announcement import AnnouncementCategory
        auto_announce(
            db,
            org_id=current_user.organization_id,
            category=AnnouncementCategory.EVENT,
            title_ta=f"📅 {payload.title_ta}",
            title_en=f"📅 {payload.title_en}",
            body_ta=payload.description_ta or payload.title_ta,
            body_en=payload.description_en or payload.title_en,
            expires_at=payload.event_end,
            created_by_user_id=current_user.id,
        )
        NotificationService.broadcast_to_tenant(
            db=db,
            tenant_id=current_user.organization_id,
            category="EVENT",
            title_en=f"New event: {payload.title_en}",
            title_ta=f"புதிய நிகழ்வு: {payload.title_ta}",
            body_en=payload.description_en,
            body_ta=payload.description_ta,
            route="/events",
        )
    return event

@router.put("/{event_id}", response_model=EventOut)
def update_event(
    event_id: UUID,
    payload: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive)
):
    """Update an existing event."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    update_data = payload.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(event, key, value)
        
    db.commit()
    db.refresh(event)
    return event

@router.get("", response_model=List[EventOut])
def list_events(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """List published events for the current tenant (public)."""
    query = db.query(Event).filter(Event.organization_id == tenant_id, Event.is_published == True, Event.status != "deleted")
    events = _attach_registration_counts(db, query.order_by(Event.event_start.desc()).all())
    result = [EventOut.model_validate(e) for e in events]

    cached = etag_not_modified(request, result)
    if cached is not None:
        return cached
    set_etag(response, result)
    return result

@router.get("/admin/all", response_model=List[EventOut])
def list_all_events(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive)
):
    """List all events (including drafts) for admin."""
    query = db.query(Event).filter(Event.organization_id == current_user.organization_id, Event.status != "deleted")
    return _attach_registration_counts(db, query.order_by(Event.event_start.desc()).all())

@router.get("/{event_id}", response_model=EventOut)
def get_event(
    event_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Get a single event by ID, scoped to current tenant."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == tenant_id,
        Event.status != "deleted"
    ).first()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    _attach_registration_counts(db, [event])
    return event

@router.post("/{event_id}/register", response_model=EventRegistrationOut)
def register_for_event(
    event_id: UUID,
    payload: EventRegistrationCreate,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Register for an event."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == tenant_id,
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    
    if not event.is_published:
        raise HTTPException(status_code=400, detail="Event is not open for registration")
        
    # Only an explicit False closes registration — NULL means the row predates
    # the column (unset = enabled, matching the insert default).
    if event.registration_enabled is False:
        raise HTTPException(status_code=400, detail="This event does not require registration. Anyone can join!")
        
    if event.registration_deadline:
        deadline = event.registration_deadline
        if deadline.tzinfo is None:  # SQLite hands back naive datetimes
            deadline = deadline.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > deadline:
            raise HTTPException(status_code=400, detail="Registration deadline has passed")

    # A running (LIVE) event still accepts entries — multi-day competitions
    # register participants mid-event. Only a finished event is closed.
    event_end = event.event_end
    if event_end is not None:
        if event_end.tzinfo is None:
            event_end = event_end.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > event_end:
            raise HTTPException(status_code=400, detail="Event has ended")
        
    if event.max_participants:
        current_count = db.query(EventRegistration).filter(EventRegistration.event_id == event_id).count()
        if current_count >= event.max_participants:
            raise HTTPException(status_code=400, detail="Event has reached maximum capacity")

    # If logged in, maybe check if already registered
    if current_user:
        existing = db.query(EventRegistration).filter(
            EventRegistration.event_id == event_id,
            EventRegistration.user_id == current_user.id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="You are already registered for this event")

    registration = EventRegistration(
        event_id=event_id,
        user_id=current_user.id if current_user else None,
        name=payload.name,
        dob=payload.dob,
        gender=payload.gender,
        mobile_number=payload.mobile_number,
        email=payload.email,
        address=payload.address,
        school_college=payload.school_college,
        class_grade=payload.class_grade,
        member_id=payload.member_id,
        competition_category=payload.competition_category or [],
        remarks=payload.remarks,
        status="registered"
    )
    try:
        db.add(registration)
        db.commit()
        db.refresh(registration)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"DB Error: {str(e)}")
    return registration

@router.get("/{event_id}/registrations", response_model=List[EventRegistrationOut])
def get_event_registrations(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive)
):
    """Get all registrations for an event (Admin only)."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
        
    registrations = db.query(EventRegistration).filter(EventRegistration.event_id == event_id).all()
    return registrations

@router.get("/{event_id}/registrations.csv")
def export_event_registrations_csv(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive),
):
    """Download an event's registrations as CSV (admin only). Admins collect
    these offline (e.g. the Drawing Competition roster)."""
    import csv as _csv
    import io as _io
    from fastapi.responses import StreamingResponse

    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id,
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    rows = (
        db.query(EventRegistration)
        .filter(EventRegistration.event_id == event_id)
        .order_by(EventRegistration.created_at.asc())
        .all()
    )

    def _age(dob):
        if not dob:
            return ""
        today = datetime.now(timezone.utc)
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))

    out = _io.StringIO()
    w = _csv.writer(out)
    w.writerow(["Name", "DOB", "Age", "Gender", "Mobile", "School/College",
                "Class", "Category", "Registered At"])
    for r in rows:
        cats = r.competition_category
        cats = ", ".join(cats) if isinstance(cats, list) else (cats or "")
        w.writerow([
            r.name or "",
            r.dob.date().isoformat() if r.dob else "",
            _age(r.dob),
            r.gender or "",
            r.mobile_number or "",
            r.school_college or "",
            r.class_grade or "",
            cats,
            r.created_at.isoformat() if r.created_at else "",
        ])
    out.seek(0)
    fname = f"registrations_{event.title_en or event_id}".replace(" ", "_")[:60]
    return StreamingResponse(
        iter([out.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{fname}.csv"'},
    )

@router.get("/{event_id}/registrants", response_model=EventRegistrantsOut)
def get_event_registrants(
    event_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Names-only list of who registered — safe for any user (no PII).

    The full-detail /registrations endpoint stays admin-only; this one powers
    the member-facing "N Going" list in the app and on the web.
    """
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == tenant_id,
    ).first()
    if not event or not event.is_published:
        raise HTTPException(status_code=404, detail="Event not found")

    names = [
        row[0]
        for row in db.query(EventRegistration.name)
        .filter(EventRegistration.event_id == event_id)
        .order_by(EventRegistration.created_at.asc())
        .all()
    ]
    return EventRegistrantsOut(count=len(names), names=names)

@router.get("/{event_id}/analytics")
def get_event_analytics(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive)
):
    """Get analytics for an event (Admin only)."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    registrations = db.query(EventRegistration).filter(EventRegistration.event_id == event_id).all()
    
    total = len(registrations)
    by_gender = {}
    by_age_group = {"under_18": 0, "18_to_25": 0, "26_to_35": 0, "above_35": 0}
    by_competition = {}
    
    for r in registrations:
        by_gender[r.gender] = by_gender.get(r.gender, 0) + 1
        
        if r.age < 18:
            by_age_group["under_18"] += 1
        elif r.age <= 25:
            by_age_group["18_to_25"] += 1
        elif r.age <= 35:
            by_age_group["26_to_35"] += 1
        else:
            by_age_group["above_35"] += 1
            
        cats = r.competition_category if isinstance(r.competition_category, list) else []
        for cat in cats:
            by_competition[cat] = by_competition.get(cat, 0) + 1
            
    return {
        "total_registrations": total,
        "by_gender": by_gender,
        "by_age_group": by_age_group,
        "by_competition": by_competition
    }

@router.post("/{event_id}/checkin", response_model=EventCheckinOut)
def checkin_event(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_member)
):
    """Check in to an event via QR code scan (Volunteers and Members)."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id
    ).first()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    existing = db.query(EventAttendance).filter(
        EventAttendance.event_id == event_id,
        EventAttendance.user_id == current_user.id
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already checked in to this event"
        )

    now = datetime.now(timezone.utc)
    attendance = EventAttendance(
        event_id=event_id,
        user_id=current_user.id,
        checked_in_at=now
    )
    db.add(attendance)
    db.commit()

    return EventCheckinOut(
        message="Check-in successful",
        event_id=event_id,
        user_id=current_user.id,
        checked_in_at=now
    )


@router.post("/{event_id}/checkout", response_model=EventCheckoutOut)
def checkout_event(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Check out of an event, recording hours accrued since check-in."""
    attendance = db.query(EventAttendance).filter(
        EventAttendance.event_id == event_id,
        EventAttendance.user_id == current_user.id
    ).first()

    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No check-in record found for this event"
        )

    if attendance.checked_out_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already checked out of this event"
        )

    now = datetime.now(timezone.utc)
    checked_in = attendance.checked_in_at
    # Ensure checked_in is timezone-aware for arithmetic
    if checked_in.tzinfo is None:
        checked_in = checked_in.replace(tzinfo=timezone.utc)

    hours = round((now - checked_in).total_seconds() / 3600, 2)

    attendance.checked_out_at = now
    attendance.hours_accrued = Decimal(str(hours))

    # Update or create VolunteerMetadata hours
    volunteer_meta = db.query(VolunteerMetadata).filter(
        VolunteerMetadata.user_id == current_user.id
    ).first()
    if volunteer_meta:
        current_total = float(volunteer_meta.total_hours_accrued or 0)
        volunteer_meta.total_hours_accrued = Decimal(str(round(current_total + hours, 2)))
    else:
        volunteer_meta = VolunteerMetadata(
            user_id=current_user.id,
            skills=[],
            availability_status="AVAILABLE",
            total_hours_accrued=Decimal(str(hours)),
        )
        db.add(volunteer_meta)

    db.commit()

    return EventCheckoutOut(checked_out_at=now, hours_accrued=hours)


@router.delete("/{event_id}")
def delete_event(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_executive)
):
    """Soft delete an event (Admin only)."""
    event = db.query(Event).filter(
        Event.id == event_id,
        Event.organization_id == current_user.organization_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
        
    event.status = "deleted"
    db.commit()
    return {"message": "Event deleted successfully"}

@router.delete("/{event_id}/register")
def cancel_registration(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Cancel registration for an event."""
    registration = db.query(EventRegistration).filter(
        EventRegistration.event_id == event_id,
        EventRegistration.user_id == current_user.id
    ).first()
    if not registration:
        raise HTTPException(status_code=404, detail="Registration not found")
        
    db.delete(registration)
    db.commit()
    return {"message": "Registration cancelled successfully"}

@router.get("/{event_id}/registration-status")
def get_registration_status(
    event_id: UUID,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    """Get registration status and total count."""
    total = db.query(EventRegistration).filter(EventRegistration.event_id == event_id).count()
    is_registered = False
    
    if current_user:
        existing = db.query(EventRegistration).filter(
            EventRegistration.event_id == event_id,
            EventRegistration.user_id == current_user.id
        ).first()
        if existing:
            is_registered = True
            
    return {
        "is_registered": is_registered,
        "total_registrations": total
    }
