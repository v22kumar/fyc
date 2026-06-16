from decimal import Decimal
from typing import List
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.event import Event, EventAttendance
from app.models.user import User, VolunteerMetadata
from app.schemas.event import EventCreate, EventOut, EventCheckinOut, EventCheckoutOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/events", tags=["Events"])

require_executive = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_member = RoleChecker(["VOLUNTEER", "CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])

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
        created_by_user_id=current_user.id
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event

@router.get("", response_model=List[EventOut])
def list_events(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """List all events for the current tenant (public)."""
    query = db.query(Event).filter(Event.organization_id == tenant_id)
    return query.order_by(Event.event_start.desc()).all()

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
    ).first()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return event

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
