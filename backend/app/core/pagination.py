"""Standard pagination params for NEW list endpoints.

Audit finding (Sprint 1): existing routers declare `limit`/`offset` Query
params individually with inconsistent bounds (audit.py le=500, chess.py
le=100/200, posts.py le=50, news.py uses per-feed constants). Rewriting every
existing endpoint's bounds in one sprint risks behavior changes across 150+
routes with no test coverage to catch regressions, so this sprint does not
touch them. Going forward, new list endpoints should depend on
`pagination_params` below instead of redeclaring limit/offset, so the app
converges on one standard (default 20/page, max 50) without a risky mass
rewrite. See docs/SPRINT_1_STATUS.md for the full inconsistency list.
"""
from fastapi import Query
from pydantic import BaseModel


class PageParams(BaseModel):
    limit: int
    offset: int


def pagination_params(
    limit: int = Query(20, ge=1, le=50, description="Items per page (max 50)"),
    offset: int = Query(0, ge=0, description="Items to skip"),
) -> PageParams:
    return PageParams(limit=limit, offset=offset)
