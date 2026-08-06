from datetime import date, datetime, timedelta, timezone
from typing import List, Optional
from pydantic import BaseModel, Field
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.cache import TTLCache
from app.core.database import get_db
from app.models.blood_donor import BloodDonor
from app.models.user import User, UserProfile
from app.models.audit import AuditLog
from app.models.geography import GeographicNode, GeoLevel
from app.schemas.blood_donor import (
    BloodDonorRegister, BloodDonorAvailabilityUpdate, BloodDonorProfileUpdate,
    BloodDonorPublicOut, ContactRequestOut, VALID_BLOOD_GROUPS
)
from app.services import blood_matching as bm
from app.dependencies import get_current_user
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/blood-donors", tags=["Blood Donors"])

# 5-minute search result cache — keyed by all query params + tenant.
# Invalidated on any write (register / availability update).
# maxsize=256: covers 256 unique filter combinations before LRU eviction.
_search_cache = TTLCache(ttl_seconds=300, maxsize=256)
_DONORS_CC = "public, max-age=300, stale-while-revalidate=600"


def _district_taluk_ids(db: Session, geography_id: UUID) -> list[UUID]:
    """Return IDs of all taluks/wards/villages in the same district as geography_id."""
    node = db.get(GeographicNode, geography_id)
    if not node:
        return [geography_id]

    current = node
    while current and current.level != GeoLevel.DISTRICT:
        if current.parent_id is None:
            break
        current = db.get(GeographicNode, current.parent_id)

    if not current or current.level != GeoLevel.DISTRICT:
        return [geography_id]

    taluks = db.query(GeographicNode).filter(GeographicNode.parent_id == current.id).all()
    return [current.id] + [t.id for t in taluks]


def _age_from(dob) -> Optional[int]:
    """Whole years, or nothing.

    A hospital asks a donor's age, so the app should be able to answer — but it
    should answer with an age, not hand out a date of birth. Anyone under 18 is
    reported as None: they cannot donate, and publishing a minor's age in a
    public directory serves no purpose.
    """
    if not dob:
        return None
    today = date.today()
    years = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return years if 18 <= years <= 120 else None


def _public_out(donor, profile, geo, user, distance_km: Optional[float] = None,
                with_approx_location: bool = False,
                approx_from: Optional[tuple] = None) -> BloodDonorPublicOut:
    """Build the public donor view with the derived tier / eligibility fields.

    `approx_from` is the position the distance was actually measured from. It
    matters: a donor seen this morning a kilometre away has a home area twenty
    kilometres off, and publishing the home area anyway put the pin somewhere
    the card did not claim they were. The map and the row have to be the same
    claim or neither is believable.
    """
    imported = bool(user and getattr(user, "source", None) == "F2S_IMPORT")
    approx_lat = approx_lng = None
    src_lat, src_lng = approx_from or (
        getattr(donor, "latitude", None), getattr(donor, "longitude", None)
    )
    if with_approx_location and src_lat is not None and src_lng is not None:
        # Round to ~1.1 km so pins cluster by area without pinpointing a home.
        approx_lat = round(src_lat, 2)
        approx_lng = round(src_lng, 2)
    return BloodDonorPublicOut(
        id=donor.id,
        blood_group=donor.blood_group,
        is_available=bool(donor.is_available),
        geography_id=donor.geography_id,
        geography_name_en=geo.name_en if geo else None,
        geography_name_ta=geo.name_ta if geo else None,
        full_name_en=profile.full_name_en if profile else None,
        full_name_ta=profile.full_name_ta if profile else None,
        age=_age_from(profile.date_of_birth) if profile else None,
        is_imported=imported,
        tier="imported" if imported else "fyc",
        is_eligible=bm.is_eligible(donor.last_donation_date),
        eligible_on=bm.eligible_on(donor.last_donation_date),
        distance_km=(round(distance_km, 1) if distance_km is not None else None),
        has_location=bool(
            getattr(donor, "latitude", None) is not None
            and getattr(donor, "longitude", None) is not None
            and getattr(donor, "location_consent", False)
        ),
        approx_latitude=approx_lat,
        approx_longitude=approx_lng,
    )


