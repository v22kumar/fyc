from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse

from app.core.config import settings

router = APIRouter(prefix="/app", tags=["App"])

# Canonical, always-present release asset (published by flutter-build.yml).
# The split-per-ABI build no longer produces a single "latest" fat APK.
_CANONICAL_APK = (
    "https://github.com/v22kumar/fyc/releases/download/app-latest/fyc-connect-arm64.apk"
)


@router.get("/download")
def download_app():
    """302 redirect to the latest FYC Connect Android APK (arm64)."""
    url = settings.APP_APK_URL or _CANONICAL_APK
    # Self-heal: an older APP_APK_URL may still point at the removed
    # fyc-connect-latest.apk (which 404s) — fall back to the canonical asset.
    if not url or "fyc-connect-latest.apk" in url:
        url = _CANONICAL_APK
    return RedirectResponse(url=url, status_code=302)


@router.get("/info")
def app_info():
    """Returns basic metadata about the Android app download."""
    return {
        "name": "FYC Connect",
        "platform": "Android",
        "package": "com.friendsyouthclub.fycconnect",
        "available": bool(settings.APP_APK_URL),
        "download_url": settings.APP_APK_URL or None,
    }
