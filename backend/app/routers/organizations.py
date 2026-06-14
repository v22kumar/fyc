from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.models.tenant import Organization
from app.schemas.tenant import OrganizationCreate, OrganizationOut
from app.dependencies import RoleChecker

router = APIRouter(prefix="/organizations", tags=["Organizations"])

require_superadmin = RoleChecker(["SUPER_ADMIN"])

@router.get("", response_model=List[OrganizationOut])
def list_organizations(db: Session = Depends(get_db)):
    """List all active organizations (public — used by clients on login screen)."""
    return db.query(Organization).filter(Organization.is_active == True).all()

@router.get("/{org_id}", response_model=OrganizationOut)
def get_organization(org_id: str, db: Session = Depends(get_db)):
    """Get a single organization by ID."""
    from uuid import UUID
    try:
        uid = UUID(org_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid organization ID")
    org = db.query(Organization).filter(Organization.id == uid).first()
    if not org:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    return org

@router.post("", response_model=OrganizationOut, status_code=status.HTTP_201_CREATED)
def create_organization(
    payload: OrganizationCreate,
    db: Session = Depends(get_db),
    _: object = Depends(require_superadmin)
):
    """Create a new tenant organization (Super Admin only)."""
    existing = db.query(Organization).filter(Organization.slug == payload.slug).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Slug already in use")

    org = Organization(**payload.model_dump())
    db.add(org)
    db.commit()
    db.refresh(org)
    return org
