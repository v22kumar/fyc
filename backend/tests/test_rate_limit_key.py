"""The rate limiter has to know who is calling.

On Fly it never did: `get_remote_address` returns fly-proxy for every request,
so the whole club shared one bucket and `5/minute` on OTP send was five sign-ins
per minute for everybody. These tests pin the two halves of the fix — read
Fly's own header on Fly, and refuse to read it anywhere else, because off Fly
that header is just something a caller can type.
"""
import pytest
from starlette.requests import Request


def _request(headers: dict[str, str], peer: str = "10.0.0.9") -> Request:
    """A Request with the given headers, arriving from `peer`."""
    return Request(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "GET",
            "scheme": "http",
            "path": "/",
            "raw_path": b"/",
            "query_string": b"",
            "headers": [
                (k.lower().encode("latin1"), v.encode("latin1"))
                for k, v in headers.items()
            ],
            "client": (peer, 54321),
            "server": ("testserver", 80),
        }
    )


@pytest.fixture
def rate_limit(monkeypatch):
    """The module, with `_ON_FLY` set the way this test needs it.

    `_ON_FLY` is resolved once at import because `FLY_APP_NAME` cannot change
    while a process runs. Tests set the resolved flag rather than reloading the
    module: a reload would mint a fresh `limiter` while every router kept a
    reference to the old one, which is a confusing way to fail.
    """

    def _load(on_fly: bool):
        import app.core.rate_limit as mod

        monkeypatch.setattr(mod, "_ON_FLY", on_fly)
        return mod

    return _load


def test_on_fly_the_real_caller_is_counted(rate_limit):
    """Two members behind the same proxy must land in two different buckets."""
    mod = rate_limit(on_fly=True)

    first = mod.client_ip(_request({"Fly-Client-IP": "49.207.1.1"}))
    second = mod.client_ip(_request({"Fly-Client-IP": "49.207.2.2"}))

    assert first == "49.207.1.1"
    assert second == "49.207.2.2"
    assert first != second, "otherwise one member's limit is everyone's limit"


def test_off_fly_a_forged_header_is_ignored(rate_limit):
    """`Fly-Client-IP` is only trustworthy where fly-proxy writes it.

    Anywhere else a caller can send whatever they like, and a caller who sends a
    fresh value per request would have no rate limit at all — strictly worse
    than the shared bucket this replaces.
    """
    mod = rate_limit(on_fly=False)

    ip = mod.client_ip(_request({"Fly-Client-IP": "1.2.3.4"}, peer="10.0.0.9"))

    assert ip == "10.0.0.9"


def test_a_forwarded_for_header_is_never_trusted(rate_limit):
    """Not even on Fly.

    fly-proxy *appends* to X-Forwarded-For rather than replacing it, so its
    leftmost entry is caller-controlled. This is exactly the trap in
    `uvicorn --forwarded-allow-ips='*'`, which takes that leftmost entry.
    """
    mod = rate_limit(on_fly=True)

    ip = mod.client_ip(
        _request({"X-Forwarded-For": "1.2.3.4, 49.207.5.5"}, peer="10.0.0.9")
    )

    assert ip == "10.0.0.9"


def test_missing_fly_header_falls_back_rather_than_failing(rate_limit):
    """A request without the header still gets a key — the old behaviour."""
    mod = rate_limit(on_fly=True)

    assert mod.client_ip(_request({}, peer="10.0.0.9")) == "10.0.0.9"


def test_every_limited_route_shares_one_key_function():
    """Five routers used to build five limiters, and a fix had to land in all
    five. They now share one, so the next fix lands once."""
    from app.core.rate_limit import limiter
    from app.main import limiter as main_limiter
    from app.routers.auth import limiter as auth_limiter
    from app.routers.chess import limiter as chess_limiter
    from app.routers.chess_tournaments import limiter as tournament_limiter
    from app.routers.diagnostics import limiter as diagnostics_limiter

    for other in (
        main_limiter,
        auth_limiter,
        chess_limiter,
        tournament_limiter,
        diagnostics_limiter,
    ):
        assert other is limiter
