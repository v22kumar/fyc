from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.blood_donor import BloodDonor
from app.models.user import User, UserProfile
from app.models.audit import AuditLog
from app.models.geography import GeographicNode, GeoLevel
from app.schemas.blood_donor import (
    BloodDonorRegister, BloodDonorAvailabilityUpdate,
    BloodDonorPublicOut, ContactRequestOut, VALID_BLOOD_GROUPS
)
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/blood-donors", tags=["Blood Donors"])

require_registered = RoleChecker(["PUBLIC_CITIZEN", "VOLUNTEER", "CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])


def _district_taluk_ids(db: Session, geography_id: UUID) -> list[UUID]:
    """Return IDs of all taluks/wards/villages in the same district as geography_id."""
    node = db.get(GeographicNode, geography_id)
    if not node:
        return [geography_id]

    # Walk up to district level
    current = node
    while current and current.level != GeoLevel.DISTRICT:
        if current.parent_id is None:
            break
        current = db.get(GeographicNode, current.parent_id)

    if not current or current.level != GeoLevel.DISTRICT:
        return [geography_id]

    # Collect all descendant IDs under this district (one level deep = taluks)
    taluks = db.query(GeographicNode).filter(GeographicNode.parent_id == current.id).all()
    ids = [current.id] + [t.id for t in taluks]
    return ids


@router.get("", response_model=List[BloodDonorPublicOut])
def search_donors(
    blood_group: Optional[str] = None,
    geography_id: Optional[UUID] = None,
    nearby: bool = False,
    available_only: bool = True,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Public search for blood donors. Names and locations are visible but contact
    details are not exposed here — use the /request-contact endpoint.
    Pass nearby=true with geography_id to include all taluks in the same district.
    """
    query = db.query(BloodDonor).filter(BloodDonor.organization_id == tenant_id)
    if blood_group:
        query = query.filter(BloodDonor.blood_group == blood_group.upper())
    if geography_id:
        if nearby:
            area_ids = _district_taluk_ids(db, geography_id)
            query = query.filter(BloodDonor.geography_id.in_(area_ids))
        else:
            query = query.filter(BloodDonor.geography_id == geography_id)
    if available_only:
        query = query.filter(BloodDonor.is_available == True)

    donors = query.all()
    result = []
    for donor in donors:
        profile = db.query(UserProfile).filter(UserProfile.user_id == donor.user_id).first()
        geo = db.get(GeographicNode, donor.geography_id) if donor.geography_id else None
        result.append(BloodDonorPublicOut(
            id=donor.id,
            blood_group=donor.blood_group,
            is_available=donor.is_available,
            geography_id=donor.geography_id,
            geography_name_en=geo.name_en if geo else None,
            geography_name_ta=geo.name_ta if geo else None,
            full_name_en=profile.full_name_en if profile else None,
            full_name_ta=profile.full_name_ta if profile else None,
        ))
    return result

@router.post("/register", response_model=BloodDonorPublicOut, status_code=status.HTTP_201_CREATED)
def register_donor(
    payload: BloodDonorRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Register the authenticated user as a blood donor."""
    if payload.blood_group.upper() not in VALID_BLOOD_GROUPS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid blood group. Must be one of: {', '.join(VALID_BLOOD_GROUPS)}"
        )

    existing = db.query(BloodDonor).filter(BloodDonor.user_id == current_user.id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already registered as a blood donor"
        )

    donor = BloodDonor(
        organization_id=current_user.organization_id,
        user_id=current_user.id,
        blood_group=payload.blood_group.upper(),
        geography_id=payload.geography_id,
        is_available=payload.is_available,
        last_donation_date=payload.last_donation_date
    )
    db.add(donor)
    db.commit()
    db.refresh(donor)

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    geo = db.get(GeographicNode, donor.geography_id) if donor.geography_id else None
    return BloodDonorPublicOut(
        id=donor.id,
        blood_group=donor.blood_group,
        is_available=donor.is_available,
        geography_id=donor.geography_id,
        geography_name_en=geo.name_en if geo else None,
        geography_name_ta=geo.name_ta if geo else None,
        full_name_en=profile.full_name_en if profile else None,
        full_name_ta=profile.full_name_ta if profile else None,
    )

@router.patch("/{donor_id}/availability", response_model=BloodDonorPublicOut)
def update_availability(
    donor_id: UUID,
    payload: BloodDonorAvailabilityUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update the authenticated user's own blood donor availability status."""
    donor = db.query(BloodDonor).filter(
        BloodDonor.id == donor_id,
        BloodDonor.user_id == current_user.id
    ).first()
    if not donor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Donor record not found")

    donor.is_available = payload.is_available
    db.commit()
    db.refresh(donor)

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    geo = db.get(GeographicNode, donor.geography_id) if donor.geography_id else None
    return BloodDonorPublicOut(
        id=donor.id,
        blood_group=donor.blood_group,
        is_available=donor.is_available,
        geography_id=donor.geography_id,
        geography_name_en=geo.name_en if geo else None,
        geography_name_ta=geo.name_ta if geo else None,
        full_name_en=profile.full_name_en if profile else None,
        full_name_ta=profile.full_name_ta if profile else None,
    )

@router.post("/{donor_id}/request-contact", response_model=ContactRequestOut)
def request_contact(
    donor_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_registered)
):
    """
    Retrieve a donor's contact details (phone + WhatsApp link).
    Requires authentication. Every contact access is audit-logged.
    """
    donor = db.query(BloodDonor).filter(
        BloodDonor.id == donor_id,
        BloodDonor.organization_id == current_user.organization_id,
    ).first()
    if not donor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Donor not found")

    donor_user = db.query(User).filter(User.id == donor.user_id).first()
    if not donor_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Donor user not found")

    # Log this contact extraction to audit trail
    log = AuditLog(
        organization_id=current_user.organization_id,
        user_id=current_user.id,
        action_type="CONTACT_EXTRACTION_DONOR",
        target_table="blood_donors",
        target_id=donor_id,
        new_values={"accessed_by": str(current_user.id), "donor_id": str(donor_id)}
    )
    db.add(log)
    db.commit()

    phone = donor_user.phone_number
    wa_number = phone.replace("+", "").replace(" ", "")
    return ContactRequestOut(
        message="Contact details retrieved. Every access is logged for donor privacy.",
        phone_number=phone,
        whatsapp_link=f"https://wa.me/{wa_number}"
    )
