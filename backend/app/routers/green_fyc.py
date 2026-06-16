from typing import List, Optional, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.green_fyc import PlantationDrive, TreeRegistration, TreeStatus
from app.models.user import User
from app.schemas.green_fyc import (
    DriveCreate, DriveUpdate, DriveOut,
    TreeCreate, TreeUpdate, TreeGrowthUpdate, TreeOut,
)
from app.dependencies import get_current_user, RoleChecker
from app.middleware.tenant import require_tenant_id

router = APIRouter(prefix="/green", tags=["Green FYC"])

require_manager = RoleChecker(["EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN"])
require_any_auth = RoleChecker([
    "PUBLIC_CITIZEN", "VOLUNTEER", "CLUB_MEMBER",
    "EXECUTIVE_MEMBER", "ADMIN", "SUPER_ADMIN",
])


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _drive_out(drive: PlantationDrive) -> DriveOut:
    tree_count = len(drive.trees) if drive.trees is not None else 0
    return DriveOut(
        id=drive.id,
        organization_id=drive.organization_id,
        title_ta=drive.title_ta,
        title_en=drive.title_en,
        description_ta=drive.description_ta,
        description_en=drive.description_en,
        drive_date=drive.drive_date,
        location_ta=drive.location_ta,
        location_en=drive.location_en,
        geography_id=drive.geography_id,
        target_count=drive.target_count,
        banner_url=drive.banner_url,
        created_by_user_id=drive.created_by_user_id,
        is_active=drive.is_active,
        tree_count=tree_count,
    )


# ---------------------------------------------------------------------------
# Drive endpoints
# ---------------------------------------------------------------------------

@router.get("/drives", response_model=List[DriveOut])
def list_drives(
    active_only: bool = False,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    List all plantation drives, newest first.
    Pass ?active_only=true to return only active drives.
    """
    query = db.query(PlantationDrive).filter(PlantationDrive.organization_id == tenant_id)
    if active_only:
        query = query.filter(PlantationDrive.is_active == True)
    drives = query.order_by(PlantationDrive.drive_date.desc()).all()
    return [_drive_out(d) for d in drives]


@router.get("/drives/{drive_id}", response_model=DriveOut)
def get_drive(
    drive_id: UUID,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """Retrieve a single plantation drive with its tree count, scoped to current tenant."""
    drive = db.query(PlantationDrive).filter(
        PlantationDrive.id == drive_id,
        PlantationDrive.organization_id == tenant_id,
    ).first()
    if not drive:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Drive not found")
    return _drive_out(drive)


@router.post("/drives", response_model=DriveOut, status_code=status.HTTP_201_CREATED)
def create_drive(
    payload: DriveCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    """Create a new plantation drive (EXECUTIVE_MEMBER, ADMIN, SUPER_ADMIN only)."""
    drive = PlantationDrive(
        organization_id=current_user.organization_id,
        title_ta=payload.title_ta,
        title_en=payload.title_en,
        description_ta=payload.description_ta,
        description_en=payload.description_en,
        drive_date=payload.drive_date,
        location_ta=payload.location_ta,
        location_en=payload.location_en,
        geography_id=payload.geography_id,
        target_count=payload.target_count,
        banner_url=payload.banner_url,
        created_by_user_id=current_user.id,
        is_active=payload.is_active,
    )
    db.add(drive)
    db.commit()
    db.refresh(drive)
    return _drive_out(drive)


@router.patch("/drives/{drive_id}", response_model=DriveOut)
def update_drive(
    drive_id: UUID,
    payload: DriveUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    """Update a plantation drive (EXECUTIVE_MEMBER, ADMIN, SUPER_ADMIN only)."""
    drive = db.query(PlantationDrive).filter(
        PlantationDrive.id == drive_id,
        PlantationDrive.organization_id == current_user.organization_id,
    ).first()
    if not drive:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Drive not found")

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(drive, field, value)

    db.commit()
    db.refresh(drive)
    return _drive_out(drive)


# ---------------------------------------------------------------------------
# Tree endpoints
# ---------------------------------------------------------------------------

@router.get("/trees", response_model=List[TreeOut])
def list_trees(
    drive_id: Optional[UUID] = None,
    status: Optional[TreeStatus] = None,
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    List all registered trees.
    Optionally filter by ?drive_id= and/or ?status=.
    """
    query = db.query(TreeRegistration).filter(TreeRegistration.organization_id == tenant_id)
    if drive_id is not None:
        query = query.filter(TreeRegistration.drive_id == drive_id)
    if status is not None:
        query = query.filter(TreeRegistration.status == status)
    trees = query.order_by(TreeRegistration.planted_date.desc()).all()
    return trees


@router.get("/stats", response_model=Dict[str, Any])
def get_stats(
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Public statistics: total trees planted, breakdown by status, and drive count.
    Returns: total_planted, growing, mature, dead, drives_count.
    """
    tree_query = db.query(TreeRegistration).filter(TreeRegistration.organization_id == tenant_id)
    drive_query = db.query(PlantationDrive).filter(PlantationDrive.organization_id == tenant_id)

    all_trees = tree_query.all()
    drives_count = drive_query.count()

    status_counts: Dict[str, int] = {
        TreeStatus.PLANTED: 0,
        TreeStatus.GROWING: 0,
        TreeStatus.MATURE: 0,
        TreeStatus.DEAD: 0,
    }
    for tree in all_trees:
        status_counts[tree.status] = status_counts.get(tree.status, 0) + 1

    return {
        "total_planted": len(all_trees),
        "growing": status_counts[TreeStatus.GROWING],
        "mature": status_counts[TreeStatus.MATURE],
        "dead": status_counts[TreeStatus.DEAD],
        "drives_count": drives_count,
    }


@router.post("/trees", response_model=TreeOut, status_code=status.HTTP_201_CREATED)
def register_tree(
    payload: TreeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Register a new tree (any authenticated user)."""
    if payload.drive_id is not None:
        drive = db.query(PlantationDrive).filter(
            PlantationDrive.id == payload.drive_id,
            PlantationDrive.organization_id == current_user.organization_id,
        ).first()
        if not drive:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Plantation drive not found",
            )

    tree = TreeRegistration(
        organization_id=current_user.organization_id,
        drive_id=payload.drive_id,
        registered_by_user_id=current_user.id,
        species_ta=payload.species_ta,
        species_en=payload.species_en,
        latitude=payload.latitude,
        longitude=payload.longitude,
        geography_id=payload.geography_id,
        planted_date=payload.planted_date,
        photo_url=payload.photo_url,
        notes=payload.notes,
        status=TreeStatus.PLANTED,
    )
    db.add(tree)
    db.commit()
    db.refresh(tree)
    return tree


@router.patch("/trees/{tree_id}/growth", response_model=TreeOut)
def update_tree_growth(
    tree_id: UUID,
    payload: TreeGrowthUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Update the growth photo and status of a tree.
    The original registrant or an ADMIN/SUPER_ADMIN may update.
    """
    tree = db.query(TreeRegistration).filter(
        TreeRegistration.id == tree_id,
        TreeRegistration.organization_id == current_user.organization_id,
    ).first()
    if not tree:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tree not found")

    is_owner = tree.registered_by_user_id == current_user.id
    is_privileged = current_user.role in ("ADMIN", "SUPER_ADMIN")
    if not is_owner and not is_privileged:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the registrant or an admin may update this tree.",
        )

    tree.growth_photo_url = payload.growth_photo_url
    tree.status = payload.status
    db.commit()
    db.refresh(tree)
    return tree
