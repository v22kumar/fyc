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


#: Words that mean a search box rather than a story.
_QUERY_WORDS = {"news", "latest", "today", "updates", "breaking", "district",
                "headlines"}


def _title_key(title: str) -> str:
    """A headline reduced to the words that carry it.

    Punctuation, case and the publisher suffix vary between feeds while the
    story does not, so those are stripped before comparing.
    """
    import re

    t = title.lower().split(" - ")[0].split(" | ")[0]
    t = re.sub(r"[^a-z0-9\u0b80-\u0bff ]+", " ", t)
    return " ".join(t.split())


def _looks_like_a_query(title: str) -> bool:
    """Is this a search term somebody typed rather than something published?

    "kanyakumari news" and "Kanyakumari district" arrived as titles from a
    search API. A real headline says something; these name a topic. The test
    is deliberately conservative — three words or fewer, and every word either
    a place or one of the query words above — because dropping a real story is
    worse than keeping a dull one.
    """
    words = [w for w in title.strip().lower().replace("|", " ").split() if w]
    if not words or len(words) > 4:
        return False
    return all(w in _QUERY_WORDS or w.isalpha() and len(w) > 3
               for w in words) and any(w in _QUERY_WORDS for w in words)


def _publisher_from_url(url: str) -> str:
    """The masthead, from the domain.

    dinamalar.com becomes Dinamalar. Not perfect, and far better than naming
    the scraper: a member reading "Firecrawl" under a headline reasonably
    concludes that is who wrote it.
    """
    from urllib.parse import urlparse

    host = (urlparse(url).netloc or "").lower()
    host = host.removeprefix("www.").removeprefix("m.")
    if not host:
        return ""
    name = host.split(".")[0]
    return name[:1].upper() + name[1:] if name else ""


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
            "image_url": _image_from_rss(item),
        })
    return items


# ── Pictures ─────────────────────────────────────────────────────────────────
#
# Google News RSS carries no images. Its <description> is a list of links and
# its items have no media:content, no enclosure, nothing — which is why the
# news card has always been a wall of text while every news app people actually
# use is led by pictures.
#
# The image lives on the publisher's page, in the og:image meta tag that exists
# precisely so a link can be shown with a picture. Getting it means following
# Google's redirect to the publisher and reading the first few KB of their HTML.
#
# Three rules keep that from becoming a liability:
#
#   * **Bounded, and honest about what that means.** The request DOES wait for
#     enrichment — up to _IMAGE_BUDGET_SECONDS — and whatever has arrived by
#     then is what ships. Headlines are never lost to a slow publisher, but
#     saying this is "off the critical path" would be wrong: it costs the
#     request that misses the cache, once every thirty minutes per feed. The
#     budget and the shared semaphore are what keep that cost small enough to
#     sit beside live chess on a two-core machine.
#   * **Only the few that show one.** The hero and the top rows; nobody scrolls
#     forty items on a home screen.
#   * **Remembered.** An article's picture does not change, so it is looked up
#     once and kept for a day. The 30-minute news refresh reuses it.
_IMAGE_CACHE: dict[str, tuple[float, Optional[str]]] = {}
_IMAGE_TTL_SECONDS = 24 * 60 * 60
_IMAGE_BUDGET_SECONDS = 3.0

# Across ALL feeds, not per feed. Five categories refreshing together would
# otherwise open forty outbound connections at once from a two-core machine
# that is also holding chess websockets open. The pictures are worth having;
# they are not worth a stutter in somebody's game.
_IMAGE_CONCURRENCY = asyncio.Semaphore(6)
_IMAGE_FETCH_TIMEOUT = 4.0
_IMAGES_PER_FEED = 8
_HTML_HEAD_BYTES = 60_000

_OG_IMAGE_RE = re.compile(
    r'<meta[^>]+(?:property|name)=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']',
    re.IGNORECASE)
_OG_IMAGE_REVERSED_RE = re.compile(
    r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']og:image["\']',
    re.IGNORECASE)
