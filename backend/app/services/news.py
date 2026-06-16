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

GOOGLE_NEWS_RSS_URL = "https://news.google.com/rss?hl=ta&gl=IN&ceid=IN:ta"
MAX_ITEMS = 10
_REQUEST_TIMEOUT = 10
_CACHE_TTL = timedelta(minutes=30)
_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)

_cache: dict = {"items": [], "fetched_at": None}


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


def _fetch() -> list[dict]:
    response = httpx.get(
        GOOGLE_NEWS_RSS_URL,
        headers={"User-Agent": _USER_AGENT},
        timeout=_REQUEST_TIMEOUT,
        follow_redirects=True,
    )
    response.raise_for_status()
    return parse_rss(response.text)


def get_top_tamil_news(limit: int = MAX_ITEMS) -> list[dict]:
    """
    Return up to `limit` Tamil headlines, refreshing the in-process cache
    when it goes stale. Falls back to the last successfully fetched batch
    (even if stale) if the upstream feed is unreachable.
    """
    limit = min(limit, MAX_ITEMS)
    now = datetime.now(timezone.utc)
    is_stale = _cache["fetched_at"] is None or now - _cache["fetched_at"] > _CACHE_TTL
    if is_stale:
        try:
            _cache["items"] = _fetch()
            _cache["fetched_at"] = now
        except Exception as e:
            logger.warning(f"Google News RSS fetch failed, serving cache: {e}")
    return _cache["items"][:limit]
