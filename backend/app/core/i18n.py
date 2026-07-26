"""Central backend string registry — the server-side twin of the mobile
`lib/core/l10n/registry`.

Every user-facing server string (push/notification templates, API error
messages) lives here keyed by a stable id, with one entry per language.

**To add a language** (say Hindi where it's missing, or a brand-new one):
add its code to the inner dict of each message. Missing translations fall back
to English, so a language can be filled in progressively — nothing ever renders
blank. `REGISTERED_LANGS` lists the languages the app offers.

Usage:
    from app.core import i18n
    i18n.t("digest.evening.title", "ta")                      # -> Tamil title
    i18n.t("digest.thirukkural.title", lang, n=kural_number)  # {placeholder}s
    i18n.resolve_lang(accept_language_header, user)           # pick a language
"""
from __future__ import annotations

from typing import Dict, Optional

REGISTERED_LANGS = ["en", "ta", "hi", "ml"]

# id -> {lang_code: template}. English is the source of truth / fallback.
MESSAGES: Dict[str, Dict[str, str]] = {
    # ── Scheduled digests / broadcasts ──────────────────────────────────────
    "digest.thirukkural.title": {
        "en": "Daily Thirukkural (Kural #{n})",
        "ta": "இன்றைய திருக்குறள் (குறள் {n})",
        "hi": "आज का तिरुक्कुरल (कुरल #{n})",
        "ml": "ഇന്നത്തെ തിരുക്കുറൾ (കുറൾ #{n})",
    },
    "digest.news.title": {
        "en": "Latest News 📰",
        "ta": "முக்கிய செய்திகள் 📰",
        "hi": "ताज़ा समाचार 📰",
        "ml": "പുതിയ വാർത്തകൾ 📰",
    },
    "digest.evening.title": {
        "en": "Evening Digest 🌙",
        "ta": "மாலை சுருக்கம் 🌙",
        "hi": "संध्या सारांश 🌙",
        "ml": "സായാഹ്ന സംഗ്രഹം 🌙",
    },
    "digest.evening.body": {
        "en": "Review the updates and achievements from today.",
        "ta": "இன்றைய புதுப்பிப்புகள் மற்றும் சாதனைகளை மதிப்பாய்வு செய்யவும்.",
        "hi": "आज की अपडेट और उपलब्धियों की समीक्षा करें।",
        "ml": "ഇന്നത്തെ അപ്ഡേറ്റുകളും നേട്ടങ്ങളും അവലോകനം ചെയ്യുക.",
    },
    # ── API error messages (user-facing HTTPException detail) ────────────────
    "error.invalid_credentials": {
        "en": "Invalid credentials",
        "ta": "தவறான உள்நுழைவு விவரங்கள்",
        "hi": "अमान्य क्रेडेंशियल",
        "ml": "അസാധുവായ ക്രെഡൻഷ്യലുകൾ",
    },
    "error.phone_already_registered": {
        "en": "This phone number is already registered under another account.",
        "ta": "இந்த தொலைபேசி எண் ஏற்கனவே மற்றொரு கணக்கில் பதிவு செய்யப்பட்டுள்ளது.",
        "hi": "यह फ़ोन नंबर पहले से किसी अन्य खाते में पंजीकृत है।",
        "ml": "ഈ ഫോൺ നമ്പർ മറ്റൊരു അക്കൗണ്ടിൽ ഇതിനകം രജിസ്റ്റർ ചെയ്തിട്ടുണ്ട്.",
    },
    "error.account_not_found": {
        "en": "Account not found",
        "ta": "கணக்கு கிடைக்கவில்லை",
        "hi": "खाता नहीं मिला",
        "ml": "അക്കൗണ്ട് കണ്ടെത്തിയില്ല",
    },
    "error.invalid_or_expired_token": {
        "en": "Invalid or expired token",
        "ta": "தவறான அல்லது காலாவதியான டோக்கன்",
        "hi": "अमान्य या समाप्त टोकन",
        "ml": "അസാധുവായ അല്ലെങ്കിൽ കാലഹരണപ്പെട്ട ടോക്കൺ",
    },
    "error.not_authenticated": {
        "en": "Not authenticated",
        "ta": "அங்கீகரிக்கப்படவில்லை",
        "hi": "प्रमाणित नहीं",
        "ml": "പ്രാമാണീകരിച്ചിട്ടില്ല",
    },
    "error.permission_denied": {
        "en": "You don't have permission to perform this action",
        "ta": "இந்த செயலைச் செய்ய உங்களுக்கு அனுமதி இல்லை",
        "hi": "यह कार्य करने की आपको अनुमति नहीं है",
        "ml": "ഈ പ്രവർത്തനം നടത്താൻ നിങ്ങൾക്ക് അനുമതിയില്ല",
    },
    "error.organization_required": {
        "en": "X-Organization-ID header is required",
        "ta": "X-Organization-ID தலைப்பு தேவை",
        "hi": "X-Organization-ID हेडर आवश्यक है",
        "ml": "X-Organization-ID ഹെഡർ ആവശ്യമാണ്",
    },
}


def _norm(lang: Optional[str]) -> str:
    """Normalise 'ta-IN', 'TA', None → a registered base code (or 'en')."""
    if not lang:
        return "en"
    base = lang.strip().lower().replace("_", "-").split("-", 1)[0]
    return base if base in REGISTERED_LANGS else ("en" if base not in MESSAGES else base)


def t(key: str, lang: Optional[str] = "en", **params) -> Optional[str]:
    """Resolve a registered message in `lang`, else English. Returns None if the
    key is unknown (callers can then fall back to a literal). `params` fill
    `{placeholder}` tokens."""
    entry = MESSAGES.get(key)
    if not entry:
        return None
    code = _norm(lang)
    text = entry.get(code) or entry.get("en")
    if text is None:
        return None
    return text.format(**params) if params else text


def resolve_lang(accept_language: Optional[str] = None, user=None) -> str:
    """Pick the best language: an authenticated user's saved preference wins;
    otherwise the request's Accept-Language; otherwise English."""
    pref = getattr(user, "preferred_language", None)
    if pref:
        return _norm(pref)
    if accept_language:
        # Take the first, highest-priority tag (ignore q-weights — good enough).
        first = accept_language.split(",", 1)[0]
        return _norm(first)
    return "en"
