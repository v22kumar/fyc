from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.database import get_db
from app.dependencies import RoleChecker
from app.models.user import User
import psutil
import os

router = APIRouter(prefix="/system", tags=["System & Health"])

# Both endpoints expose infrastructure internals / cross-table data — admin only.
require_admin = RoleChecker(["ADMIN", "SUPER_ADMIN"])


@router.get("/health")
def system_health(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Comprehensive system health check for Admins & DevOps.
    (Public liveness probe is GET /api/health — this one is admin-gated as it
    exposes DB/storage/CPU/memory internals.)
    """
    health_status = {
        "status": "healthy",
        "api_version": "1.0.0",
        "database": "unknown",
        "storage": "unknown",
        "background_jobs": "operational",
        "system_metrics": {}
    }
    
    # Check Database
    try:
        db.execute(text("SELECT 1"))
        health_status["database"] = "connected"
    except Exception as e:
        health_status["database"] = "disconnected"
        health_status["status"] = "degraded"
        
    # Check Storage
    try:
        # Check if uploads directory is writable
        upload_dir = "uploads"
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir, exist_ok=True)
        if os.access(upload_dir, os.W_OK):
            health_status["storage"] = "writable"
        else:
            health_status["storage"] = "read-only"
            health_status["status"] = "degraded"
    except Exception:
        health_status["storage"] = "error"
        health_status["status"] = "degraded"
        
    # Basic system metrics (memory, cpu)
    try:
        health_status["system_metrics"] = {
            "cpu_percent": psutil.cpu_percent(),
            "memory_percent": psutil.virtual_memory().percent
        }
    except Exception:
        pass
        
    return health_status

from fastapi.responses import StreamingResponse
import io
import csv

@router.get("/export/{entity_type}")
def export_data(
    entity_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Generic Data Export Endpoint (admin only).
    Generates CSV files for members, events, tournaments — scoped to the
    caller's own organization to prevent cross-tenant data exposure.
    """
    from app.models.event import Event
    from app.models.sports import Tournament

    org_id = current_user.organization_id
    output = io.StringIO()
    writer = csv.writer(output)

    if entity_type.upper() == "USERS":
        writer.writerow(["ID", "Phone", "Role", "Language", "Verified"])
        users = db.query(User).filter(User.organization_id == org_id).all()
        for u in users:
            writer.writerow([str(u.id), u.phone_number, u.role, u.preferred_language, u.is_verified])

    elif entity_type.upper() == "EVENTS":
        writer.writerow(["ID", "Title", "Start Date", "Status"])
        events = db.query(Event).filter(Event.organization_id == org_id).all()
        for e in events:
            writer.writerow([str(e.id), e.title_en, e.event_start, "Published" if e.is_published else "Draft"])

    elif entity_type.upper() == "TOURNAMENTS":
        writer.writerow(["ID", "Name", "Sport", "Status"])
        tournaments = db.query(Tournament).filter(Tournament.organization_id == org_id).all()
        for t in tournaments:
            writer.writerow([str(t.id), t.name_en, t.sport, t.status])
            
    else:
        writer.writerow(["Error"])
        writer.writerow([f"Export for {entity_type} is not yet supported."])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={entity_type.lower()}_export.csv"}
    )
