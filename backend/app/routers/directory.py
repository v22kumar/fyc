from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.directory import DirectoryContact, ContactCategory
from app.models.geography import GeographicNode
from app.models.user import User
from app.schemas.directory import ContactCreate, ContactUpdate, ContactOut
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import get_current_tenant_id

router = APIRouter(prefix="/directory", tags=["Directory"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


def _build_contact_out(contact: DirectoryContact, db: Session) -> ContactOut:
    """Hydrate geography name fields that live outside the ORM model."""
    geo = db.get(GeographicNode, contact.geography_id) if contact.geography_id else None
    return ContactOut(
        id=contact.id,
        category=contact.category,
        name_ta=contact.name_ta,
        name_en=contact.name_en,
        designation_ta=contact.designation_ta,
        designation_en=contact.designation_en,
        phone_primary=contact.phone_primary,
        phone_secondary=contact.phone_secondary,
        whatsapp_number=contact.whatsapp_number,
        address_ta=contact.address_ta,
        address_en=contact.address_en,
        geography_id=contact.geography_id,
        geography_name_en=geo.name_en if geo else None,
        geography_name_ta=geo.name_ta if geo else None,
        is_active=contact.is_active,
        display_order=contact.display_order,
        organization_id=contact.organization_id,
        created_at=contact.created_at,
        updated_at=contact.updated_at,
    )


@router.get("", response_model=List[ContactOut])
def list_contacts(
    category: Optional[ContactCategory] = None,
    db: Session = Depends(get_db),
):
    """
    List all active directory contacts for the current tenant.
    Optionally filter by ?category=POLICE (public, no auth required).
    Results are ordered by category display_order then name.
    """
    tenant_id = get_current_tenant_id()
    query = db.query(DirectoryContact).filter(DirectoryContact.is_active == True)
    if tenant_id:
        query = query.filter(DirectoryContact.organization_id == tenant_id)
    if category:
        query = query.filter(DirectoryContact.category == category)
    contacts = query.order_by(
        DirectoryContact.category,
        DirectoryContact.display_order,
        DirectoryContact.name_en,
    ).all()
    return [_build_contact_out(c, db) for c in contacts]


@router.get("/{contact_id}", response_model=ContactOut)
def get_contact(contact_id: UUID, db: Session = Depends(get_db)):
    """Retrieve a single directory contact by ID (public)."""
    contact = db.query(DirectoryContact).filter(
        DirectoryContact.id == contact_id,
        DirectoryContact.is_active == True,
    ).first()
    if not contact:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")
    return _build_contact_out(contact, db)


@router.post("", response_model=ContactOut, status_code=status.HTTP_201_CREATED)
def create_contact(
    payload: ContactCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Create a new directory contact (Admin / Super Admin only)."""
    contact = DirectoryContact(
        organization_id=current_user.organization_id,
        category=payload.category,
        name_ta=payload.name_ta,
        name_en=payload.name_en,
        designation_ta=payload.designation_ta,
        designation_en=payload.designation_en,
        phone_primary=payload.phone_primary,
        phone_secondary=payload.phone_secondary,
        whatsapp_number=payload.whatsapp_number,
        address_ta=payload.address_ta,
        address_en=payload.address_en,
        geography_id=payload.geography_id,
        is_active=payload.is_active,
        display_order=payload.display_order,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return _build_contact_out(contact, db)


@router.patch("/{contact_id}", response_model=ContactOut)
def update_contact(
    contact_id: UUID,
    payload: ContactUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Update an existing directory contact (Admin / Super Admin only)."""
    contact = db.query(DirectoryContact).filter(
        DirectoryContact.id == contact_id,
        DirectoryContact.organization_id == current_user.organization_id,
    ).first()
    if not contact:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(contact, field, value)

    db.commit()
    db.refresh(contact)
    return _build_contact_out(contact, db)


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(
    contact_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Soft-delete a directory contact by setting is_active=False
    (Admin / Super Admin only). Returns 204 No Content on success.
    """
    contact = db.query(DirectoryContact).filter(
        DirectoryContact.id == contact_id,
        DirectoryContact.organization_id == current_user.organization_id,
    ).first()
    if not contact:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")

    contact.is_active = False
    db.commit()
