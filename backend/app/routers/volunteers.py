import datetime
from io import BytesIO
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user, RoleChecker
from app.models.user import User, UserProfile, VolunteerMetadata
from app.models.tenant import Organization
from app.services.certificates import generate_volunteer_certificate

router = APIRouter(prefix="/volunteers", tags=["Volunteers"])

require_volunteer = RoleChecker(["VOLUNTEER"])


@router.get("/my-certificate")
def get_my_certificate(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_volunteer),
):
    """
    Generate and return a PDF volunteer certificate for the authenticated volunteer.
    Requires the user to have a VolunteerMetadata record.
    """
    volunteer_meta = db.query(VolunteerMetadata).filter(
        VolunteerMetadata.user_id == current_user.id
    ).first()
    if not volunteer_meta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No volunteer metadata found for this user"
        )

    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()
    full_name = profile.full_name_en if profile and profile.full_name_en else "Volunteer"

    org = db.query(Organization).filter(
        Organization.id == current_user.organization_id
    ).first()
    org_name = org.name_en if org else "FYC Connect"

    total_hours = float(volunteer_meta.total_hours_accrued or 0)
    cert_id = str(current_user.id)[:8]
    issued_date = datetime.date.today()

    pdf_bytes = generate_volunteer_certificate(
        full_name=full_name,
        org_name=org_name,
        total_hours=total_hours,
        issued_date=issued_date,
        cert_id=cert_id,
    )

    return StreamingResponse(
        BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="certificate_{cert_id}.pdf"'
        },
    )
