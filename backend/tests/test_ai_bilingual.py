"""The AI digest/news parser produces Tamil + English (and a backward-compatible
`summary` alias), tolerating markdown fences and a single-summary reply."""
from app.services.ai_service import _parse_bilingual


def test_parses_bilingual_json():
    out = _parse_bilingual('{"summary_en": "Hello", "summary_ta": "வணக்கம்"}')
    assert out["summary_en"] == "Hello"
    assert out["summary_ta"] == "வணக்கம்"
    assert out["summary"] == "Hello"  # legacy alias mirrors English


def test_strips_markdown_fence_and_keeps_extra_keys():
    raw = '```json\n{"summary_en": "News", "summary_ta": "செய்தி", "trending_topics": ["A", "B"]}\n```'
    out = _parse_bilingual(raw, keep=("trending_topics",))
    assert out["summary_ta"] == "செய்தி"
    assert out["trending_topics"] == ["A", "B"]


def test_falls_back_to_single_summary():
    out = _parse_bilingual('{"summary": "Only English"}')
    assert out["summary_en"] == "Only English"
    assert out["summary"] == "Only English"
    assert out["summary_ta"] == ""  # no Tamil provided
