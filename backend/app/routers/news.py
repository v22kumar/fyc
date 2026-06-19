from fastapi import APIRouter, Query

from app.schemas.news import NewsItemResponse
from app.services import news as service

router = APIRouter(prefix="/news", tags=["News"])


@router.get("/top", response_model=list[NewsItemResponse])
def get_top_news(limit: int = Query(service.MAX_ITEMS, ge=1, le=service.MAX_ITEMS)):
    """Top Tamil headlines from Google News RSS — India edition, Tamil language."""
    return service.get_top_tamil_news(limit=limit)


@router.get("/india", response_model=list[NewsItemResponse])
def get_india_news(limit: int = Query(service.MAX_INDIA_ITEMS, ge=1, le=service.MAX_INDIA_ITEMS)):
    """Top India news headlines (English) — 5 items."""
    return service.get_india_news(limit=limit)


@router.get("/jobs", response_model=list[NewsItemResponse])
def get_jobs_news(limit: int = Query(service.MAX_JOBS_ITEMS, ge=1, le=service.MAX_JOBS_ITEMS)):
    """India jobs and recruitment headlines — 4 items."""
    return service.get_jobs_news(limit=limit)
