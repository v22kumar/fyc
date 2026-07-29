from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.platform_settings import OrganizationSettings

router = APIRouter()

DEFAULT_THEME = {
  "meta": {
    "version": 2,
    "etag": "v2-20260729",
    "cacheHours": 24
  },
  "theme": {
    "id": "default",
    "name": "FYC Green",
    "mode": "light"
  },
  "colors": {
    "primary": "#0F766E",
    "primaryContainer": "#CCFBF1",
    "secondary": "#64748B",
    "secondaryContainer": "#E2E8F0",
    "success": "#22C55E",
    "warning": "#F59E0B",
    "danger": "#EF4444",
    "info": "#3B82F6",
    "background": "#FFFFFF",
    "surface": "#F8FAFC",
    "surfaceVariant": "#F1F5F9",
    "textPrimary": "#111827",
    "textSecondary": "#6B7280",
    "textDisabled": "#9CA3AF",
    "border": "#E5E7EB",
    "divider": "#F1F5F9"
  },
  "featureColors": {
    "bloodDonation": "#DC2626",
    "sports": "#2563EB",
    "education": "#7C3AED",
    "jobs": "#059669",
    "events": "#EA580C",
    "volunteer": "#0EA5E9",
    "health": "#EC4899",
    "government": "#475569"
  },
  "radius": {
    "xs": 6,
    "sm": 10,
    "md": 14,
    "lg": 18,
    "xl": 24
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 16,
    "lg": 24,
    "xl": 32
  },
  "typography": {
    "fontFamily": "Inter",
    "headlineWeight": 700,
    "titleWeight": 600,
    "bodyWeight": 400
  },
  "components": {
    "button": {
      "radius": "lg",
      "height": 52
    },
    "card": {
      "radius": "lg",
      "elevation": 2
    },
    "input": {
      "radius": "md",
      "borderWidth": 1
    },
    "appBar": {
      "transparent": False,
      "elevation": 0
    }
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
