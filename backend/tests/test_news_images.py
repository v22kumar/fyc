"""News that looks like news.

Google News RSS carries no images — its <description> is a list of links, its
items have no media:content and no enclosure. That is why the club's news card
has always been a wall of text while every news app people actually use is led
by pictures.

The picture lives on the publisher's page, in the og:image meta tag that exists
for exactly this purpose. These pin the three rules that keep fetching it from
becoming a liability: never on the critical path, only for the few items that
show one, and remembered so it is fetched once.
"""
import asyncio

import pytest

from app.services import news as service


def test_a_feed_that_does_carry_a_picture_is_read(monkeypatch):
    """Google News does not, but these feeds get swapped and extended."""
    xml = """<?xml version="1.0"?>
    <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
      <item>
        <title>Headline one - The Hindu</title>
        <link>https://example.test/a</link>
        <media:content url="https://cdn.example.test/a.jpg"/>
      </item>
      <item>
        <title>Headline two - NDTV</title>
        <link>https://example.test/b</link>
        <enclosure url="https://cdn.example.test/b.jpg" type="image/jpeg"/>
      </item>
      <item>
        <title>Headline three - PW</title>
        <link>https://example.test/c</link>
        <description>&lt;img src="https://cdn.example.test/c.jpg"/&gt; text</description>
      </item>
    </channel></rss>"""
    items = service.parse_rss(xml)
    assert [i["image_url"] for i in items] == [
        "https://cdn.example.test/a.jpg",
        "https://cdn.example.test/b.jpg",
        "https://cdn.example.test/c.jpg",
    ]


def test_no_picture_is_not_an_error():
    """A headline without a picture is still news."""
    xml = """<?xml version="1.0"?><rss><channel>
      <item><title>Plain - NDTV</title><link>https://example.test/x</link></item>
    </channel></rss>"""
    items = service.parse_rss(xml)
    assert items[0]["image_url"] is None
    assert items[0]["title"] == "Plain"


@pytest.mark.parametrize("head,expected", [
    ('<meta property="og:image" content="https://cdn.test/1.jpg">',
     "https://cdn.test/1.jpg"),
    ('<meta content="https://cdn.test/2.jpg" property="og:image">',
     "https://cdn.test/2.jpg"),
    ('<meta name="twitter:image" content="https://cdn.test/3.jpg">',
     "https://cdn.test/3.jpg"),
    ('<meta property="og:image" content="//cdn.test/4.jpg">',
     "https://cdn.test/4.jpg"),
    ('<title>no picture here</title>', None),
])
def test_the_publishers_own_picture_is_found(head, expected, monkeypatch):
    class _Response:
        text = head
        # The real httpx response carries the final URL after redirects, and
        # the resolver reads it to notice when it has landed on Google rather
        # than the publisher.
        url = "https://www.publisher.test/article"

    class _Client:
        async def get(self, *a, **k):
            return _Response()

    service._IMAGE_CACHE.clear()
    got = asyncio.run(service._og_image(_Client(), "https://example.test/article"))
    assert got == expected


def test_a_publisher_that_hangs_costs_one_picture_and_nothing_else():
    """The rule that matters most: headlines are never held up."""
    class _Client:
        async def get(self, *a, **k):
            raise TimeoutError("publisher is slow")

    service._IMAGE_CACHE.clear()
    got = asyncio.run(service._og_image(_Client(), "https://example.test/slow"))
    assert got is None


def test_a_picture_is_looked_up_once_and_remembered():
    """An article's picture does not change; the news refreshes every 30 min."""
    calls = {"n": 0}

    class _Response:
        text = '<meta property="og:image" content="https://cdn.test/once.jpg">'
        url = "https://www.publisher.test/article"

    class _Client:
        async def get(self, *a, **k):
            calls["n"] += 1
            return _Response()

    service._IMAGE_CACHE.clear()
    first = asyncio.run(service._og_image(_Client(), "https://example.test/z"))
    second = asyncio.run(service._og_image(_Client(), "https://example.test/z"))
    assert first == second == "https://cdn.test/once.jpg"
    assert calls["n"] == 1, "the second read must come from memory"


def test_enrichment_stops_at_the_items_that_show_a_picture():
    """Nobody scrolls forty items on a home screen, and each one is a request
    to somebody else's server."""
    items = [{"link": f"https://example.test/{i}", "image_url": None}
             for i in range(30)]
    asked = []

    async def _fake(client, link):
        asked.append(link)
        return None

    service._IMAGE_CACHE.clear()
    original = service._og_image
    service._og_image = _fake
    try:
        asyncio.run(service._attach_images(items))
    finally:
        service._og_image = original

    assert len(asked) == service._IMAGES_PER_FEED


