from fastapi import APIRouter, Query, Response

from app.schemas.news import NewsItemResponse
from app.services import news as service

router = APIRouter(prefix="/news", tags=["News"])

# News feeds refresh every 15 min server-side; tell browsers to cache accordingly.
# stale-while-revalidate lets the browser serve stale content while fetching fresh in background.
_NEWS_CC = "public, max-age=900, stale-while-revalidate=1800"


@router.get("/top", response_model=list[NewsItemResponse])
def get_top_news(
    limit: int = Query(service.MAX_ITEMS, ge=1, le=service.MAX_ITEMS),
    response: Response = None,
):
    """Top Tamil headlines from Google News RSS — India edition, Tamil language."""
    if response is not None:
        response.headers["Cache-Control"] = _NEWS_CC
    return service.get_top_tamil_news(limit=limit)


@router.get("/india", response_model=list[NewsItemResponse])
def get_india_news(
    limit: int = Query(service.MAX_INDIA_ITEMS, ge=1, le=service.MAX_INDIA_ITEMS),
    response: Response = None,
):
    """Top India news headlines (English) — 5 items."""
    if response is not None:
        response.headers["Cache-Control"] = _NEWS_CC
    return service.get_india_news(limit=limit)


@router.get("/tn-jobs", response_model=list[NewsItemResponse])
def get_tn_jobs_news(
    limit: int = Query(service.MAX_TN_JOBS_ITEMS, ge=1, le=service.MAX_TN_JOBS_ITEMS),
    response: Response = None,
):
    """Tamil Nadu government job & recruitment notifications — 8 items."""
    if response is not None:
        response.headers["Cache-Control"] = _NEWS_CC
    return service.get_tn_jobs_news(limit=limit)


@router.get("/central-jobs", response_model=list[NewsItemResponse])
def get_central_jobs_news(
    limit: int = Query(service.MAX_CENTRAL_JOBS_ITEMS, ge=1, le=service.MAX_CENTRAL_JOBS_ITEMS),
    response: Response = None,
):
    """Central government job notifications — SSC, UPSC, Railway, IBPS — 8 items."""
    if response is not None:
        response.headers["Cache-Control"] = _NEWS_CC
    return service.get_central_jobs_news(limit=limit)


@router.get("/kanyakumari", response_model=list[NewsItemResponse])
def get_kanyakumari_news(
    limit: int = Query(service.MAX_KANYAKUMARI_ITEMS, ge=1, le=service.MAX_KANYAKUMARI_ITEMS),
    response: Response = None,
):
    """Kanyakumari / Kanniyakumari local news in Tamil — 8 items."""
    if response is not None:
        response.headers["Cache-Control"] = _NEWS_CC
    return service.get_kanyakumari_news(limit=limit)
