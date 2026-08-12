"""A Google sign-in that happens in the browser, not inside the app.

The native Google plugin authenticates by showing Google the pair (package
name, signing certificate). When Google does not recognise that pair it answers
`DEVELOPER_ERROR` — code 10 — and there is nothing the app can do about it: the
fix lives in a console, and it is specific to *how this copy was signed*. Play
re-signs uploaded bundles with its own key, so the Play build and the CI build
present different certificates and can fail independently. That makes the
signing certificate a single point of failure for signing in at all.

The browser knows nothing about certificates. It authenticates against the
*web* client id over ordinary OAuth, so it works on every build — Play-signed,
CI-signed, debug — and keeps working when a fingerprint is missing.

The awkward part is getting the answer back. Rather than register a custom URL
scheme (another thing that is per-build and can be wrong), the app holds a
handle: it starts the flow, opens the browser, and asks this table whether the
browser has finished. Google redirects to the backend, the backend finishes the
exchange, and the result waits here until the app collects it — once.
"""
from sqlalchemy import Column, DateTime, String, Text

from app.core.database import Base
from app.models.base import GUID, TimestampMixin


class PendingBrowserLogin(Base, TimestampMixin):
    __tablename__ = "pending_browser_logins"

    # Secret handle, generated server-side and returned only to the app that
    # started the flow. It is also the OAuth `state`, which is what stops a
    # stranger's callback from landing in this member's session. Whoever holds
    # it can collect the token, so it is long, single-use and short-lived.
    session_id = Column(String(64), primary_key=True)

    organization_id = Column(GUID(), nullable=False)

    # "pending" until the browser comes back, then "ready" or "failed".
    status = Column(String(12), nullable=False, default="pending")

    # The finished answer — a Token, or the needs_registration hand-off — as
    # JSON. Written once by the callback, read once by the app, then deleted.
    result_json = Column(Text, nullable=True)

    # Why it failed, in a sentence the member can act on.
    error = Column(String(300), nullable=True)

    expires_at = Column(DateTime(timezone=True), nullable=False)
