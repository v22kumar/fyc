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
    """Metadata for the in-app updater: latest version + APK URL.

    The app compares its own build number to latest_version_code and, if older,
    offers a one-tap update that downloads apk_url.
    """
    apk_url = settings.APP_APK_URL or _CANONICAL_APK
    if "fyc-connect-latest.apk" in apk_url:
        apk_url = _CANONICAL_APK
    return {
        "name": "FYC Connect",
        "platform": "Android",
        "package": "com.friendsyouthclub.fycconnect",
        "available": True,
        "download_url": apk_url,
        "apk_url": apk_url,
        "latest_version_code": settings.APP_LATEST_VERSION_CODE,
        "latest_version_name": settings.APP_LATEST_VERSION_NAME,
        "mandatory": settings.APP_UPDATE_MANDATORY,
        "notes": settings.APP_UPDATE_NOTES,
    }
