from app.services import news as service

_SAMPLE_RSS = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Tamil Nadu - Google News</title>
    <item>
      <title>Sample headline one - Example News</title>
      <link>https://news.google.com/rss/articles/sample-1</link>
      <pubDate>Mon, 16 Jun 2026 05:30:00 GMT</pubDate>
      <source url="https://example.com">Example News</source>
    </item>
    <item>
      <title>Sample headline two without a source tag - Another Outlet</title>
      <link>https://news.google.com/rss/articles/sample-2</link>
      <pubDate>Mon, 16 Jun 2026 04:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Headline missing a link</title>
      <pubDate>Mon, 16 Jun 2026 03:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>"""


def test_parse_rss_uses_source_tag_when_present():
    items = service.parse_rss(_SAMPLE_RSS)
    assert items[0]["title"] == "Sample headline one"
    assert items[0]["source"] == "Example News"
    assert items[0]["link"] == "https://news.google.com/rss/articles/sample-1"
    assert items[0]["published_at"] is not None


def test_parse_rss_falls_back_to_splitting_title():
    items = service.parse_rss(_SAMPLE_RSS)
    assert items[1]["title"] == "Sample headline two without a source tag"
    assert items[1]["source"] == "Another Outlet"


def test_parse_rss_skips_items_without_a_link():
    items = service.parse_rss(_SAMPLE_RSS)
    assert len(items) == 2


def test_get_top_tamil_news_caches_and_falls_back_on_failure(monkeypatch):
    calls = {"n": 0}

    def fake_fetch(url):
        calls["n"] += 1
        return service.parse_rss(_SAMPLE_RSS)

    monkeypatch.setattr(service, "_fetch", fake_fetch)
    service._cache["items"] = []
    service._cache["fetched_at"] = None

    first = service.get_top_tamil_news(limit=10)
    assert len(first) == 2
    assert calls["n"] == 1

    # Cache still fresh — second call should not re-fetch.
    second = service.get_top_tamil_news(limit=10)
    assert calls["n"] == 1
    assert second == first

    # Force staleness, but make the upstream fetch fail — should serve the
    # last good cache instead of raising.
    def failing_fetch(url):
        raise RuntimeError("upstream unreachable")

    monkeypatch.setattr(service, "_fetch", failing_fetch)
    service._cache["fetched_at"] = None
    third = service.get_top_tamil_news(limit=10)
    assert third == first


def test_get_top_tamil_news_respects_limit_and_max(monkeypatch):
    monkeypatch.setattr(service, "_fetch", lambda url: service.parse_rss(_SAMPLE_RSS))
    service._cache["items"] = []
    service._cache["fetched_at"] = None

    assert len(service.get_top_tamil_news(limit=1)) == 1
    assert len(service.get_top_tamil_news(limit=999)) <= service.MAX_ITEMS


def test_news_endpoint(client, monkeypatch):
    monkeypatch.setattr(service, "_fetch", lambda url: service.parse_rss(_SAMPLE_RSS))
    service._cache["items"] = []
    service._cache["fetched_at"] = None

    res = client.get("/api/v1/news/top")
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 2
    assert data[0]["source"] == "Example News"


def test_news_endpoint_limit_capped_at_ten(client):
    res = client.get("/api/v1/news/top", params={"limit": 50})
    assert res.status_code == 422  # exceeds le=10
