import uuid
import io
from pathlib import Path
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse

from app.dependencies import get_current_user
from app.models.user import User
from app.middleware.tenant import require_tenant_id
from app.core.config import settings
from uuid import UUID

# Attempt to import cloudinary; fall back gracefully if not installed.
try:
    import cloudinary
    import cloudinary.uploader
    _CLOUDINARY_AVAILABLE = True
except ImportError:
    _CLOUDINARY_AVAILABLE = False

router = APIRouter(prefix="/media", tags=["Media"])

UPLOAD_DIR = Path("uploads")
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif", "video/mp4", "video/quicktime"}
MAX_SIZE_MB = 20


def _cloudinary_configured() -> bool:
    """Return True if Cloudinary credentials are set and the library is installed."""
    return (
        _CLOUDINARY_AVAILABLE
        and bool(settings.CLOUDINARY_CLOUD_NAME)
        and bool(settings.CLOUDINARY_API_KEY)
        and bool(settings.CLOUDINARY_API_SECRET)
    )


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Upload a photo. Files are isolated per organization.
    Returns a URL that can be stored in photo_url fields.

    When CLOUDINARY_CLOUD_NAME is configured the file is uploaded to Cloudinary
    and the secure CDN URL is returned.  Otherwise the file is written to local
    disk (development fallback).
    """
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Only JPEG, PNG, WebP, and GIF images are accepted. Got: {file.content_type}",
        )

    content = await file.read()
    if len(content) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds the {MAX_SIZE_MB} MB limit.",
        )

    org_id = str(current_user.organization_id)

    if _cloudinary_configured():
        # Configure Cloudinary credentials (idempotent — safe to call on every request)
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
        )

        ext = Path(file.filename or "upload.jpg").suffix.lstrip(".") or "jpg"
        public_id = f"fyc/{org_id}/{uuid.uuid4().hex}"

        result = cloudinary.uploader.upload(
            io.BytesIO(content),
            folder=f"fyc/{org_id}",
            public_id=uuid.uuid4().hex,
            resource_type="auto",
        )

        secure_url: str = result["secure_url"]
        filename: str = result.get("original_filename", public_id)
        return {"url": secure_url, "filename": filename}

    # ── Local disk fallback (development) ──────────────────────────────────
    ext = Path(file.filename or "upload.jpg").suffix or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"

    org_dir = UPLOAD_DIR / org_id
    org_dir.mkdir(parents=True, exist_ok=True)
    dest = org_dir / filename
    dest.write_bytes(content)

    return {"url": f"/uploads/{org_id}/{filename}", "filename": filename}
