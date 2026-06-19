"""
Tamil news headlines via Google News RSS (news.google.com).

Public RSS feed, no API key needed. Results are cached in-process so the
home screen stays fast and a transient upstream hiccup never surfaces as an
error — we just keep serving the last good batch until the next refresh.
"""
import logging
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

GOOGLE_NEWS_RSS_URL      = "https://news.google.com/rss?hl=ta&gl=IN&ceid=IN:ta"
INDIA_NEWS_RSS_URL       = "https://news.google.com/rss?hl=en&gl=IN&ceid=IN:en"
JOBS_NEWS_RSS_URL        = "https://news.google.com/rss/search?q=jobs+recruitment+india&hl=en&gl=IN&ceid=IN:en"
KANYAKUMARI_NEWS_RSS_URL = "https://news.google.com/rss/search?q=kanyakumari+OR+kanniyakumari&hl=ta&gl=IN&ceid=IN:ta"

MAX_ITEMS             = 10
MAX_INDIA_ITEMS       = 5
MAX_JOBS_ITEMS        = 4
MAX_KANYAKUMARI_ITEMS = 8

_REQUEST_TIMEOUT = 10
_CACHE_TTL = timedelta(minutes=30)
_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)

_cache:            dict = {"items": [], "fetched_at": None}
_india_cache:      dict = {"items": [], "fetched_at": None}
_jobs_cache:       dict = {"items": [], "fetched_at": None}
_kanyakumari_cache: dict = {"items": [], "fetched_at": None}


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


def _fetch(url: str) -> list[dict]:
    response = httpx.get(
        url,
        headers={"User-Agent": _USER_AGENT},
        timeout=_REQUEST_TIMEOUT,
        follow_redirects=True,
    )
    response.raise_for_status()
    return parse_rss(response.text)


def _get_cached(cache: dict, url: str, limit: int) -> list[dict]:
    now = datetime.now(timezone.utc)
    is_stale = cache["fetched_at"] is None or now - cache["fetched_at"] > _CACHE_TTL
    if is_stale:
        try:
            cache["items"] = _fetch(url)
            cache["fetched_at"] = now
        except Exception as e:
            logger.warning(f"News RSS fetch failed ({url}), serving cache: {e}")
    return cache["items"][:limit]


def get_top_tamil_news(limit: int = MAX_ITEMS) -> list[dict]:
    """Return up to `limit` Tamil headlines (Google News India, Tamil edition)."""
    return _get_cached(_cache, GOOGLE_NEWS_RSS_URL, min(limit, MAX_ITEMS))


def get_india_news(limit: int = MAX_INDIA_ITEMS) -> list[dict]:
    """Return up to `limit` India headlines (Google News India, English edition)."""
    return _get_cached(_india_cache, INDIA_NEWS_RSS_URL, min(limit, MAX_INDIA_ITEMS))


def get_jobs_news(limit: int = MAX_JOBS_ITEMS) -> list[dict]:
    """Return up to `limit` India jobs/recruitment headlines from Google News."""
    return _get_cached(_jobs_cache, JOBS_NEWS_RSS_URL, min(limit, MAX_JOBS_ITEMS))


def get_kanyakumari_news(limit: int = MAX_KANYAKUMARI_ITEMS) -> list[dict]:
    """Return up to `limit` Kanyakumari/Kanniyakumari local headlines (Tamil)."""
    return _get_cached(_kanyakumari_cache, KANYAKUMARI_NEWS_RSS_URL, min(limit, MAX_KANYAKUMARI_ITEMS))
