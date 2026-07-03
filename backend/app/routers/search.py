from typing import List, Optional, Any
from uuid import UUID
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies import get_current_user_optional
from app.middleware.tenant import require_tenant_id
from app.models.user import UserProfile
from app.models.event import Event
from app.models.sports import Tournament, Team, Player
from app.models.issue import PublicIssue
from app.models.blood_donor import BloodDonor
from pydantic import BaseModel

router = APIRouter(prefix="/search", tags=["Search"])

class SearchResult(BaseModel):
    id: UUID
    type: str # 'USER', 'EVENT', 'TOURNAMENT', 'TEAM', 'PLAYER', 'NEWS', 'ISSUE', 'BLOOD_DONOR'
    title: str
    subtitle: Optional[str] = None
    image_url: Optional[str] = None

@router.get("", response_model=List[SearchResult])
def global_search(
    q: str = Query(..., min_length=2, description="Search query string"),
    types: Optional[List[str]] = Query(None, description="Filter by types (e.g., USER, EVENT)"),
    db: Session = Depends(get_db),
    tenant_id: UUID = Depends(require_tenant_id),
    current_user: Any = Depends(get_current_user_optional) # Optional for public vs private visibility
):
    """
    Global search engine across the platform.
    """
    results = []
    q_like = f"%{q}%"
    filter_types = [t.upper() for t in types] if types else []

    def should_search(t: str):
        return not filter_types or t in filter_types

    # Users / People
    if should_search("USER"):
        users = db.query(UserProfile).join(UserProfile.user).filter(
            UserProfile.user.has(organization_id=tenant_id),
            (UserProfile.full_name_en.ilike(q_like) | UserProfile.full_name_ta.ilike(q_like))
        ).limit(10).all()
        for u in users:
            results.append(SearchResult(
                id=u.user_id,
                type="USER",
                title=u.full_name_en or u.full_name_ta,
                image_url=u.profile_image_url
            ))

    # Events
    if should_search("EVENT"):
        events = db.query(Event).filter(
            Event.organization_id == tenant_id,
            (Event.title_en.ilike(q_like) | Event.title_ta.ilike(q_like) | Event.description_en.ilike(q_like))
        ).limit(10).all()
        for e in events:
            results.append(SearchResult(
                id=e.id,
                type="EVENT",
                title=e.title_en or e.title_ta,
                subtitle="Event",
                image_url=e.banner_url
            ))

    # Tournaments
    if should_search("TOURNAMENT"):
        tournaments = db.query(Tournament).filter(
            Tournament.organization_id == tenant_id,
            (Tournament.name_en.ilike(q_like) | Tournament.name_ta.ilike(q_like) | Tournament.sport.ilike(q_like))
        ).limit(10).all()
        for t in tournaments:
            results.append(SearchResult(
                id=t.id,
                type="TOURNAMENT",
                title=t.name_en or t.name_ta,
                subtitle=f"Sport: {t.sport}"
            ))

    # Teams
    if should_search("TEAM"):
        teams = db.query(Team).filter(
            Team.organization_id == tenant_id,
            Team.name.ilike(q_like)
        ).limit(10).all()
        for t in teams:
            results.append(SearchResult(
                id=t.id,
                type="TEAM",
                title=t.name,
                subtitle="Team",
                image_url=t.logo_url
            ))

    # News search omitted — there is no News model in the schema (public news
    # is sourced from Google RSS, not a local table).

    # Issues
    if should_search("ISSUE"):
        issues = db.query(PublicIssue).filter(
            PublicIssue.organization_id == tenant_id,
            (PublicIssue.description_en.ilike(q_like) | PublicIssue.description_ta.ilike(q_like))
        ).limit(10).all()
        for i in issues:
            results.append(SearchResult(
                id=i.id,
                type="ISSUE",
                title="Public Issue",
                subtitle=i.description_en[:50] if i.description_en else "",
                image_url=i.photo_url
            ))

    return results
