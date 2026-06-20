from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.cache import TTLCache
from app.core.database import get_db
from app.models.geography import GeographicNode, GeoLevel
from app.schemas.geography import GeographicNodeCreate, GeographicNodeOut
from app.dependencies import RoleChecker

router = APIRouter(prefix="/geography", tags=["Geography"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])

# Geography data is seeded once and changes only on explicit admin action.
# 24-hour TTL is conservative; real-world TTL could be much longer.
_geo_list_cache = TTLCache(ttl_seconds=86400, maxsize=128)
_geo_node_cache = TTLCache(ttl_seconds=86400, maxsize=512)

_GEO_CC = "public, max-age=86400, stale-while-revalidate=604800"


@router.get("", response_model=List[GeographicNodeOut])
def list_nodes(
    parent_id: Optional[UUID] = None,
    level: Optional[GeoLevel] = None,
    response: Response = None,
    db: Session = Depends(get_db),
):
    """
    List geographic nodes. Filter by parent_id to get children of a node,
    or by level (e.g., DISTRICT) to get all districts. Cached 24 hours.
    """
    key = (str(parent_id), str(level))
    hit, cached = _geo_list_cache.get(key)
    if hit:
        if response is not None:
            response.headers["Cache-Control"] = _GEO_CC
        return cached

    query = db.query(GeographicNode)
    if parent_id is not None:
        query = query.filter(GeographicNode.parent_id == parent_id)
    if level is not None:
        query = query.filter(GeographicNode.level == level)
    result = query.all()
    _geo_list_cache.set(key, result)

    if response is not None:
        response.headers["Cache-Control"] = _GEO_CC
    return result


@router.get("/{node_id}", response_model=GeographicNodeOut)
def get_node(node_id: UUID, response: Response = None, db: Session = Depends(get_db)):
    """Get a single geographic node by ID. Cached 24 hours."""
    hit, cached = _geo_node_cache.get(node_id)
    if hit:
        if response is not None:
            response.headers["Cache-Control"] = _GEO_CC
        return cached

    node = db.query(GeographicNode).filter(GeographicNode.id == node_id).first()
    if not node:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Geographic node not found")

    _geo_node_cache.set(node_id, node)
    if response is not None:
        response.headers["Cache-Control"] = _GEO_CC
    return node


@router.post("", response_model=GeographicNodeOut, status_code=status.HTTP_201_CREATED)
def create_node(
    payload: GeographicNodeCreate,
    db: Session = Depends(get_db),
    _: object = Depends(require_admin),
):
    """Add a new geographic node (Admin/Super Admin only). Clears the list cache."""
    if payload.parent_id:
        parent = db.query(GeographicNode).filter(GeographicNode.id == payload.parent_id).first()
        if not parent:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Parent node not found")

    node = GeographicNode(**payload.model_dump())
    db.add(node)
    db.commit()
    db.refresh(node)

    # New node invalidates all list queries that may have excluded it
    _geo_list_cache.invalidate()
    return node
