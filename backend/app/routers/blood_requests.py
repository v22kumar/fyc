from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user, get_current_user_optional
from app.middleware.tenant import require_tenant_id
from app.models.blood_donor import BloodDonor
from app.models.blood_request import BloodRequest, BloodPledge
from app.models.user import User, UserProfile
from app.schemas.blood_request import (
    BloodRequestCreate, BloodRequestOut, BloodRequestDetailOut,
    PledgeCreate, PledgeOut,
)
from app.services import blood_matching as bm
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/blood-requests", tags=["Blood Requests"])

# Radius (km) the emergency fan-out reaches, by urgency.
_RADIUS_BY_URGENCY = {"CRITICAL": 25.0, "URGENT": 15.0, "ROUTINE": 8.0}
_MAX_OPEN_PER_REQUESTER = 3


def _name(db: Session, user_id) -> Optional[str]:
    if not user_id:
        return None
    p = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    return (p.full_name_en or p.full_name_ta) if p else None


def _accepted_count(db: Session, request_id) -> int:
    return (
        db.query(BloodPledge)
        .filter(BloodPledge.request_id == request_id, BloodPledge.status == "ACCEPTED")
        .count()
    )


def _out(db: Session, req: BloodRequest) -> BloodRequestOut:
    return BloodRequestOut(
        id=req.id,
        patient_blood_group=req.patient_blood_group,
        units_needed=req.units_needed,
        hospital_name=req.hospital_name,
        latitude=req.latitude,
        longitude=req.longitude,
        urgency=req.urgency,
        note=req.note,
        contact_phone=req.contact_phone,
        status=req.status,
        notified_count=req.notified_count or 0,
        accepted_count=_accepted_count(db, req.id),
        created_at=req.created_at,
        requester_name=_name(db, req.requester_user_id),
    )


def _fan_out(db: Session, req: BloodRequest, tenant_id) -> int:
    """Notify nearby, compatible, eligible, opted-in FYC donors. Returns count."""
    if req.latitude is None or req.longitude is None:
        return 0
    radius = _RADIUS_BY_URGENCY.get(req.urgency, 15.0)
    groups = bm.compatible_donor_groups(req.patient_blood_group)

    donors = (
        db.query(BloodDonor)
        .filter(
            BloodDonor.organization_id == tenant_id,
            BloodDonor.is_available == True,  # noqa: E712
            BloodDonor.location_consent == True,  # noqa: E712
            BloodDonor.notify_opt_in == True,  # noqa: E712
            BloodDonor.latitude.isnot(None),
            BloodDonor.longitude.isnot(None),
            BloodDonor.blood_group.in_(groups),
        )
        .all()
    )

    svc = NotificationService(db)
    hospital = req.hospital_name or "a nearby hospital"
    notified = 0
    for d in donors:
        if req.requester_user_id and d.user_id == req.requester_user_id:
            continue  # don't alert the requester about their own request
        if not bm.is_eligible(d.last_donation_date):
            continue
        dist = bm.haversine_km(req.latitude, req.longitude, d.latitude, d.longitude)
        if dist > radius:
            continue
        km = round(dist, 1)
        try:
            svc.send_notification(
                user_id=d.user_id,
                organization_id=tenant_id,
                title_en=f"🩸 Blood needed: {req.patient_blood_group}",
                title_ta=f"🩸 ரத்தம் தேவை: {req.patient_blood_group}",
                body_en=f"Urgent {req.patient_blood_group} request ~{km} km away at {hospital}. Can you help?",
                body_ta=f"{hospital} அருகில் ~{km} கி.மீ தொலைவில் {req.patient_blood_group} ரத்தம் அவசரமாக தேவை. உதவ முடியுமா?",
                notification_type="BLOOD_EMERGENCY",
                data={"route": f"/blood-requests/{req.id}", "request_id": str(req.id)},
            )
            notified += 1
        except Exception:
            # One donor's push failure must never abort the whole fan-out.
            continue
    return notified