def test_the_google_pointer_is_unwrapped_to_the_publisher():
    """Why the first attempt produced no pictures at all.

    An RSS <link> is `news.google.com/rss/articles/CBMi...` — Google's pointer,
    which a browser resolves and a server does not. Fetching it lands on
    Google's own page, which carries no publisher og:image, so every headline
    came back blank.

    Google hands over the real address anyway: as an anchor inside the
    HTML-escaped <description>.
    """
    xml = """<?xml version="1.0"?><rss><channel>
      <item>
        <title>Vivek Express cancelled - Daily Thanthi</title>
        <link>https://news.google.com/rss/articles/CBMiABCDEF?oc=5</link>
        <description>&lt;a href="https://www.dailythanthi.com/news/real"&gt;H&lt;/a&gt;
          &lt;font color="#6f6f6f"&gt;Daily Thanthi&lt;/font&gt;</description>
        <source url="https://www.dailythanthi.com">Daily Thanthi</source>
      </item>
    </channel></rss>"""
    item = service.parse_rss(xml)[0]
    assert item["_publisher_url"] == "https://www.dailythanthi.com/news/real"
    assert item["link"].startswith("https://news.google.com"), \
        "the tap target stays Google's, which works fine in a browser"


def test_the_masthead_is_the_last_resort_not_a_blank():
    """No anchor in the description: fall back to the publisher's home page.

    A masthead is a poor picture and an honest one — better than a blank hero.
    """
    xml = """<?xml version="1.0"?><rss><channel>
      <item>
        <title>Something - News18</title>
        <link>https://news.google.com/rss/articles/XYZ</link>
        <source url="https://tamil.news18.com">News18 Tamil</source>
      </item>
    </channel></rss>"""
    assert service.parse_rss(xml)[0]["_publisher_url"] == "https://tamil.news18.com"


def test_a_google_link_inside_the_description_is_not_mistaken_for_a_publisher():
    xml = """<?xml version="1.0"?><rss><channel>
      <item>
        <title>X - Y</title>
        <link>https://news.google.com/rss/articles/A</link>
        <description>&lt;a href="https://news.google.com/stories/B"&gt;X&lt;/a&gt;</description>
      </item>
    </channel></rss>"""
    assert service.parse_rss(xml)[0]["_publisher_url"] is None


def test_the_report_says_whether_pictures_are_arriving():
    """"No images" had three possible causes and no way to tell them apart."""
    service._kanyakumari_cache["items"] = [
        {"title": "a", "image_url": "https://cdn/x.jpg", "_publisher_url": "https://p/1"},
        {"title": "b", "image_url": None, "_publisher_url": "https://p/2"},
        {"title": "c", "image_url": None, "_publisher_url": None},
    ]
    report = service.image_report()["feeds"]["kanyakumari"]
    assert report["items"] == 3
    assert report["with_image"] == 1
    assert report["publisher_url_resolved"] == 2
    # Counts only — never a headline, a link or an image address.
    assert "cdn" not in str(report)


def test_the_report_reads_the_cache_that_is_actually_serving(monkeypatch):
    """The correction that makes this diagnostic honest.

    `_get_cached` returns from Valkey *before* it touches the in-process dicts.
    So the first version of this report read a cache that is never populated on
    a deployment with Valkey configured, and answered "0 items, never fetched"
    for every feed while the app was visibly full of news. A diagnostic that
    reports nothing when everything is working sends you hunting a bug that is
    not there.
    """
    import json as _json

    served = [
        {"title": "a", "image_url": "https://cdn/1.jpg", "_publisher_url": "https://p/1"},
        {"title": "b", "image_url": "https://cdn/2.jpg", "_publisher_url": "https://p/2"},
    ]

    class _Valkey:
        def get(self, key):
            return _json.dumps(served) if "news_cache:" in key else None

    monkeypatch.setattr("app.core.cache.get_valkey", lambda: _Valkey())
    # The in-process dict is empty, exactly as it is in production.
    service._cache["items"] = []
    service._cache["fetched_at"] = None

    report = service.image_report()
    assert report["valkey_in_use"] is True
    tamil = report["feeds"]["tamil"]
    assert tamil["items"] == 2, "must count what is being served, not what is not"
    assert tamil["with_image"] == 2
    assert tamil["served_from"] == "valkey"


def test_zeros_are_readable_because_the_report_says_where_it_looked():
    """Zeros meant two different things and looked identical."""
    report = service.image_report()
    assert "valkey_in_use" in report
    assert all("served_from" in f for f in report["feeds"].values())
