import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse

from app.dependencies import get_current_user
from app.models.user import User
from app.middleware.tenant import require_tenant_id
from uuid import UUID

router = APIRouter(prefix="/media", tags=["Media"])

UPLOAD_DIR = Path("uploads")
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
MAX_SIZE_MB = 10


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    tenant_id: UUID = Depends(require_tenant_id),
):
    """
    Upload a photo. Files are isolated per organization.
    Returns a URL that can be stored in photo_url fields.
    In production, swap the local write for an S3 PutObject call.
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

    ext = Path(file.filename or "upload.jpg").suffix or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"

    # Isolate files per organization
    org_dir = UPLOAD_DIR / str(current_user.organization_id)
    org_dir.mkdir(parents=True, exist_ok=True)
    dest = org_dir / filename
    dest.write_bytes(content)

    return {"url": f"/uploads/{current_user.organization_id}/{filename}", "filename": filename}
