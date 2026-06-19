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


@router.get("/tn-jobs", response_model=list[NewsItemResponse])
def get_tn_jobs_news(limit: int = Query(service.MAX_TN_JOBS_ITEMS, ge=1, le=service.MAX_TN_JOBS_ITEMS)):
    """Tamil Nadu government job & recruitment notifications — 8 items."""
    return service.get_tn_jobs_news(limit=limit)


@router.get("/central-jobs", response_model=list[NewsItemResponse])
def get_central_jobs_news(limit: int = Query(service.MAX_CENTRAL_JOBS_ITEMS, ge=1, le=service.MAX_CENTRAL_JOBS_ITEMS)):
    """Central government job notifications — SSC, UPSC, Railway, IBPS — 8 items."""
    return service.get_central_jobs_news(limit=limit)


@router.get("/kanyakumari", response_model=list[NewsItemResponse])
def get_kanyakumari_news(limit: int = Query(service.MAX_KANYAKUMARI_ITEMS, ge=1, le=service.MAX_KANYAKUMARI_ITEMS)):
    """Kanyakumari / Kanniyakumari local news in Tamil — 8 items."""
    return service.get_kanyakumari_news(limit=limit)
