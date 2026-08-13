"""One rate limiter, keyed by the address the request really came from.

## Why this module exists

There were five `Limiter(key_func=get_remote_address)` instances, one per
router, and every one of them was counting the wrong thing in production.

`get_remote_address` reads `request.client.host` — the peer that opened the TCP
connection. On Fly that peer is always fly-proxy, never the member. Uvicorn can
correct this from `X-Forwarded-For`, but only for peers it trusts, and its
default trust list is `127.0.0.1`. fly-proxy reaches the machine over the
private network, so it is never trusted and the header is never read.

The result: every member in the club shared one bucket. `@limiter.limit("5/minute")`
on OTP send was a *club-wide* five per minute. On tournament day, with a hundred
people signing in at once, the sixth person each minute would be told to slow
 down for something five strangers did.

## Why not just trust the proxy header

The obvious fix — `uvicorn --forwarded-allow-ips='*'` — is worse than the bug.
With `always_trust` set, uvicorn takes the *leftmost* entry of `X-Forwarded-For`,
and the leftmost entry is whatever the caller wrote there. fly-proxy appends the
real address rather than replacing the header, so a caller who sends
`X-Forwarded-For: 1.2.3.4` becomes 1.2.3.4 as far as the limiter is concerned,
and a caller who sends a fresh value on every request has no limit at all. That
turns a shared bucket into no bucket, which is the failure we would least like
on the endpoint that spends money sending SMS.

So we read `Fly-Client-IP`, which fly-proxy *sets* rather than appends to, and
only when we can see we are actually running on Fly. Off Fly — a laptop, a test,
a future host — that header is just something a caller can type, so it is
ignored and we fall back to the connection's own address.
"""
import os

from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request

from app.core.config import settings

# Set by the Fly runtime in every machine. Its presence is how we know the
# `Fly-Client-IP` header is being written by the proxy rather than by whoever
# is calling us.
_ON_FLY = bool(os.getenv("FLY_APP_NAME"))


def client_ip(request: Request) -> str:
    """The caller's address, as well as this host can know it.

    Falls back to the connection peer, which is right off Fly and harmless on
    it — a shared bucket is the behaviour we already had.
    """
    if _ON_FLY:
        fly_ip = request.headers.get("Fly-Client-IP")
        if fly_ip:
            return fly_ip.strip()
    return get_remote_address(request)


class _DisabledLimiter:
    """A real no-op limiter for tests.

    slowapi's decorator wrapper is useful in production, but even when the
    limiter is disabled it can still alter FastAPI's signature introspection on
    some routes. That turns perfectly valid JSON body parameters into required
    query parameters and produces 422s before the endpoint is called.

    Tests do not need rate limiting; the OTP attempt counter and dedicated
    throttle tests cover the security behaviour. Returning the original
    function keeps FastAPI's request/payload/db dependency inspection exact.
    """

    def limit(self, *_args, **_kwargs):
        return lambda fn: fn


# Shared by every router. slowapi keys each limit by (key, endpoint), so one
# instance does not merge unrelated limits — it just means the address is
# resolved the same way everywhere, which was the actual problem.
#
# Storage is in-process, which is correct while the app runs on exactly one
# machine (fly.toml pins it there because live chess games live in memory). If
# that ever changes, this is the line that needs a Valkey URI — otherwise each
# instance would enforce the limit separately and the real limit would multiply
# by the instance count.
limiter = _DisabledLimiter() if settings.TESTING else Limiter(
    key_func=client_ip,
    enabled=True,
)
