import io
import logging
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse
from fastapi.concurrency import run_in_threadpool

from app.dependencies import get_current_user
from app.models.user import User
from app.middleware.tenant import require_tenant_id
from app.core.config import settings
from uuid import UUID

logger = logging.getLogger(__name__)

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


def _looks_like_image(content: bytes) -> bool:
    """The first bytes are the file's own statement of what it is — the
    Content-Type header is only the client's claim. Accepts exactly the
    formats in ALLOWED_TYPES: JPEG, PNG, WebP, GIF, MP4/QuickTime."""
    if len(content) < 12:
        return False
    return (
        content[:3] == b"\xff\xd8\xff"                        # JPEG
        or content[:4] == b"\x89PNG"                           # PNG
        or content[:4] == b"GIF8"                              # GIF
        or (content[:4] == b"RIFF" and content[8:12] == b"WEBP")  # WebP
        or content[4:8] == b"ftyp"                             # MP4 / QuickTime
    )


def _cloudinary_configured() -> bool:
    """Return True if Cloudinary credentials are set and the library is installed."""
    return (
        _CLOUDINARY_AVAILABLE
        and bool(settings.CLOUDINARY_CLOUD_NAME)
        and bool(settings.CLOUDINARY_API_KEY)
        and bool(settings.CLOUDINARY_API_SECRET)
    )


def storage_status() -> dict:
    """Where photos are being written, and whether they will still be there
    tomorrow.

    Worth reporting because the failure it describes is completely silent. The
    upload succeeds, the URL is stored, the photo displays — and then a deploy
    replaces the container and every one of those URLs 404s, with nothing in any
    log to connect the two events weeks apart.

    `library_installed` is broken out on purpose: it was the missing half. The
    three secrets can all be set correctly and still be ignored if `cloudinary`
    is not in requirements.txt, which is exactly what happened.
    """
    durable = _cloudinary_configured()
    return {
        "backend": "cloudinary" if durable else "local_disk",
        # The whole point. False means uploads are being written to a filesystem
        # that a deploy throws away.
        "survives_a_deploy": durable,
        "library_installed": _CLOUDINARY_AVAILABLE,
        "credentials_set": bool(
            settings.CLOUDINARY_CLOUD_NAME
            and settings.CLOUDINARY_API_KEY
            and settings.CLOUDINARY_API_SECRET
        ),
        "environment": settings.ENVIRONMENT,
    }


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

    # Read in bounded chunks and stop the moment the limit is crossed — the
    # old `await file.read()` buffered the entire body into RAM *before*
    # checking, so the size limit protected the disk but not the memory of
    # the single machine serving everyone.
    max_bytes = MAX_SIZE_MB * 1024 * 1024
    chunks: list[bytes] = []
    received = 0
    while True:
        chunk = await file.read(1024 * 1024)
        if not chunk:
            break
        received += len(chunk)
        if received > max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File exceeds the {MAX_SIZE_MB} MB limit.",
            )
        chunks.append(chunk)
    content = b"".join(chunks)

    # The Content-Type header is the client's claim; the first bytes are the
    # file's own. JPEG/PNG/WebP/GIF all declare themselves up front.
    if not _looks_like_image(content):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="The file does not look like a JPEG, PNG, WebP or GIF image.",
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

        # The Cloudinary upload is a blocking, multi-second HTTP call — run it in
        # a worker thread so it never stalls the event loop (and every other
        # request/live-score stream) for the duration of the CDN round-trip.
        result = await run_in_threadpool(
            cloudinary.uploader.upload,
            io.BytesIO(content),
            folder=f"fyc/{org_id}",
            public_id=uuid.uuid4().hex,
            resource_type="auto",
        )

        secure_url: str = result["secure_url"]
        filename: str = result.get("original_filename", public_id)
        return {"url": secure_url, "filename": filename}

    # ── Local disk fallback (development) ──────────────────────────────────
    # In production this path means the photo is already lost — it just hasn't
    # happened yet. The container filesystem is not the mounted volume, so the
    # next deploy removes it and leaves a dead URL in the database. Say so at
    # the moment it happens, with the org, so the damage can be traced later.
    if settings.is_production:
        logger.error(
            "[media] wrote an upload to ephemeral container disk — it will be "
            "lost on the next deploy. Configure Cloudinary. org=%s",
            current_user.organization_id,
        )

    ext = Path(file.filename or "upload.jpg").suffix or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"

    org_dir = UPLOAD_DIR / org_id
    dest = org_dir / filename

    def _write_local():
        org_dir.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)

    await run_in_threadpool(_write_local)  # offload blocking disk I/O

    return {"url": f"/uploads/{org_id}/{filename}", "filename": filename}
