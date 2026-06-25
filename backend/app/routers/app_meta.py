from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse

from app.core.config import settings

router = APIRouter(prefix="/app", tags=["App"])


@router.get("/download")
def download_app():
    """302 redirect to the latest FYC Connect Android APK."""
    # Always redirect to the uploads path where the APK should be
    url = settings.APP_APK_URL or "/uploads/fyc-connect-latest.apk"
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
