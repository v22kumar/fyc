"""Reusable ETag / 304 Not Modified support for list endpoints.

Applied to a representative set of high-traffic list endpoints this sprint
(posts, announcements, events, sports tournaments) to establish the pattern;
see docs/SPRINT_1_STATUS.md for the remaining-endpoints checklist.

Usage in a router:

    @router.get("", response_model=List[PostOut])
    def list_posts(request: Request, response: Response, ...):
        result = [...]
        cached = etag_not_modified(request, result)
        if cached is not None:
            return cached
        set_etag(response, result)
        return result
"""
import hashlib
import json
from typing import Any, Optional

from fastapi import Request, Response
from fastapi.encoders import jsonable_encoder

_CACHE_CONTROL = "private, max-age=0, must-revalidate"


def compute_etag(payload: Any) -> str:
    """Deterministic weak ETag for a JSON-serializable payload."""
    encoded = jsonable_encoder(payload)
    blob = json.dumps(encoded, sort_keys=True, default=str).encode("utf-8")
    return 'W/"' + hashlib.sha256(blob).hexdigest()[:32] + '"'


def set_etag(response: Response, payload: Any) -> str:
    """Stamp the ETag + Cache-Control headers on an outgoing response."""
    etag = compute_etag(payload)
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = _CACHE_CONTROL
    return etag


def etag_not_modified(request: Request, payload: Any) -> Optional[Response]:
    """Return a bare 304 Response if the client's cached copy (sent via
    If-None-Match) still matches `payload`, else None (caller proceeds to
    return the real payload after calling `set_etag`).

    Returning a `Response` instance directly from a FastAPI route bypasses
    `response_model` serialization — this is documented FastAPI behavior, so
    a 304 can be returned even from an endpoint typed `response_model=List[...]`.
    """
    etag = compute_etag(payload)
    if_none_match = request.headers.get("if-none-match")
    if if_none_match == etag:
        return Response(status_code=304, headers={"ETag": etag, "Cache-Control": _CACHE_CONTROL})
    return None