_TWITTER_IMAGE_RE = re.compile(
    r'<meta[^>]+(?:property|name)=["\']twitter:image["\'][^>]+content=["\']([^"\']+)["\']',
    re.IGNORECASE)


def _image_from_rss(item) -> Optional[str]:
    """A picture the feed handed us outright, if it ever does.

    Google News does not, but these feeds are swapped and extended over time
    and reading the standard fields costs nothing.
    """
    for path, attr in (
        ("{http://search.yahoo.com/mrss/}content", "url"),
        ("{http://search.yahoo.com/mrss/}thumbnail", "url"),
        ("enclosure", "url"),
    ):
        el = item.find(path)
        if el is not None:
            url = (el.get(attr) or "").strip()
            if url.startswith("http"):
                return url
    description = item.findtext("description") or ""
    match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', description, re.IGNORECASE)
    if match and match.group(1).startswith("http"):
        return match.group(1)
    return None


async def _og_image(client: httpx.AsyncClient, link: str) -> Optional[str]:
    """The publisher's own picture for this article, or None.

    Reads only the head of the document: og:image is a meta tag, so the answer
    is in the first few KB and pulling a megabyte of article body to find it
    would be rude to them and slow for us.
    """
    now = datetime.now(timezone.utc).timestamp()
    hit = _IMAGE_CACHE.get(link)
    if hit and now - hit[0] < _IMAGE_TTL_SECONDS:
        return hit[1]

    found: Optional[str] = None
    try:
        async with _IMAGE_CONCURRENCY:
            response = await client.get(
            link,
                headers={"User-Agent": _USER_AGENT},
                timeout=_IMAGE_FETCH_TIMEOUT,
                follow_redirects=True,
            )
        head = response.text[:_HTML_HEAD_BYTES]
        for pattern in (_OG_IMAGE_RE, _OG_IMAGE_REVERSED_RE, _TWITTER_IMAGE_RE):
            match = pattern.search(head)
            if match:
                candidate = html.unescape(match.group(1).strip())
                if candidate.startswith("//"):
                    candidate = "https:" + candidate
                if candidate.startswith("http"):
                    found = candidate
                    break
    except Exception:
        # A publisher that is slow, blocking us, or serving something that is
        # not HTML costs this one picture. Nothing else.
        found = None

    _IMAGE_CACHE[link] = (now, found)
    return found


async def _attach_images(items: list[dict]) -> None:
    """Fill in `image_url` for the items that will show one.

    Bounded twice over — by how many are enriched and by a wall-clock budget —
    so a bad morning on somebody else's website can never hold up the club's
    home screen. Whatever has arrived when the budget runs out is what gets
    used.
    """
    pending = [i for i in items[:_IMAGES_PER_FEED] if not i.get("image_url")]
    if not pending:
        return
    try:
        async with httpx.AsyncClient() as client:
            results = await asyncio.wait_for(
                asyncio.gather(
                    *(_og_image(client, i["link"]) for i in pending),
                    return_exceptions=True,
                ),
                timeout=_IMAGE_BUDGET_SECONDS,
            )
        for item, result in zip(pending, results):
            if isinstance(result, str):
                item["image_url"] = result
    except Exception:
        logger.info("[news] image enrichment gave up within its budget")


async def _fetch(url: str) -> list[dict]:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            url,
            headers={"User-Agent": _USER_AGENT},
            timeout=_REQUEST_TIMEOUT,
            follow_redirects=True,
        )
    response.raise_for_status()
    items = parse_rss(response.text)
    await _attach_images(items)
    return items


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


import os

_firecrawl_cache: dict = {"items": [], "fetched_at": None}

