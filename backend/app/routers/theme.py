from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.platform_settings import OrganizationSettings

router = APIRouter()

DEFAULT_THEME = {
    "version": 1,
    "theme": "default",
    "colors": {
        "primary": "#0F766E",
        "secondary": "#64748B",
        "success": "#22C55E",
        "warning": "#F59E0B",
        "danger": "#EF4444",
        "info": "#3B82F6",
        "background": "#FFFFFF",
        "surface": "#F8FAFC",
        "textPrimary": "#111827",
        "textSecondary": "#6B7280",
        "border": "#E5E7EB",
        "divider": "#F1F5F9"
    }
}

@router.get("/theme")
def get_theme(request: Request, db: Session = Depends(get_db)):
    org_id_str = request.headers.get("X-Organization-ID")
    
    if org_id_str:
        # Check if the organization has custom theme settings
        settings = db.query(OrganizationSettings).filter(
            OrganizationSettings.organization_id == org_id_str
        ).first()
        
        if settings and settings.theme_colors_json:
            return settings.theme_colors_json
            
    return DEFAULT_THEME

from fastapi import HTTPException
from app.dependencies import RoleChecker

@router.put("/theme")
def update_theme(
    request: Request, 
    payload: dict, 
    db: Session = Depends(get_db), 
    current_user=Depends(RoleChecker(["SUPER_ADMIN"]))
):
    org_id_str = request.headers.get("X-Organization-ID")
    if not org_id_str:
        raise HTTPException(status_code=400, detail="Missing X-Organization-ID")
        
    settings = db.query(OrganizationSettings).filter(
        OrganizationSettings.organization_id == org_id_str
    ).first()
    
    if not settings:
        settings = OrganizationSettings(organization_id=org_id_str)
        db.add(settings)
    
    # Store the entire payload as the theme dictionary
    settings.theme_colors_json = payload
    db.commit()
    db.refresh(settings)
    
    return settings.theme_colors_json
