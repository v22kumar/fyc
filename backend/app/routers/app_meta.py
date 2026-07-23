import time

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse

from app.core.config import settings

router = APIRouter(prefix="/app", tags=["App"])

# Canonical, always-present release asset (published by flutter-build.yml).
# The split-per-ABI build no longer produces a single "latest" fat APK.
_CANONICAL_APK = (
    "https://github.com/v22kumar/fyc/releases/download/app-latest/fyc-connect-arm64.apk"
)

# version.json is uploaded to the rolling "app-latest" GitHub Release on EVERY
# successful build (via GITHUB_TOKEN — no Fly dependency). It is the reliable
# source of truth for the in-app updater: it can't silently go stale the way a
# Fly secret can when FLY_API_TOKEN is missing or rotated.
_VERSION_JSON_URL = (
    "https://github.com/v22kumar/fyc/releases/download/app-latest/version.json"
)
_version_cache: dict = {"ts": 0.0, "data": None}


async def _release_version() -> dict | None:
    """Fetch version.json from the GitHub Release, cached for 5 minutes.

    Returns the last cached copy on a network hiccup, or None if it has never
    been fetched (callers then fall back to settings/defaults).
    """
    now = time.time()
    if _version_cache["data"] is not None and now - _version_cache["ts"] < 300:
        return _version_cache["data"]
    try:
        async with httpx.AsyncClient() as client:
            r = await client.get(_VERSION_JSON_URL, timeout=6.0, follow_redirects=True)
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, dict):
                _version_cache["data"] = data
                _version_cache["ts"] = now
                return data
    except Exception:
        pass
    return _version_cache["data"]


@router.get("/download")
async def download_app():
    """302 redirect to the latest FYC Connect Android APK (arm64)."""
    rel = await _release_version() or {}
    url = rel.get("apk_url") or settings.APP_APK_URL or _CANONICAL_APK
    # Self-heal: an older APP_APK_URL may still point at the removed
    # fyc-connect-latest.apk (which 404s) — fall back to the canonical asset.
    if not url or "fyc-connect-latest.apk" in url:
        url = _CANONICAL_APK
    return RedirectResponse(url=url, status_code=302)


@router.get("/info")
async def app_info():
    """Metadata for the in-app updater: latest version + APK URL.

    The app compares its own build number to latest_version_code and, if older,
    offers an update that downloads apk_url. The GitHub Release's version.json
    is the primary source of truth; Fly settings are a fallback so the endpoint
    still works if the release can't be reached.
    """
    rel = await _release_version() or {}

    latest_code = rel.get("version_code")
    if not isinstance(latest_code, int):
        latest_code = settings.APP_LATEST_VERSION_CODE

    latest_name = rel.get("version_name") or settings.APP_LATEST_VERSION_NAME

    apk_url = rel.get("apk_url") or settings.APP_APK_URL or _CANONICAL_APK
    if "fyc-connect-latest.apk" in apk_url:
        apk_url = _CANONICAL_APK

    mandatory = rel.get("mandatory")
    if not isinstance(mandatory, bool):
        mandatory = settings.APP_UPDATE_MANDATORY

    notes = rel.get("notes") or settings.APP_UPDATE_NOTES

    return {
        "name": "FYC Connect",
        "platform": "Android",
        "package": "com.friendsyouthclub.fycconnect",
        "available": True,
        "download_url": apk_url,
        "apk_url": apk_url,
        "latest_version_code": latest_code,
        "latest_version_name": latest_name,
        "mandatory": mandatory,
        "notes": notes,
    }