async def _fetch_firecrawl(query: str, limit: int) -> list[dict]:
    api_key = os.getenv("FIRECRAWL_API_KEY")
    if not api_key:
        return []
        
    url = "https://api.firecrawl.dev/v1/search"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "query": query,
        "limit": limit
    }
    
    try:
        async with httpx.AsyncClient() as client:
            res = await client.post(
                url, 
                json=payload, 
                headers=headers, 
                timeout=_REQUEST_TIMEOUT,
                follow_redirects=True
            )
        res.raise_for_status()
        data = res.json().get("data", [])
        
        items = []
        for item in data:
            title = item.get("title")
            link = item.get("url")
            if not title or not link:
                continue
            
            # A search result is not always a news story. "kanyakumari news"
            # and "Kanyakumari district" are queries that came back as titles,
            # and putting them in a headline list tells a member the app does
            # not know what it is showing them.
            if _looks_like_a_query(title):
                continue

            items.append({
                "title": title,
                # The publisher, taken from the link — not the name of the
                # tool that fetched it. "Firecrawl" was appearing under every
                # headline as though it were a newspaper.
                "source": _publisher_from_url(link),
                "link": link,
                # Deliberately absent rather than invented.
                #
                # This used to be set to the moment of the fetch, so every
                # story in the list read "3m" no matter how old it was. A
                # fabricated timestamp is worse than none: it is the app
                # asserting a fact it does not have.
                "published_at": None,
            })
        return items
    except Exception as e:
        logger.warning(f"Firecrawl API failed: {e}")
        return []

async def _get_cached_firecrawl(cache_dict: dict, query: str, limit: int) -> list[dict]:
    from app.core.cache import get_valkey
    valkey = get_valkey()
    cache_key = f"news_cache:firecrawl:{query}"
    
    if valkey:
        cached_data = valkey.get(cache_key)
        if cached_data:
            try:
                items = json.loads(cached_data)
                for item in items:
                    if item.get("published_at"):
                        item["published_at"] = datetime.fromisoformat(item["published_at"])
                return items[:limit]
            except Exception as e:
                logger.warning(f"Valkey cache parse error for Firecrawl {query}: {e}")
                
    now = datetime.now(timezone.utc)
    is_stale = cache_dict["fetched_at"] is None or now - cache_dict["fetched_at"] > _CACHE_TTL
    if is_stale:
        items = await _fetch_firecrawl(query, limit)
        # Even if items is empty, we update cache so we don't spam the API on failure
        cache_dict["items"] = items
        cache_dict["fetched_at"] = now
        
        if valkey and items:
            class DateTimeEncoder(json.JSONEncoder):
                def default(self, obj):
                    if isinstance(obj, datetime):
                        return obj.isoformat()
                    return super().default(obj)
            valkey.setex(cache_key, int(_CACHE_TTL.total_seconds()), json.dumps(items, cls=DateTimeEncoder))
            
    return cache_dict["items"][:limit]


async def get_kanyakumari_news(limit: int = MAX_KANYAKUMARI_ITEMS) -> list[dict]:
    """Return up to `limit` Kanyakumari/Kanniyakumari local headlines (Tamil)."""
    # Fetch from both Google News RSS and Firecrawl concurrently
    rss_task = _get_cached(_kanyakumari_cache, KANYAKUMARI_NEWS_RSS_URL, limit)
    fc_task = _get_cached_firecrawl(_firecrawl_cache, "Kanyakumari news", limit)
    
    rss_items, fc_items = await asyncio.gather(rss_task, fc_task, return_exceptions=True)
    
    combined = []
    seen_urls = set()
    seen_titles = set()

    def _add(item: dict) -> None:
        # Two sources carrying the same story under different URLs is the
        # normal case, not the exception — which is why matching on the link
        # alone let the same headline appear twice in one list. Comparing the
        # words as well catches it.
        key = _title_key(item.get("title", ""))
        if item["link"] in seen_urls or (key and key in seen_titles):
            return
        combined.append(item)
        seen_urls.add(item["link"])
        if key:
            seen_titles.add(key)

    if not isinstance(rss_items, Exception):
        for item in rss_items:
            _add(item)

    if not isinstance(fc_items, Exception):
        for item in fc_items:
            _add(item)
                
    # Sort by published_at descending if available
    combined.sort(
        key=lambda x: x.get("published_at") or datetime.min.replace(tzinfo=timezone.utc), 
        reverse=True
    )
    
    return combined[:limit]
