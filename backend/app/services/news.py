"""
Tamil news headlines via Google News RSS (news.google.com).

Public RSS feed, no API key needed. Results are cached in-process so the
home screen stays fast and a transient upstream hiccup never surfaces as an
error — we just keep serving the last good batch until the next refresh.
"""
import asyncio
import html
import json
import logging
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

GOOGLE_NEWS_RSS_URL      = "https://news.google.com/rss?hl=ta&gl=IN&ceid=IN:ta"
INDIA_NEWS_RSS_URL       = "https://news.google.com/rss?hl=en&gl=IN&ceid=IN:en"
KANYAKUMARI_NEWS_RSS_URL = "https://news.google.com/rss/search?q=kanyakumari+OR+kanniyakumari&hl=ta&gl=IN&ceid=IN:ta"
TN_JOBS_RSS_URL          = "https://news.google.com/rss/search?q=TNPSC+OR+%22tamil+nadu+recruitment%22+OR+%22tamilnadu+govt+jobs%22+OR+%22TN+police+recruitment%22&hl=en&gl=IN&ceid=IN:en"
CENTRAL_JOBS_RSS_URL     = "https://news.google.com/rss/search?q=SSC+OR+UPSC+OR+%22railway+recruitment%22+OR+%22central+government+jobs%22+OR+IBPS+OR+%22bank+recruitment%22&hl=en&gl=IN&ceid=IN:en"

MAX_ITEMS              = 10
MAX_INDIA_ITEMS        = 5
MAX_KANYAKUMARI_ITEMS  = 8
MAX_TN_JOBS_ITEMS      = 8
MAX_CENTRAL_JOBS_ITEMS = 8

_REQUEST_TIMEOUT = 10
_CACHE_TTL = timedelta(minutes=30)
_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)

_cache:              dict = {"items": [], "fetched_at": None}
_india_cache:        dict = {"items": [], "fetched_at": None}
_kanyakumari_cache:  dict = {"items": [], "fetched_at": None}
_tn_jobs_cache:      dict = {"items": [], "fetched_at": None}
_central_jobs_cache: dict = {"items": [], "fetched_at": None}


def _split_title_source(raw_title: str) -> tuple[str, str]:
    """Google News titles are usually 'Headline - Source'; split them apart."""
    if " - " in raw_title:
        headline, _, source = raw_title.rpartition(" - ")
        if headline and source:
            return headline, source
    return raw_title, "Google News"


def _parse_pubdate(raw: Optional[str]) -> Optional[datetime]:
    if not raw:
        return None
    try:
        return parsedate_to_datetime(raw)
    except (TypeError, ValueError):
        return None


def parse_rss(xml_text: str) -> list[dict]:
    """Parse a Google News RSS document into a list of plain dicts."""
    root = ET.fromstring(xml_text)
    items = []
    for item in root.findall("./channel/item"):
        raw_title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()

        source_el = item.find("source")
        source_text = (source_el.text or "").strip() if source_el is not None else ""
        if source_text:
            headline = raw_title
            suffix = f" - {source_text}"
            if headline.endswith(suffix):
                headline = headline[: -len(suffix)]
            source = source_text
        else:
            headline, source = _split_title_source(raw_title)

        if not headline or not link:
            continue

        items.append({
            "title": headline,
            "source": source,
            "link": link,
            "published_at": _parse_pubdate(item.findtext("pubDate")),
        })
    return items


async def _fetch(url: str) -> list[dict]:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            url,
            headers={"User-Agent": _USER_AGENT},
            timeout=_REQUEST_TIMEOUT,
            follow_redirects=True,
        )
    response.raise_for_status()
    return parse_rss(response.text)


async def _get_cached(cache_dict: dict, url: str, limit: int) -> list[dict]:
    from app.core.cache import get_valkey
    valkey = get_valkey()
    cache_key = f"news_cache:{url}"
    
    if valkey:
        cached_data = valkey.get(cache_key)
        if cached_data:
            try:
                items = json.loads(cached_data)
                # Convert ISO strings back to datetime objects
                for item in items:
                    if item.get("published_at"):
                        item["published_at"] = datetime.fromisoformat(item["published_at"])
                return items[:limit]
            except Exception as e:
                logger.warning(f"Valkey cache parse error for {url}: {e}")
                
    # Fallback to local dict logic or refresh
    now = datetime.now(timezone.utc)
    is_stale = cache_dict["fetched_at"] is None or now - cache_dict["fetched_at"] > _CACHE_TTL
    if is_stale:
        try:
            items = await _fetch(url)
            cache_dict["items"] = items
            cache_dict["fetched_at"] = now
            
            # Update Valkey if available
            if valkey:
                # Serialize datetime to ISO strings for JSON
                class DateTimeEncoder(json.JSONEncoder):
                    def default(self, obj):
                        if isinstance(obj, datetime):
                            return obj.isoformat()
                        return super().default(obj)
                valkey.setex(cache_key, int(_CACHE_TTL.total_seconds()), json.dumps(items, cls=DateTimeEncoder))
                
        except Exception as e:
            logger.warning(f"News RSS fetch failed ({url}), serving cache: {e}")
    return cache_dict["items"][:limit]


async def get_top_tamil_news(limit: int = MAX_ITEMS) -> list[dict]:
    """Return up to `limit` Tamil headlines (Google News India, Tamil edition)."""
    return await _get_cached(_cache, GOOGLE_NEWS_RSS_URL, min(limit, MAX_ITEMS))


async def get_india_news(limit: int = MAX_INDIA_ITEMS) -> list[dict]:
    """Return up to `limit` India headlines (Google News India, English edition)."""
    return await _get_cached(_india_cache, INDIA_NEWS_RSS_URL, min(limit, MAX_INDIA_ITEMS))


async def get_tn_jobs_news(limit: int = MAX_TN_JOBS_ITEMS) -> list[dict]:
    """Return up to `limit` Tamil Nadu government job/recruitment headlines."""
    return await _get_cached(_tn_jobs_cache, TN_JOBS_RSS_URL, min(limit, MAX_TN_JOBS_ITEMS))


async def get_central_jobs_news(limit: int = MAX_CENTRAL_JOBS_ITEMS) -> list[dict]:
    """Return up to `limit` Central government job/recruitment headlines (SSC, UPSC, Railway, IBPS)."""
    return await _get_cached(_central_jobs_cache, CENTRAL_JOBS_RSS_URL, min(limit, MAX_CENTRAL_JOBS_ITEMS))


async def get_kanyakumari_news(limit: int = MAX_KANYAKUMARI_ITEMS) -> list[dict]:
    """Return up to `limit` Kanyakumari/Kanniyakumari local headlines (Tamil)."""
    return await _get_cached(_kanyakumari_cache, KANYAKUMARI_NEWS_RSS_URL, min(limit, MAX_KANYAKUMARI_ITEMS))
