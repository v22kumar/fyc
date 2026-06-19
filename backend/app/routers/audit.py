from typing import List, Optional
from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel, ConfigDict

from app.core.database import get_db
from app.models.audit import AuditLog
from app.models.user import User
from app.dependencies import RoleChecker

router = APIRouter(prefix="/audit", tags=["Audit"])

require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


class AuditLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organization_id: UUID
    user_id: Optional[UUID]
    action_type: str
    target_table: str
    target_id: UUID
    old_values: Optional[dict]
    new_values: Optional[dict]
    ip_address: Optional[str]
    user_agent: Optional[str]
    created_at: datetime


@router.get("", response_model=List[AuditLogOut])
def list_audit_logs(
    action_type: Optional[str] = None,
    target_table: Optional[str] = None,
    limit: int = Query(default=50, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    List audit log entries for this organization (ADMIN/SUPER_ADMIN only).
    Supports filtering by action_type and target_table, and basic pagination.
    """
    query = db.query(AuditLog).filter(
        AuditLog.organization_id == current_user.organization_id
    )
    if action_type:
        query = query.filter(AuditLog.action_type == action_type.upper())
    if target_table:
        query = query.filter(AuditLog.target_table == target_table)

    logs = (
        query.order_by(AuditLog.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return logs