@router.get("", response_model=List[BloodDonorPublicOut])
def search_donors(
    blood_group: Optional[str] = None,
    geography_id: Optional[UUID] = None,
    nearby: bool = False,
    compatible: bool = False,
    available_only: bool = True,
    source: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    response: Response = None,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Public search for blood donors. Names and locations are visible but contact
    details are not exposed here — use the /request-contact endpoint.
    Paginated: default limit=100. X-Total-Count header carries full match count.
    Pass nearby=true with geography_id to include all taluks in the same district.
    Results cached 5 minutes; cache flushed on any donor register / availability update.

    `source` splits the two populations, which behave nothing alike:

    * `club` — members who registered in the app. They can be located, notified,
      and asked. This is what the map and the nearby ranking are about.
    * `imported` — contacts from the Friends2Support directory. No account, no
      location, no way to reach them except a cold phone call.

    They were interleaved in one list, which quietly promised the same thing for
    both: a member who has agreed to be asked, and a stranger's phone number
    from a public directory, adjacent and identically weighted.
    """
    cache_key = (
        str(tenant_id), blood_group or "", str(geography_id), nearby, compatible,
        available_only, source or "", limit, offset,
    )
    hit, cached = _search_cache.get(cache_key)
    if hit:
        result, total = cached
        if response is not None:
            response.headers["X-Total-Count"] = str(total)
            response.headers["Cache-Control"] = _DONORS_CC
        return result

    filters = [BloodDonor.organization_id == tenant_id]
    # The app's "All" chip sends the literal string "All", which was then
    # matched against the blood_group column and returned nothing — so the
    # default view of the whole screen was empty, whatever was in the database.
    if blood_group and blood_group.strip().lower() in ("all", ""):
        blood_group = None
    if blood_group:
        if compatible:
            # Include every donor group that can give to this recipient group.
            filters.append(BloodDonor.blood_group.in_(bm.compatible_donor_groups(blood_group)))
        else:
            filters.append(BloodDonor.blood_group == blood_group.upper())
    if geography_id:
        if nearby:
            area_ids = _district_taluk_ids(db, geography_id)
            filters.append(BloodDonor.geography_id.in_(area_ids))
        else:
            filters.append(BloodDonor.geography_id == geography_id)
    if available_only:
        filters.append(BloodDonor.is_available == True)
    if source:
        want = source.strip().lower()
        if want == "imported":
            filters.append(User.source == "F2S_IMPORT")
        elif want == "club":
            # A donor with no user row at all is not an import — treat the
            # absence of the marker as "one of ours", never the other way round.
            filters.append(
                or_(User.source.is_(None), User.source != "F2S_IMPORT")
            )

    count_q = db.query(func.count(BloodDonor.id))
    if source:
        count_q = count_q.outerjoin(User, User.id == BloodDonor.user_id)
    total = count_q.filter(*filters).scalar() or 0

    rows = (
        db.query(BloodDonor, UserProfile, GeographicNode, User)
        .outerjoin(UserProfile, UserProfile.user_id == BloodDonor.user_id)
        .outerjoin(GeographicNode, GeographicNode.id == BloodDonor.geography_id)
        .outerjoin(User, User.id == BloodDonor.user_id)
        .filter(*filters)
        .order_by(BloodDonor.blood_group, BloodDonor.id)
        .offset(offset)
        .limit(limit)
        .all()
    )

    result = [_public_out(donor, profile, geo, user) for donor, profile, geo, user in rows]

    _search_cache.set(cache_key, (result, total))
    if response is not None:
        response.headers["X-Total-Count"] = str(total)
        response.headers["Cache-Control"] = _DONORS_CC
    return result


@router.get("/nearby", response_model=List[BloodDonorPublicOut])
def nearby_donors(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    blood_group: Optional[str] = None,
    radius_km: float = Query(15.0, gt=0, le=500),
    compatible: bool = True,
    eligible_only: bool = True,
    limit: int = 50,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Location-aware donor search: FYC donors who opted into sharing a base
    location, ranked by real distance from (lat, lng). Widened to compatible
    blood groups by default, and (by default) limited to donors currently
    eligible to donate. F2S contacts have no location and never appear here —
    they remain the call-only fallback in the main list."""
    filters = [
        BloodDonor.organization_id == tenant_id,
        BloodDonor.is_available == True,
        BloodDonor.location_consent == True,
        BloodDonor.latitude.isnot(None),
        BloodDonor.longitude.isnot(None),
    ]
    if blood_group:
        groups = bm.compatible_donor_groups(blood_group) if compatible else [blood_group.upper()]
        filters.append(BloodDonor.blood_group.in_(groups))

    rows = (
        db.query(BloodDonor, UserProfile, GeographicNode, User)
        .outerjoin(UserProfile, UserProfile.user_id == BloodDonor.user_id)
        .outerjoin(GeographicNode, GeographicNode.id == BloodDonor.geography_id)
        .outerjoin(User, User.id == BloodDonor.user_id)
        .filter(*filters)
        .all()
    )

    now = datetime.now(timezone.utc)
    scored = []
    for donor, profile, geo, user in rows:
        if eligible_only and not bm.is_eligible(donor.last_donation_date):
            continue
        # Rank from the freshest position that is still worth believing: where
        # they were last seen if that is recent, otherwise their home area. A
        # last-seen fix from March is not a better answer than "lives nearby",
        # it is only a more precise wrong one.
        origin_lat, origin_lng, basis = donor.latitude, donor.longitude, "home"
        seen_at = donor.last_seen_at
        if seen_at is not None and seen_at.tzinfo is None:
            seen_at = seen_at.replace(tzinfo=timezone.utc)
        if (
            donor.last_seen_lat is not None
            and donor.last_seen_lng is not None
            and seen_at is not None
            and (now - seen_at) < timedelta(hours=_LAST_SEEN_TRUSTED_HOURS)
        ):
            origin_lat, origin_lng = donor.last_seen_lat, donor.last_seen_lng
            basis = "live" if (now - seen_at) < timedelta(hours=1) else "recent"
        dist = bm.haversine_km(lat, lng, origin_lat, origin_lng)
        if dist > radius_km:
            continue
        exact = bool(blood_group) and donor.blood_group == blood_group.upper()
        scored.append((0 if exact else 1, dist, donor, profile, geo, user,
                       basis, (origin_lat, origin_lng)))

    scored.sort(key=lambda t: (t[0], t[1]))  # exact group first, then nearest
    out = []
    for _, dist, d, p, g, u, basis, origin in scored[:limit]:
        item = _public_out(d, p, g, u, distance_km=dist,
                           with_approx_location=True, approx_from=origin)
        # Say which position the distance came from. A distance whose basis is
        # hidden cannot be judged — "3 km away" from a fix an hour old and from
        # a home area recorded last year are not the same claim.
        item.location_basis = basis
        out.append(item)
    return out

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

    # Consent and coordinates are two different facts, and folding them into one
    # threw away the more important half.
    #
    # `location_consent` is the member's answer to "may we place you on a map".
    # Coordinates are whether we have managed to read one yet. Someone who says
    # yes on the registration screen and then misses the Android permission
    # dialog used to be recorded as having said *no* — the yes was silently
    # dropped, and the app had no way of knowing it was ever given. Now the
    # answer is stored as given, and the position lands opportunistically the
    # next time they open the blood screen.
    #
    # Coordinates without consent are still refused, which is the direction that
    # actually matters for privacy.
    consent = bool(payload.location_consent)
    donor = BloodDonor(
        organization_id=current_user.organization_id,
        user_id=current_user.id,
        blood_group=payload.blood_group.upper(),
        geography_id=payload.geography_id,
        is_available=payload.is_available,
        last_donation_date=payload.last_donation_date,
        latitude=payload.latitude if consent else None,
        longitude=payload.longitude if consent else None,
        location_consent=consent,
        notify_opt_in=payload.notify_opt_in,
    )
    db.add(donor)
    db.commit()
    db.refresh(donor)
    _search_cache.invalidate()  # new donor must appear in search results immediately

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    geo = db.get(GeographicNode, donor.geography_id) if donor.geography_id else None
    return _public_out(donor, profile, geo, current_user)

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
    _search_cache.invalidate()  # availability change must reflect in search results immediately

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    geo = db.get(GeographicNode, donor.geography_id) if donor.geography_id else None
    return _public_out(donor, profile, geo, current_user)


@router.patch("/me", response_model=BloodDonorPublicOut)
def update_my_donor_profile(
    payload: BloodDonorProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The authenticated donor updates their own card: availability, last-donation
    date (drives eligibility), opt-in location and notification preference."""
    donor = db.query(BloodDonor).filter(BloodDonor.user_id == current_user.id).first()
    if not donor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="You are not registered as a donor")

    if payload.is_available is not None:
        donor.is_available = payload.is_available
    if payload.last_donation_date is not None:
        donor.last_donation_date = payload.last_donation_date
    if payload.notify_opt_in is not None:
        donor.notify_opt_in = payload.notify_opt_in
    # Location: consent gates whether coordinates are stored at all.
    if payload.location_consent is not None:
        donor.location_consent = payload.location_consent
        if not payload.location_consent:
            donor.latitude = None
            donor.longitude = None
    if payload.latitude is not None and payload.longitude is not None and donor.location_consent:
        donor.latitude = payload.latitude
        donor.longitude = payload.longitude

    db.commit()
    db.refresh(donor)
    _search_cache.invalidate()

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    geo = db.get(GeographicNode, donor.geography_id) if donor.geography_id else None
    return _public_out(donor, profile, geo, current_user)

@router.post("/{donor_id}/request-contact", response_model=ContactRequestOut)
def request_contact(
    donor_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Retrieve a donor's contact details (phone + WhatsApp link).
    Public endpoint, tenant-scoped via X-Organization-ID. Every access is
    still audit-logged (anonymously) so misuse can be traced.
    """
    donor = db.query(BloodDonor).filter(
        BloodDonor.id == donor_id,
        BloodDonor.organization_id == tenant_id,
    ).first()
    if not donor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Donor not found")

    donor_user = db.query(User).filter(User.id == donor.user_id).first()
    if not donor_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Donor user not found")

    # Log this contact extraction to audit trail (no authenticated user on
    # the public site, so it's recorded anonymously rather than skipped).
    log = AuditLog(
        organization_id=tenant_id,
        user_id=None,
        action_type="CONTACT_EXTRACTION_DONOR",
        target_table="blood_donors",
        target_id=donor_id,
        new_values={"accessed_by": "anonymous_public_site", "donor_id": str(donor_id)}
    )
    db.add(log)
    db.commit()

    phone = donor_user.phone_number
    wa_number = phone.replace("+", "").replace(" ", "")
    return ContactRequestOut(
        message="Contact details retrieved.",
        phone_number=phone,
        whatsapp_link=f"https://wa.me/{wa_number}"
    )

class MyLocationIn(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


# Roughly a village. Below this the position has not usefully changed, and
# rewriting it would be churn for no gain in a search that works in kilometres.
_MEANINGFUL_MOVE_KM = 1.0

# How stale a stored position may get before a refresh is worth a write, even
# if the member has not moved.
_REFRESH_AFTER_HOURS = 24

# Beyond this, a last-seen position stops being better information than the
# home area and starts being a more precise way to be wrong.
_LAST_SEEN_TRUSTED_HOURS = 24


@router.patch("/me/location", status_code=status.HTTP_204_NO_CONTENT)
def update_my_location(
    payload: MyLocationIn,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: User = Depends(get_current_user),
):
    """Refresh my own position, opportunistically.

    The app calls this when it happens to be open and already has a cached fix
    from the operating system. That is the whole strategy: no background
    tracking, no polling, no GPS wake — so no battery cost and no extra request
    beyond one the app was making anyway.

    It accepts the tradeoff honestly. A member who never opens the app has a
    stale position, and a member who never opens the app was never going to
    answer a request either.

    Consent still governs. Opening the app is not consent to be located, so a
    donor who has not opted in is a no-op here.
    """
    donor = (
        db.query(BloodDonor)
        .filter(
            BloodDonor.user_id == current_user.id,
            BloodDonor.organization_id == tenant_id,
        )
        .first()
    )
    if not donor or not donor.location_consent:
        # Not a donor, or has not agreed to share a location. Silently nothing —
        # this is a background courtesy call, not something to raise an error at.
        return

    now = datetime.now(timezone.utc)
    last = donor.last_seen_at
    if last is not None and last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)

    moved_enough = (
        donor.last_seen_lat is None
        or donor.last_seen_lng is None
        or bm.haversine_km(
            donor.last_seen_lat, donor.last_seen_lng, payload.lat, payload.lng)
        >= _MEANINGFUL_MOVE_KM
    )
    stale_enough = (
        last is None or (now - last) >= timedelta(hours=_REFRESH_AFTER_HOURS)
    )
    # Most calls land here and cost a read. Writing a new row every time someone
    # opens the app would be churn a kilometre-scale search cannot even see.
    if not (moved_enough or stale_enough):
        return

    # The last-seen pair only. The home area from registration is a different
    # claim and this must never touch it — writing here used to relocate a
    # member permanently to wherever they last opened the app.
    donor.last_seen_lat = payload.lat
    donor.last_seen_lng = payload.lng
    donor.last_seen_at = now
    db.commit()
