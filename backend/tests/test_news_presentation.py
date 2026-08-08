"""How the news is shown, as opposed to where it comes from.

Sourcing is separate work the club is handling. These cover the three things
that made the list read as a search results page rather than as news.
"""
from app.services.news import (
    _looks_like_a_query, _publisher_from_url, _title_key,
)


class TestPublisher:
    """The masthead, not the tool that fetched it."""

    def test_the_domain_becomes_the_publisher(self):
        assert _publisher_from_url("https://www.dinamalar.com/news/1") == "Dinamalar"

    def test_mobile_subdomains_are_stripped(self):
        assert _publisher_from_url("https://m.thehindu.com/x") == "Thehindu"

    def test_a_missing_url_gives_nothing_rather_than_a_guess(self):
        assert _publisher_from_url("") == ""

    def test_the_scraper_is_never_the_answer(self):
        # A member reading "Firecrawl" under a headline reasonably concludes
        # that is who wrote it.
        for url in ["https://www.dinamalar.com/a", "https://maalaimalar.com/b"]:
            assert _publisher_from_url(url).lower() != "firecrawl"


class TestQueriesAreNotHeadlines:
    """A search term is not a story."""

    def test_a_bare_topic_is_dropped(self):
        assert _looks_like_a_query("kanyakumari news")
        assert _looks_like_a_query("Kanyakumari district")

    def test_a_real_headline_survives(self):
        assert not _looks_like_a_query(
            "Heavy rain puts Kanyakumari district on high alert")

    def test_the_filter_errs_towards_keeping(self):
        # Dropping a real story is worse than keeping a dull one.
        assert not _looks_like_a_query("Assembly debates the budget today")


class TestTheSameStoryTwice:
    """Two feeds carrying one story is the normal case."""

    def test_publisher_suffixes_do_not_make_it_a_different_story(self):
        a = _title_key("Heavy rain puts Kanyakumari on alert - Dinamalar")
        b = _title_key("Heavy rain puts Kanyakumari on alert | The Hindu")
        assert a == b

    def test_punctuation_and_case_are_ignored(self):
        assert _title_key("Rain Alert, Kanyakumari!") == _title_key(
            "rain alert kanyakumari")

    def test_different_stories_stay_different(self):
        assert _title_key("Rain alert in Kanyakumari") != _title_key(
            "Power cut in Nagercoil")

    def test_tamil_headlines_survive_normalisation(self):
        # The filter strips punctuation by character range; Tamil must not be
        # stripped along with it, or every Tamil story collapses to one key.
        a = _title_key("கன்னியாகுமரி மழை எச்சரிக்கை")
        b = _title_key("நாகர்கோவில் மின் தடை")
        assert a and b and a != b
