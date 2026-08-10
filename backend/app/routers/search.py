"""The search endpoint.

Thin on purpose: it validates, delegates to `app.services.search`, and shapes
the answer. The ranking, the destination catalogue and the list of searchable
things all live in the service, where they can be read and tested without an
HTTP client. This file used to hold all three, inline, as seven near-identical
blocks — which is why nobody added an eighth, and why fourteen screens were
never searchable.
"""
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import get_db
from app.dependencies import get_current_user_optional
from app.middleware.tenant import require_tenant_id
from app.services.search import search as run_search

router = APIRouter(prefix="/search", tags=["Search"])


class SearchResult(BaseModel):
    # A string, not a UUID: a destination is identified by a slug ("events"),
    # and forcing it into a UUID column is what kept places out of search.
    id: str
    type: str
    title: str
    subtitle: Optional[str] = None
    image_url: Optional[str] = None
    # Where tapping this goes. Previously the app kept its own type→route map
    # and sent every result to a section index, so finding one specific event
    # landed you on the full list. The server knows what it found; it should
    # say where the thing lives.
    route: str
    score: int


@router.get("", response_model=List[SearchResult])
def global_search(
    q: str = Query(..., min_length=2, description="Search query string"),
    types: Optional[List[str]] = Query(
        None, description="Restrict to types, e.g. DESTINATION, EVENT, USER"),
    lang: str = Query("en", description="Language for destination titles"),
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: Any = Depends(get_current_user_optional),
):
    """Everything that answers this query, best first.

    One ranked list rather than a bag of per-type buckets: relevance is a
    property of the whole result set, and the old shape made it impossible to
    say that an exactly-named event beats a tournament that merely mentions it.

    Results include **places** as well as things — see
    `app.services.search_destinations`. A member typing "Events" gets the events
    page, which is what they meant and what the old search could never return.
    """
    return [
        SearchResult(**hit._asdict())
        for hit in run_search(db, q, tenant_id, lang=lang, types=types)
    ]
