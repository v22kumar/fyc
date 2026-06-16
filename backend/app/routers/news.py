from fastapi import APIRouter, Query

from app.schemas.news import NewsItemResponse
from app.services import news as service

router = APIRouter(prefix="/news", tags=["News"])


@router.get("/top", response_model=list[NewsItemResponse])
def get_top_news(limit: int = Query(service.MAX_ITEMS, ge=1, le=service.MAX_ITEMS)):
    """
    Top Tamil headlines from Google News RSS (news.google.com), India edition.
    Universal public content — no tenant scope or auth required.
    """
    return service.get_top_tamil_news(limit=limit)
