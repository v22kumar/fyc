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
