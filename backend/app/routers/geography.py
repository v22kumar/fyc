from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.geography import GeographicNode, GeoLevel
from app.schemas.geography import GeographicNodeCreate, GeographicNodeOut
from app.dependencies import RoleChecker

router = APIRouter(prefix="/geography", tags=["Geography"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])

@router.get("", response_model=List[GeographicNodeOut])
def list_nodes(
    parent_id: Optional[UUID] = None,
    level: Optional[GeoLevel] = None,
    db: Session = Depends(get_db)
):
    """
    List geographic nodes. Filter by parent_id to get children of a node,
    or by level (e.g., DISTRICT) to get all districts.
    """
    query = db.query(GeographicNode)
    if parent_id is not None:
        query = query.filter(GeographicNode.parent_id == parent_id)
    if level is not None:
        query = query.filter(GeographicNode.level == level)
    return query.all()

@router.get("/{node_id}", response_model=GeographicNodeOut)
def get_node(node_id: UUID, db: Session = Depends(get_db)):
    """Get a single geographic node by ID."""
    node = db.query(GeographicNode).filter(GeographicNode.id == node_id).first()
    if not node:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Geographic node not found")
    return node

@router.post("", response_model=GeographicNodeOut, status_code=status.HTTP_201_CREATED)
def create_node(
    payload: GeographicNodeCreate,
    db: Session = Depends(get_db),
    _: object = Depends(require_admin)
):
    """Add a new geographic node (Admin/Super Admin only)."""
    if payload.parent_id:
        parent = db.query(GeographicNode).filter(GeographicNode.id == payload.parent_id).first()
        if not parent:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Parent node not found")

    node = GeographicNode(**payload.model_dump())
    db.add(node)
    db.commit()
    db.refresh(node)
    return node
