from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse

from app.core.config import settings

router = APIRouter(prefix="/app", tags=["App"])


@router.get("/download")
def download_app():
    """302 redirect to the latest FYC Connect Android APK.

    Set APP_APK_URL env var to the APK's public URL, e.g.:
        flyctl secrets set APP_APK_URL=https://fyc-backend.fly.dev/uploads/fyc-connect-latest.apk
    """
    if not settings.APP_APK_URL:
        raise HTTPException(
            status_code=404,
            detail="App download not yet available. Admin must set APP_APK_URL.",
        )
    return RedirectResponse(url=settings.APP_APK_URL, status_code=302)


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
