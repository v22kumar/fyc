from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text, func
from app.core.database import get_db
from app.dependencies import RoleChecker
from app.middleware.tenant import require_tenant_id
from app.models.user import User
import psutil
import os

router = APIRouter(prefix="/system", tags=["System & Health"])


@router.get("/impact-stats")
def impact_stats(db: Session = Depends(get_db), tenant_id=Depends(require_tenant_id)):
    """Public: real community-impact counts for the marketing homepage.

    Every figure is a live COUNT of actual rows for this tenant — no hardcoded
    numbers. Each count is guarded so a missing/!-yet-created table can never
    500 the public homepage; it just contributes 0.
    """
    from app.models.blood_donor import BloodDonor
    from app.models.event import Event
    from app.models.green_fyc import TreeRegistration

    def _count(model, *filters) -> int:
        try:
            q = db.query(func.count(model.id)).filter(model.organization_id == tenant_id)
            for f in filters:
                q = q.filter(f)
            return int(q.scalar() or 0)
        except Exception:
            return 0

    return {
        "trees": _count(TreeRegistration),
        "blood_donors": _count(BloodDonor),
        "events": _count(Event, Event.status != "deleted"),
        "members": _count(User),
    }

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
    
    # Check Database — report the actual backend so prod can be confirmed as
    # PostgreSQL (vs a silent SQLite fallback).
    try:
        db.execute(text("SELECT 1"))
        health_status["database"] = "connected"
        try:
            health_status["db_dialect"] = db.bind.dialect.name  # 'postgresql' / 'sqlite'
        except Exception:
            health_status["db_dialect"] = "unknown"
    except Exception as e:
        health_status["database"] = "disconnected"
        health_status["status"] = "degraded"

    # Check cache backend — connected Valkey/Redis vs the in-memory fallback.
    try:
        from app.core.livecache import _client
        _r = _client()
        if _r is not None:
            _r.ping()
            health_status["cache"] = "valkey/redis connected"
        else:
            health_status["cache"] = "in-memory fallback (no VALKEY_URL/REDIS_URL)"
    except Exception as _ce:
        health_status["cache"] = f"error: {str(_ce)[:80]}"

    # Live chess load — active in-memory game sessions + spectators (lets a load
    # test confirm the server actually holds the games it is driving).
    try:
        from app.services.chess_ws_manager import ws_manager
        _sessions = list(ws_manager._sessions.values())
        health_status["chess"] = {
            "active_sessions": len(_sessions),
            "connected_players": sum(len(s.connections) for s in _sessions),
            "spectators": sum(len(s.spectators) for s in _sessions),
            "paused_games": sum(1 for s in _sessions if getattr(s, "paused", False)),
        }
    except Exception:
        pass

    # Auth providers — report whether the login channels are actually configured
    # on THIS running instance. A missing/shadowed secret is the usual cause of
    # "Google/OTP down": if these are false in prod, set the Fly secrets. (Only
    # booleans — never echo the secret values.)
    try:
        from app.core.config import settings as _s
        health_status["auth"] = {
            "google": bool(_s.GOOGLE_CLIENT_ID or _s.GOOGLE_WEB_CLIENT_ID),
            "twilio_account": bool(_s.TWILIO_ACCOUNT_SID and _s.TWILIO_AUTH_TOKEN),
            "twilio_verify": bool(_s.TWILIO_VERIFY_SID),
            "smtp_email": bool(_s.SMTP_USER and _s.SMTP_PASSWORD),
        }
    except Exception:
        pass

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
        
    # System metrics — host cpu/mem plus this process's RSS (absolute MB), so a
    # load test can chart the server's CPU/memory while it drives games.
    try:
        _vm = psutil.virtual_memory()
        _proc = psutil.Process()
        health_status["system_metrics"] = {
            "cpu_percent": psutil.cpu_percent(),
            "memory_percent": _vm.percent,
            "memory_used_mb": round(_vm.used / (1024 * 1024), 1),
            "memory_total_mb": round(_vm.total / (1024 * 1024), 1),
            "process_rss_mb": round(_proc.memory_info().rss / (1024 * 1024), 1),
            "process_cpu_percent": _proc.cpu_percent(),
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
