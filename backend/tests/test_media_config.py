"""Getting Cloudinary switched on, without splitting a secret by hand.

The dashboard hands you exactly one value:

    CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>

and this app wanted three separate secrets. Asking somebody to take that
string apart is three chances to paste the wrong half — and a half-configured
Cloudinary fails at upload time with an authentication error, not at boot with
"not configured", so the mistake surfaces days later on somebody's photo.
"""
from app.core.config import Settings


_URL = "cloudinary://123456789012345:kUsecretsecretsecret@wpyxmshm"


def test_the_one_value_the_dashboard_gives_is_enough():
    name, key, secret = Settings(CLOUDINARY_URL=_URL).cloudinary
    assert name == "wpyxmshm"
    assert key == "123456789012345"
    assert secret == "kUsecretsecretsecret"


def test_three_separate_secrets_still_work():
    """The existing way in must keep working — someone may already have set it."""
    name, key, secret = Settings(
        CLOUDINARY_CLOUD_NAME="c", CLOUDINARY_API_KEY="k",
        CLOUDINARY_API_SECRET="s").cloudinary
    assert (name, key, secret) == ("c", "k", "s")


def test_explicit_secrets_win_over_the_url():
    name, _, _ = Settings(
        CLOUDINARY_URL=_URL, CLOUDINARY_CLOUD_NAME="explicit",
        CLOUDINARY_API_KEY="k", CLOUDINARY_API_SECRET="s").cloudinary
    assert name == "explicit"


def test_nothing_set_is_not_half_configured():
    assert Settings().cloudinary == ("", "", "")


def test_the_masked_url_from_the_dashboard_is_refused():
    """The dashboard displays the URL with the key and secret masked.

    Pasting that verbatim is the obvious mistake. Without this guard it reads
    as fully configured and fails at the first upload, days later, with an
    authentication error nobody connects back to a copy-paste.
    """
    masked = "cloudinary://<your_api_key>:<your_api_secret>@wpyxmshm"
    assert Settings(CLOUDINARY_URL=masked).cloudinary == ("", "", ""), \
        "a placeholder is not a credential"


def test_a_url_that_is_not_a_cloudinary_url_is_ignored():
    assert Settings(CLOUDINARY_URL="https://example.com/x").cloudinary == \
        ("", "", "")
