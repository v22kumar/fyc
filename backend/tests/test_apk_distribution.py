"""Which APK the club hands out, and why it must be exactly one.

Play re-signs an app bundle with its own key, so the APK a member downloads
from the Play Store and the one CI builds carry **different signatures**.
Android will not let one replace the other.

That makes this a trap rather than a preference: the website's download button
and the in-app updater used to resolve the URL independently. Point the website
at the Play-signed APK — which is exactly what the club asked for — and a member
would install happily, then be permanently unable to update, because the updater
was still handing out the CI build. The app would nag for a version it could not
install, which is the same shape as the bug that locked the club out once
already.
"""
from app.core.config import settings
from app.routers.app_meta import _CANONICAL_APK, _distributed_apk


_PLAY_APK = "https://fycconnect.com/downloads/fyc-connect-play-signed.apk"
_CI_APK = "https://github.com/v22kumar/fyc/releases/download/app-latest/x.apk"


def test_the_ci_build_is_what_ships_by_default(monkeypatch):
    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", "", raising=False)
    monkeypatch.setattr(settings, "APP_APK_URL", "", raising=False)
    assert _distributed_apk({"apk_url": _CI_APK}) == _CI_APK


def test_setting_one_url_switches_both_the_website_and_the_updater(monkeypatch):
    """The whole reason this resolver exists.

    Both callers ask the same function, so the download and the update can
    never end up on opposite sides of a signature boundary.
    """
    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", _PLAY_APK, raising=False)
    # Even with a perfectly good CI URL in the release metadata.
    assert _distributed_apk({"apk_url": _CI_APK}) == _PLAY_APK


def test_a_stale_setting_cannot_resurrect_a_removed_asset(monkeypatch):
    """fyc-connect-latest.apk was deleted when the build went split-per-ABI."""
    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", "", raising=False)
    monkeypatch.setattr(
        settings, "APP_APK_URL",
        "https://github.com/v22kumar/fyc/releases/download/app-latest/fyc-connect-latest.apk",
        raising=False)
    assert _distributed_apk({}) == _CANONICAL_APK


def test_with_nothing_configured_there_is_still_an_answer(monkeypatch):
    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", "", raising=False)
    monkeypatch.setattr(settings, "APP_APK_URL", "", raising=False)
    assert _distributed_apk({}) == _CANONICAL_APK


def test_the_download_and_the_updater_never_disagree(client, monkeypatch):
    """Asserted end to end, because agreeing in a unit test is not the risk.

    The risk is somebody later adding a second way to resolve the URL in one of
    these two handlers.
    """
    from app.routers import app_meta

    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", _PLAY_APK, raising=False)
    # The endpoint now verifies the override before handing it out, so the
    # check is seeded as already-passed. Without this the test would exercise
    # the network — and prove the fallback rather than the agreement.
    app_meta._OVERRIDE_CHECK.update({"ts": 9e9, "ok": True, "url": _PLAY_APK})

    download = client.get("/api/v1/app/download", follow_redirects=False)
    assert download.status_code == 302
    assert download.headers["location"] == _PLAY_APK

    info = client.get("/api/v1/app/info").json()
    assert info["apk_url"] == _PLAY_APK, \
        "the updater must download exactly what the website handed out"
    app_meta._OVERRIDE_CHECK.update({"ts": 0.0, "ok": None, "url": ""})


def test_a_download_url_that_serves_nothing_is_not_handed_out(monkeypatch):
    """The mistake that broke the club's only download link.

    APK_DOWNLOAD_URL was set to an address copied from an example — it looked
    like a real one and nothing was hosted there, so every member who tapped
    Download got a 404. Nothing between the secret and the member checked.

    A misconfigured secret should cost the override, not the app.
    """
    from app.routers import app_meta

    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", _PLAY_APK, raising=False)
    # As if the reachability check has already run and failed.
    app_meta._OVERRIDE_CHECK.update({"ts": 9e9, "ok": False, "url": _PLAY_APK})
    try:
        assert _distributed_apk({}) == _CANONICAL_APK, \
            "a link that serves nothing must never be what the club hands out"
    finally:
        app_meta._OVERRIDE_CHECK.update({"ts": 0.0, "ok": None, "url": ""})


def test_a_reachable_url_is_used(monkeypatch):
    from app.routers import app_meta

    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", _PLAY_APK, raising=False)
    app_meta._OVERRIDE_CHECK.update({"ts": 9e9, "ok": True, "url": _PLAY_APK})
    try:
        assert _distributed_apk({}) == _PLAY_APK
    finally:
        app_meta._OVERRIDE_CHECK.update({"ts": 0.0, "ok": None, "url": ""})


def test_the_fallback_reaches_the_member_not_just_the_resolver(client, monkeypatch):
    """End to end: a broken override must still yield a working download."""
    from app.routers import app_meta

    monkeypatch.setattr(settings, "APK_DOWNLOAD_URL", _PLAY_APK, raising=False)
    app_meta._OVERRIDE_CHECK.update({"ts": 9e9, "ok": False, "url": _PLAY_APK})
    try:
        r = client.get("/api/v1/app/download", follow_redirects=False)
        assert r.status_code == 302
        assert r.headers["location"] == _CANONICAL_APK
        assert client.get("/api/v1/app/info").json()["apk_url"] == _CANONICAL_APK
    finally:
        app_meta._OVERRIDE_CHECK.update({"ts": 0.0, "ok": None, "url": ""})
