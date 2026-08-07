"""Uploads have to outlive a deploy.

They did not. `media.py` prefers Cloudinary and falls back to local disk "for
development", but `cloudinary` was never in requirements.txt — so the import
failed, the preference could never be taken, and production wrote every photo
to the container filesystem. Fly mounts its volume at /app/data; uploads go to
/app/uploads. Different directory. Every deploy took the gallery with it, and
nothing anywhere said so.

The dependency is the fix. These tests are the alarm that would have caught it:
one that the package is actually installed, and one that the app can be asked,
from outside, whether today's photos are being written somewhere permanent.
"""
import pytest

from app.routers.media import storage_status


def test_cloudinary_is_installed():
    """The failure was a missing dependency, not missing configuration.

    Worth its own test because every other signal pointed the wrong way: the
    secrets could be set correctly, the code reads them, and the upload still
    goes to disk. A test on configuration alone would have passed throughout.
    """
    import cloudinary  # noqa: F401
    import cloudinary.uploader  # noqa: F401

    from app.routers import media

    assert media._CLOUDINARY_AVAILABLE is True


def test_status_reports_durability_not_just_configuration():
    status = storage_status()

    assert set(status) >= {
        "backend",
        "survives_a_deploy",
        "library_installed",
        "credentials_set",
    }
    # The library half is now satisfied everywhere, including CI. Only the
    # credentials decide the answer, which is the question an operator can act on.
    assert status["library_installed"] is True
    assert status["survives_a_deploy"] == status["credentials_set"]


def test_status_leaks_no_credentials():
    """Same rule as /api/health/auth: configuration, never values. This endpoint
    is unauthenticated so it can be read during an outage."""
    from app.core.config import settings

    secrets = [
        settings.CLOUDINARY_CLOUD_NAME,
        settings.CLOUDINARY_API_KEY,
        settings.CLOUDINARY_API_SECRET,
    ]
    rendered = repr(storage_status())

    for secret in secrets:
        if secret:
            assert secret not in rendered


@pytest.mark.parametrize("configured", [True, False])
def test_backend_name_follows_configuration(monkeypatch, configured):
    from app.routers import media

    monkeypatch.setattr(media, "_cloudinary_configured", lambda: configured)
    status = media.storage_status()

    assert status["backend"] == ("cloudinary" if configured else "local_disk")
    assert status["survives_a_deploy"] is configured
