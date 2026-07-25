"""The backend string registry resolves per-language with English fallback,
fills placeholders, and normalizes locale tags. Adding a language = adding
entries; English stays the source of truth."""
from app.core import i18n


def test_resolves_requested_language():
    assert i18n.t("digest.evening.title", "ta") == i18n.MESSAGES["digest.evening.title"]["ta"]
    assert i18n.t("digest.evening.title", "en") == i18n.MESSAGES["digest.evening.title"]["en"]


def test_falls_back_to_english_for_missing_language():
    # 'fr' is not a registered language -> English.
    assert i18n.t("error.account_not_found", "fr") == i18n.MESSAGES["error.account_not_found"]["en"]


def test_unknown_key_returns_none():
    assert i18n.t("no.such.key", "en") is None


def test_placeholder_substitution():
    assert i18n.t("digest.thirukkural.title", "en", n=42) == "Daily Thirukkural (Kural #42)"


def test_normalizes_locale_tags():
    assert i18n._norm("ta-IN") == "ta"
    assert i18n._norm("TA") == "ta"
    assert i18n._norm(None) == "en"
    assert i18n._norm("fr") == "en"


def test_resolve_lang_prefers_user_then_header():
    class U:
        preferred_language = "ta"
    assert i18n.resolve_lang("en-US,en;q=0.9", U()) == "ta"   # user wins
    assert i18n.resolve_lang("ml-IN,ml;q=0.9", None) == "ml"  # header
    assert i18n.resolve_lang(None, None) == "en"              # default


def test_english_is_the_superset():
    # Every message must have an English entry (the guaranteed fallback).
    for key, langs in i18n.MESSAGES.items():
        assert "en" in langs, f"{key} missing English"
