"""The places in the app, made findable.

A member typed "Events" into the search bar and got **No results found** — from
a search box whose own placeholder reads "Search services, events, and more",
on a screen that offers "Events" as a suggested query. Nothing was broken. The
search only ever matched the *titles of things*, and no event is called
"Events".

That is the gap this closes. An app with forty-odd screens has two kinds of
answer to a query, and it only ever had one:

* **things** — this event, that member, this tournament;
* **places** — the events page, the blood-donation hub, the complaint box.

Somebody who types "blood" almost never means a donor named Blood. They mean
*take me to the blood page*. Destinations are matched first and ranked above
content, because a place is a confident answer and a substring match on a
description is a guess.

Each entry carries its keywords in **both scripts**, so a Tamil speaker typing
"ரத்த" and an English speaker typing "blood" land on the same page — and so do
the near-misses people actually type: "donor", "blood bank", "O+".

Adding a screen to search is one entry in this list. That is the whole point:
the previous design required a new twenty-line block in the router for every
kind of thing, which is why fourteen screens were never searchable at all.
"""
from __future__ import annotations

from typing import NamedTuple


class Destination(NamedTuple):
    slug: str
    route: str
    title_en: str
    title_ta: str
    # Everything a member might reasonably type to mean this place. Lowercase;
    # matched by prefix and by word, never by exact equality alone.
    keywords: tuple[str, ...]
    # Nudges genuinely important places above incidental ones when two match
    # equally well. Emergency help outranks the settings screen.
    weight: int = 0


DESTINATIONS: tuple[Destination, ...] = (
    Destination(
        "events", "/events", "Events", "நிகழ்வுகள்",
        ("events", "event", "programme", "program", "function", "meeting",
         "register", "நிகழ்வு", "நிகழ்வுகள்", "விழா", "பதிவு"), 6),
    Destination(
        "blood", "/blood-donation", "Blood donation", "ரத்த தானம்",
        ("blood", "blood donation", "donor", "donors", "blood bank",
         "a+", "a-", "b+", "b-", "o+", "o-", "ab+", "ab-",
         "ரத்தம்", "ரத்த", "ரத்த தானம்", "தானம்"), 9),
    Destination(
        "sports", "/sports", "Sports & tournaments", "விளையாட்டு",
        ("sports", "sport", "tournament", "tournaments", "cricket", "match",
         "matches", "score", "scores", "scorecard", "standings", "fixtures",
         "விளையாட்டு", "போட்டி", "கிரிக்கெட்", "மதிப்பெண்"), 6),
    Destination(
        "chess", "/chess", "Chess", "சதுரங்கம்",
        ("chess", "chess tournament", "play chess", "சதுரங்கம்"), 5),
    Destination(
        "announcements", "/announcements", "Announcements", "அறிவிப்புகள்",
        ("announcements", "announcement", "notice", "notices", "news",
         "அறிவிப்பு", "அறிவிப்புகள்", "செய்தி"), 5),
    Destination(
        "feed", "/feed", "Community feed", "சமூக ஊட்டம்",
        ("feed", "posts", "post", "community feed", "timeline", "share",
         "பதிவுகள்", "ஊட்டம்"), 4),
    Destination(
        "members", "/members", "Members", "உறுப்பினர்கள்",
        ("members", "member", "roster", "people", "who is in",
         "உறுப்பினர்", "உறுப்பினர்கள்"), 4),
    Destination(
        "directory", "/directory", "Phone directory", "தொலைபேசி அடைவு",
        ("directory", "contacts", "contact", "phone numbers", "phone book",
         "அடைவு", "தொலைபேசி", "தொடர்பு"), 4),
    Destination(
        "work", "/work", "Jobs & skills", "வேலை & திறன்",
        ("work", "jobs", "job", "skills", "skill", "employment", "hiring",
         "electrician", "plumber", "carpenter", "tailor", "driver",
         "வேலை", "திறன்", "வேலைவாய்ப்பு"), 6),
    Destination(
        "opportunities", "/opportunities", "Scholarships & opportunities",
        "வாய்ப்புகள்",
        ("opportunities", "opportunity", "scholarship", "scholarships",
         "internship", "training", "வாய்ப்பு", "வாய்ப்புகள்", "உதவித்தொகை"), 5),
    Destination(
        "green", "/green", "Green FYC", "பசுமை FYC",
        ("green", "tree", "trees", "plantation", "plant a tree", "sapling",
         "environment", "மரம்", "மரங்கள்", "பசுமை", "நடவு"), 5),
    Destination(
        "gallery", "/gallery", "Photo gallery", "புகைப்பட தொகுப்பு",
        ("gallery", "photos", "photo", "pictures", "images", "album",
         "புகைப்படம்", "புகைப்படங்கள்", "தொகுப்பு"), 4),
    Destination(
        "report-issue", "/issues/report", "Report a problem", "புகார் அளிக்க",
        ("complaint", "complaints", "complain", "report", "report a problem",
         "issue", "issues", "problem", "grievance", "pothole", "street light",
         "water", "garbage", "drainage",
         "புகார்", "பிரச்சனை", "குறை", "தெரு விளக்கு", "குடிநீர்", "குப்பை"), 7),
    Destination(
        "track-issue", "/issues/track", "Track my complaint",
        "என் புகார் நிலை",
        ("track complaint", "my complaint", "complaint status", "follow up",
         "புகார் நிலை", "என் புகார்"), 5),
    Destination(
        "sos", "/sos", "Emergency help (SOS)", "அவசர உதவி",
        ("sos", "emergency", "help", "danger", "ambulance", "police", "fire",
         "urgent", "அவசரம்", "அவசர உதவி", "உதவி", "காவல்", "ஆம்புலன்ஸ்"), 10),
    Destination(
        "safety", "/settings/safety", "Safety settings", "பாதுகாப்பு அமைப்பு",
        ("safety", "safety settings", "emergency contacts", "trusted contacts",
         "பாதுகாப்பு"), 3),
    Destination(
        "profile", "/me", "My profile", "என் சுயவிவரம்",
        ("profile", "my profile", "my account", "me", "account",
         "சுயவிவரம்", "என் கணக்கு"), 4),
    Destination(
        "membership", "/membership", "Membership card", "உறுப்பினர் அட்டை",
        ("membership", "membership card", "id card", "my card",
         "உறுப்பினர் அட்டை", "அட்டை"), 4),
    Destination(
        "certificate", "/certificate", "Volunteer certificate", "சான்றிதழ்",
        ("certificate", "volunteer certificate", "சான்றிதழ்"), 3),
    Destination(
        "journey", "/journey", "My journey", "என் பயணம்",
        ("journey", "my journey", "my activity", "contributions",
         "பயணம்", "என் பயணம்"), 3),
    Destination(
        "notifications", "/notifications", "Notifications", "அறிவிப்புகள்",
        ("notifications", "notification", "alerts", "inbox",
         "அறிவிப்புகள்"), 3),
    Destination(
        "settings", "/settings", "Settings", "அமைப்புகள்",
        ("settings", "preferences", "language", "change language", "logout",
         "sign out", "அமைப்புகள்", "மொழி"), 3),
    Destination(
        "scan", "/scan", "Scan QR code", "QR ஸ்கேன்",
        ("scan", "qr", "qr code", "check in", "checkin", "ஸ்கேன்"), 3),
    Destination(
        "about", "/about", "About FYC", "FYC பற்றி",
        ("about", "about fyc", "who we are", "contact us", "பற்றி"), 2),
)