@router.post("", response_model=BloodRequestOut, status_code=status.HTTP_201_CREATED)
def create_request(
    payload: BloodRequestCreate,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Raise a blood request and alert nearby eligible donors."""
    if payload.patient_blood_group.upper() not in bm.COMPATIBLE_DONORS:
        raise HTTPException(status_code=400, detail="Invalid blood group")

    open_count = (
        db.query(BloodRequest)
        .filter(
            BloodRequest.organization_id == tenant_id,
            BloodRequest.requester_user_id == current_user.id,
            BloodRequest.status == "OPEN",
        )
        .count()
    )
    if open_count >= _MAX_OPEN_PER_REQUESTER:
        raise HTTPException(
            status_code=429,
            detail="You already have several open requests. Please close one first.",
        )

    req = BloodRequest(
        organization_id=tenant_id,
        requester_user_id=current_user.id,
        patient_blood_group=payload.patient_blood_group.upper(),
        units_needed=payload.units_needed,
        hospital_name=payload.hospital_name,
        latitude=payload.latitude,
        longitude=payload.longitude,
        urgency=payload.urgency,
        note=payload.note,
        contact_phone=payload.contact_phone or current_user.phone_number,
        status="OPEN",
    )
    db.add(req)
    db.commit()
    db.refresh(req)

    req.notified_count = _fan_out(db, req, tenant_id)
    db.commit()
    db.refresh(req)
    return _out(db, req)


@router.get("", response_model=List[BloodRequestOut])
def list_requests(
    status_filter: str = "OPEN",
    limit: int = 50,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Public board of requests for this org (default: open ones), newest first."""
    q = db.query(BloodRequest).filter(BloodRequest.organization_id == tenant_id)
    if status_filter and status_filter.upper() != "ALL":
        q = q.filter(BloodRequest.status == status_filter.upper())
    reqs = q.order_by(BloodRequest.created_at.desc()).limit(limit).all()
    return [_out(db, r) for r in reqs]


@router.get("/stats")
def blood_stats(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Admin oversight: donor coverage + emergency response analytics."""
    if (current_user.role or "").upper() not in ("ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER"):
        raise HTTPException(status_code=403, detail="Admins only")

    donors = db.query(BloodDonor).filter(BloodDonor.organization_id == tenant_id).all()
    total_donors = len(donors)
    with_location = sum(
        1 for d in donors
        if d.latitude is not None and d.longitude is not None and d.location_consent
    )
    available = sum(1 for d in donors if d.is_available)
    eligible = sum(1 for d in donors if bm.is_eligible(d.last_donation_date))
    imported = (
        db.query(func.count(BloodDonor.id))
        .join(User, User.id == BloodDonor.user_id)
        .filter(BloodDonor.organization_id == tenant_id, User.source == "F2S_IMPORT")
        .scalar()
    ) or 0
    fyc_donors = total_donors - imported

    # Blood-group coverage (how many available donors per group).
    coverage: dict[str, int] = {}
    for d in donors:
        if d.is_available:
            coverage[d.blood_group] = coverage.get(d.blood_group, 0) + 1

    reqs = db.query(BloodRequest).filter(BloodRequest.organization_id == tenant_id).all()
    total_requests = len(reqs)
    open_requests = sum(1 for r in reqs if r.status == "OPEN")
    fulfilled_requests = sum(1 for r in reqs if r.status == "FULFILLED")
    notified_total = sum((r.notified_count or 0) for r in reqs)

    pledges = db.query(BloodPledge).filter(BloodPledge.organization_id == tenant_id).all()
    accepted = sum(1 for p in pledges if p.status == "ACCEPTED")
    donated = sum(1 for p in pledges if p.status == "DONATED")

    response_rate = round(100.0 * accepted / notified_total, 1) if notified_total else 0.0
    lives_helped = sum((r.units_needed or 1) for r in reqs if r.status == "FULFILLED")

    return {
        "donors": {
            "total": total_donors,
            "fyc": fyc_donors,
            "imported": imported,
            "with_location": with_location,
            "available": available,
            "eligible": eligible,
            "coverage": coverage,
        },
        "requests": {
            "total": total_requests,
            "open": open_requests,
            "fulfilled": fulfilled_requests,
            "notified_total": notified_total,
        },
        "responses": {
            "accepted": accepted,
            "donated": donated,
            "response_rate_pct": response_rate,
        },
        "lives_helped": lives_helped,
    }


@router.get("/{request_id}", response_model=BloodRequestDetailOut)
def get_request(
    request_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    req = (
        db.query(BloodRequest)
        .filter(BloodRequest.id == request_id, BloodRequest.organization_id == tenant_id)
        .first()
    )
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    pledges = db.query(BloodPledge).filter(BloodPledge.request_id == req.id).all()
    my_pledge = None
    pledge_out = []
    for p in pledges:
        if current_user and p.donor_user_id == current_user.id:
            my_pledge = p.status
        pledge_out.append(PledgeOut(
            id=p.id,
            donor_user_id=p.donor_user_id,
            donor_name=_name(db, p.donor_user_id),
            status=p.status,
            responded_at=p.updated_at or p.created_at,
        ))

    base = _out(db, req)
    return BloodRequestDetailOut(**base.model_dump(), pledges=pledge_out, my_pledge=my_pledge)


@router.post("/{request_id}/pledge", response_model=BloodRequestDetailOut)
def pledge(
    request_id: UUID,
    payload: PledgeCreate,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """A donor responds to a request (accept / decline / mark donated)."""
    req = (
        db.query(BloodRequest)
        .filter(BloodRequest.id == request_id, BloodRequest.organization_id == tenant_id)
        .first()
    )
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    existing = (
        db.query(BloodPledge)
        .filter(BloodPledge.request_id == req.id, BloodPledge.donor_user_id == current_user.id)
        .first()
    )
    if existing:
        existing.status = payload.status
    else:
        db.add(BloodPledge(
            organization_id=tenant_id,
            request_id=req.id,
            donor_user_id=current_user.id,
            status=payload.status,
        ))
    db.commit()

    # Let the requester know someone is coming.
    if payload.status == "ACCEPTED" and req.requester_user_id:
        try:
            NotificationService(db).send_notification(
                user_id=req.requester_user_id,
                organization_id=tenant_id,
                title_en="🩸 A donor responded",
                title_ta="🩸 ஒரு தானதாரர் பதிலளித்தார்",
                body_en=f"{_name(db, current_user.id) or 'A donor'} accepted your {req.patient_blood_group} request.",
                body_ta=f"{_name(db, current_user.id) or 'ஒரு தானதாரர்'} உங்கள் {req.patient_blood_group} கோரிக்கையை ஏற்றார்.",
                notification_type="BLOOD_EMERGENCY",
                data={"route": f"/blood-requests/{req.id}", "request_id": str(req.id)},
            )
        except Exception:
            pass

    return get_request(request_id, db, tenant_id, current_user)


@router.post("/{request_id}/close", response_model=BloodRequestOut)
def close_request(
    request_id: UUID,
    fulfilled: bool = True,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Requester (or an admin) closes a request once fulfilled or cancelled."""
    req = (
        db.query(BloodRequest)
        .filter(BloodRequest.id == request_id, BloodRequest.organization_id == tenant_id)
        .first()
    )
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    is_admin = (current_user.role or "").upper() in ("ADMIN", "SUPER_ADMIN", "EXECUTIVE_MEMBER")
    if req.requester_user_id != current_user.id and not is_admin:
        raise HTTPException(status_code=403, detail="Only the requester or an admin can close this")
    req.status = "FULFILLED" if fulfilled else "CLOSED"
    db.commit()
    db.refresh(req)
    return _out(db, req)
