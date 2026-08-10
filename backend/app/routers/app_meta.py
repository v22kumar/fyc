import logging
import time

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse

from app.core.config import settings

logger = logging.getLogger(__name__)
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


_OVERRIDE_CHECK: dict = {"ts": 0.0, "ok": None, "url": ""}
_OVERRIDE_RECHECK_SECONDS = 300


async def _override_is_real(url: str) -> bool:
    """Does APK_DOWNLOAD_URL actually serve a file?

    Added because it did not, and the club's only download link 404'd for
    everybody until somebody noticed. The setting was pasted from an example
    that looked like a real address, which is exactly the mistake a placeholder
    invites — and nothing between the secret and the member checked.

    A misconfigured secret should cost the club the *override*, not the app. So
    the URL is verified before it is handed out, cached for five minutes so the
    check costs one request per interval rather than one per download, and a
    failure falls back to the build that is known to exist.
    """
    now = time.time()
    if (_OVERRIDE_CHECK["url"] == url
            and _OVERRIDE_CHECK["ok"] is not None
            and now - _OVERRIDE_CHECK["ts"] < _OVERRIDE_RECHECK_SECONDS):
        return bool(_OVERRIDE_CHECK["ok"])

    ok = False
    try:
        async with httpx.AsyncClient() as client:
            r = await client.head(url, timeout=4.0, follow_redirects=True)
            # Some hosts refuse HEAD; a ranged GET settles it without pulling
            # ninety megabytes to answer a yes/no question.
            if r.status_code >= 400:
                r = await client.get(url, timeout=4.0, follow_redirects=True,
                                     headers={"Range": "bytes=0-0"})
            ok = r.status_code < 400
    except Exception:
        ok = False

    _OVERRIDE_CHECK.update({"ts": now, "ok": ok, "url": url})
    if not ok:
        logger.warning(
            "[app] APK_DOWNLOAD_URL does not serve a file; falling back")
    return ok


def _distributed_apk(release: dict) -> str:
    """The single APK this club hands out, resolved the same way everywhere.

    Both the website's download button and the in-app updater call this. That
    is the whole point of it existing: Play re-signs an app bundle with its own
    key, so a Play-signed APK and a CI-signed one **cannot replace each other**.
    If the two endpoints resolved the URL independently — as they did — the
    club could serve one from the website and the other from the updater, and a
    member would install happily and then be permanently unable to update.
    Android refuses the swap, and the app nags for a version it cannot install.

    APK_DOWNLOAD_URL wins when set: that is the deliberate choice to distribute
    the Play-signed universal APK instead of the CI build.
    """
    if settings.APK_DOWNLOAD_URL and _OVERRIDE_CHECK.get("ok") is not False:
        return settings.APK_DOWNLOAD_URL
    url = release.get("apk_url") or settings.APP_APK_URL or _CANONICAL_APK
    # Self-heal: an older APP_APK_URL may still point at the removed
    # fyc-connect-latest.apk (which 404s) — fall back to the canonical asset.
    if not url or "fyc-connect-latest.apk" in url:
        url = _CANONICAL_APK
    return url


@router.get("/download")
async def download_app():
    """302 redirect to the latest FYC Connect Android APK (arm64)."""
    rel = await _release_version() or {}
    if settings.APK_DOWNLOAD_URL:
        await _override_is_real(settings.APK_DOWNLOAD_URL)
    return RedirectResponse(url=_distributed_apk(rel), status_code=302)


@router.get("/info")
async def app_info():
    """Metadata for the in-app updater: latest version + APK URL.

    The app compares its own build number to latest_version_code and, if older,
    offers an update that downloads apk_url. The GitHub Release's version.json
    is the primary source of truth; Fly settings are a fallback so the endpoint
    still works if the release can't be reached.
    """
    rel = await _release_version() or {}
    if settings.APK_DOWNLOAD_URL:
        await _override_is_real(settings.APK_DOWNLOAD_URL)

    latest_code = rel.get("version_code")
    if not isinstance(latest_code, int):
        latest_code = settings.APP_LATEST_VERSION_CODE

    latest_name = rel.get("version_name") or settings.APP_LATEST_VERSION_NAME

    # The same artifact the website hands out — see _distributed_apk. Two
    # different signatures across these two endpoints is an app that installs
    # and can never update.
    apk_url = _distributed_apk(rel)

    mandatory = rel.get("mandatory")
    if not isinstance(mandatory, bool):
        mandatory = settings.APP_UPDATE_MANDATORY

    # The floor, not the ceiling.
    #
    # "There is a newer version" and "this version can no longer run" are
    # different facts, and conflating them is what locked the club out: every
    # build shipped mandatory=true, so the app demanded a version the Play
    # Store had not finished reviewing, and the only button led to a page with
    # no Update on it.
    #
    # A client blocks only when it is below this floor — which moves when a
    # breaking API change or a security fix genuinely makes an old build
    # unusable, not on every green pipeline.
    min_supported = rel.get("min_supported_version_name") or "0.0.0"

    notes = rel.get("notes") or settings.APP_UPDATE_NOTES

    return {
        "name": "FYC Connect",
        "platform": "Android",
        # The real applicationId, from mobile/android/app/build.gradle.kts.
        # This said `com.friendsyouthclub.fycconnect`, which is not the
        # package of any app that has ever shipped — a wrong answer in the
        # one endpoint whose job is to say what the app is.
        "package": "com.fycconnect.app",
        "available": True,
        "download_url": apk_url,
        "apk_url": apk_url,
        "latest_version_code": latest_code,
        "latest_version_name": latest_name,
        "mandatory": mandatory,
        # Clients decide blocking from this, not from `mandatory`. Kept
        # alongside it so an old client that only understands `mandatory`
        # keeps working — and since that flag now defaults to false, an old
        # client stops blocking too, which is the behaviour we want.
        "min_supported_version_name": min_supported,
        "notes": notes,
    }
