"""One query in, one ranked list out.

What this replaces: a router that ran seven hand-written blocks, each with its
own `ilike('%q%')` and its own `.limit(10)`, and returned them concatenated in
the order the code happened to run. That design had four faults, and the one
the club actually hit was the first:

* **Only things, never places.** Typing "Events" found nothing, because no event
  is titled "Events". See `search_destinations.py` — that is the fix, and it is
  the reason this rewrite exists.
* **No ranking.** An event whose *title* is exactly the query sorted below a
  tournament that merely mentions it in a description, because tournaments ran
  first. Relevance was an accident of statement order.
* **Fourteen screens unreachable.** Posts, work listings, opportunities, chess
  tournaments, plantation drives and the phone directory were never searched at
  all — adding a type meant writing another twenty-line block, so nobody did.
* **Substring only.** `%q%` matches the middle of a word as readily as the
  start, so "an" ranked a hundred rows identically and returned the first ten
  by insertion order.

The shape now: the database is asked a broad, cheap question (does this row
contain the query anywhere?) with a bounded candidate set per source, and
**ranking happens here, in one place, by one function**. At a club's scale —
thousands of rows, not millions — that is both fast and honest. It also keeps
the SQL portable, which matters because the tests run on SQLite and production
is Postgres.

Adding a searchable thing is one entry in `_SOURCES`. That is the whole design
goal: the previous version made adding a type expensive, and so it never
happened.
"""
from __future__ import annotations

import logging
import re
from typing import Any, Callable, NamedTuple, Optional
from uuid import UUID

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.services.search_destinations import DESTINATIONS

logger = logging.getLogger(__name__)

# How many rows each source may contribute before ranking. Generous enough that
# the best answer is inside the candidate set, small enough that a one-letter
# query cannot drag the whole table into memory.
_CANDIDATES_PER_SOURCE = 25

# What comes back. Everything is capped here so a broad query stays one screen.
_MAX_RESULTS = 30

_WORD = re.compile(r"[^\w஀-௿]+", re.UNICODE)


def _norm(text: str) -> str:
    return " ".join(_WORD.split((text or "").strip().lower())).strip()


def score(query: str, *fields: Optional[str]) -> int:
    """How well does this row answer this query?

    Four tiers, and the order is the whole point — it is what the old
    `ilike('%q%')` could not express, because to it every one of these was
    simply "true":

    * **exact** — the field *is* the query. "Chess" for a tournament called
      Chess. Nothing beats this.
    * **starts with** — what someone typing a name expects to see first.
    * **a word starts with it** — "kumar" finding "Arun Kumar", "meet" finding
      "Annual Sports Meet". This is the tier real queries usually land in, and
      the one substring matching flattened away.
    * **contains** — the desperate tier. Kept, because it does sometimes find
      the thing, but it must never outrank a title.

    A short field that matches beats a long one: the query is a larger share of
    a title than of a paragraph, so a title match is more likely to be the
    thing meant.
    """
    q = _norm(query)
    if not q:
        return 0
    best = 0
    for field in fields:
        text = _norm(field or "")
        if not text or q not in text:
            continue
        if text == q:
            tier = 100
        elif text.startswith(q):
            tier = 75
        elif any(word.startswith(q) for word in text.split()):
            tier = 55
        else:
            tier = 25
        # Up to 10 points for the query being most of the field rather than a
        # fragment of an essay.
        density = int(10 * len(q) / max(len(text), 1))
        best = max(best, tier + density)
    return best


class Hit(NamedTuple):
    id: str
    type: str
    title: str
    subtitle: Optional[str]
    image_url: Optional[str]
    route: str
    score: int


class Source(NamedTuple):
    """One searchable kind of thing.

    `columns` are asked of the database; `rank_on` are scored here. They differ
    on purpose: a description is worth *finding* by, but scoring a title and a
    paragraph on the same footing is exactly how the old version let a passing
    mention outrank an exact name.
    """
    type: str
    model: Any
    columns: Callable[[Any], list]
    rank_on: Callable[[Any], list]
    present: Callable[[Any], tuple]  # -> (title, subtitle, image_url, route)
    weight: int = 0
    tenant_column: str = "organization_id"


def _sources() -> list[Source]:
    # Imported here so this module can be read without dragging in every model.
    from app.models.announcement import Announcement
    from app.models.blood_donor import BloodDonor
    from app.models.chess_tournament import ChessTournament
    from app.models.directory import DirectoryContact
    from app.models.event import Event
    from app.models.green_fyc import PlantationDrive
    from app.models.issue import PublicIssue
    from app.models.opportunity import Opportunity
    from app.models.post import Post
    from app.models.sports import Team, Tournament
    from app.models.work import Listing

    return [
        Source(
            "EVENT", Event,
            lambda m: [m.title_en, m.title_ta, m.description_en, m.description_ta],
            lambda r: [r.title_en, r.title_ta],
            lambda r: (r.title_en or r.title_ta, "Event", r.banner_url, "/events"),
            weight=6,
        ),
        Source(
            "ANNOUNCEMENT", Announcement,
            lambda m: [m.title_en, m.title_ta, m.body_en, m.body_ta],
            lambda r: [r.title_en, r.title_ta],
            lambda r: (r.title_en or r.title_ta, "Announcement", None,
                       "/announcements"),
            weight=5,
        ),
        Source(
            "TOURNAMENT", Tournament,
            lambda m: [m.name_en, m.name_ta, m.sport],
            lambda r: [r.name_en, r.name_ta, r.sport],
            lambda r: (r.name_en or r.name_ta, f"Tournament · {r.sport}", None,
                       "/sports"),
            weight=5,
        ),
        Source(
            "TEAM", Team,
            lambda m: [m.name],
            lambda r: [r.name],
            lambda r: (r.name, "Team", r.logo_url, "/sports"),
            weight=3,
        ),
        Source(
            "CHESS_TOURNAMENT", ChessTournament,
            lambda m: [m.name, m.description, m.short_code],
            lambda r: [r.name, r.short_code],
            lambda r: (r.name, "Chess tournament", None, "/chess"),
            weight=4,
        ),
        Source(
            "WORK", Listing,
            lambda m: [m.display_name, m.category, m.about, m.area],
            lambda r: [r.display_name, r.category],
            lambda r: (r.display_name, f"{r.category or 'Work'}"
                       + (f" · {r.area}" if r.area else ""), None, "/work"),
            weight=5,
        ),
        Source(
            "OPPORTUNITY", Opportunity,
            lambda m: [m.title_en, m.title_ta, m.description_en,
                       m.organizer_en, m.category_en],
            lambda r: [r.title_en, r.title_ta],
            lambda r: (r.title_en or r.title_ta,
                       r.organizer_en or "Opportunity", None, "/opportunities"),
            weight=4,
        ),
        Source(
            "DIRECTORY", DirectoryContact,
            lambda m: [m.name_en, m.name_ta, m.designation_en, m.designation_ta,
                       m.category, m.phone_primary],
            lambda r: [r.name_en, r.name_ta, r.designation_en],
            lambda r: (r.name_en or r.name_ta,
                       r.designation_en or r.category or "Contact", None,
                       "/directory"),
            weight=4,
        ),
        Source(
            "PLANTATION", PlantationDrive,
            lambda m: [m.title_en, m.title_ta, m.description_en, m.location_en],
            lambda r: [r.title_en, r.title_ta],
            lambda r: (r.title_en or r.title_ta, "Plantation drive",
                       r.banner_url, "/green"),
            weight=3,
        ),
        Source(
            "POST", Post,
            lambda m: [m.content, m.category, m.location],
            lambda r: [r.content],
            lambda r: ((r.content or "")[:70], "Post", None, "/feed"),
            weight=2,
        ),
        Source(
            "ISSUE", PublicIssue,
            lambda m: [m.description_en, m.description_ta],
            lambda r: [r.description_en, r.description_ta],
            lambda r: ((r.description_en or r.description_ta or "Issue")[:70],
                       "Reported problem", r.photo_url, "/issues"),
            weight=2,
        ),
        Source(
            "BLOOD_DONOR", BloodDonor,
            lambda m: [m.blood_group],
            lambda r: [r.blood_group],
            lambda r: (f"{r.blood_group} donor", "Blood donor", None,
                       "/blood-donation"),
            weight=3,
        ),
    ]


def _search_destinations(query: str, lang: str) -> list[Hit]:
    """Places, matched on their keywords rather than on stored text.

    Ranked above content on equal footing, and deliberately so: somebody typing
    "blood" wants the blood page, not a member whose description mentions it. A
    place is a confident answer; a substring match on a paragraph is a guess.
    """
    hits = []
    for dest in DESTINATIONS:
        best = score(query, dest.title_en, dest.title_ta, *dest.keywords)
        if not best:
            continue
        hits.append(Hit(
            id=dest.slug,
            type="DESTINATION",
            title=dest.title_ta if lang == "ta" else dest.title_en,
            subtitle=None,
            image_url=None,
            route=dest.route,
            # The floor keeps any matched place above every content match, so
            # "Events" opens the events page instead of burying it under three
            # events that mention the word.
            score=200 + best + dest.weight,
        ))
    return hits


def _search_people(db: Session, query: str, tenant_id: UUID) -> list[Hit]:
    from app.models.user import User, UserProfile
    like = f"%{query.strip()}%"
    rows = (
        db.query(UserProfile)
        .join(UserProfile.user)
        .filter(
            User.organization_id == tenant_id,
            or_(User.source.is_(None), User.source != "F2S_IMPORT"),
            or_(UserProfile.full_name_en.ilike(like),
                UserProfile.full_name_ta.ilike(like)),
        )
        .limit(_CANDIDATES_PER_SOURCE)
        .all()
    )
    hits = []
    for row in rows:
        best = score(query, row.full_name_en, row.full_name_ta)
        if not best:
            continue
        hits.append(Hit(
            id=str(row.user_id), type="USER",
            title=row.full_name_en or row.full_name_ta or "Member",
            subtitle="Member", image_url=row.profile_image_url,
            # A member's own page, not the roster. Finding a person and being
            # dropped at a list of everybody is not an answer.
            route=f"/members/{row.user_id}", score=best + 5,
        ))
    return hits


def _isolated(kind: str, run: Callable[[], list[Hit]]) -> list[Hit]:
    """Run one source; if it fails, lose that source and nothing else.

    Search fans out across a dozen tables in a single request, and
    `db.query(Model)` is `SELECT *` — so one column that has drifted out of
    step with the model takes down **every** result, including the ones that
    were fine. That is what happened the first time this shipped: a search box
    that answered "Failed to load results" for every query, because of one
    table nobody was searching for.

    A search that returns most of the answers is worth far more than one that
    returns an error page. The failure is swallowed here and reported at
    `/api/health/search`, which names the broken source instead of leaving
    somebody to guess.
    """
    try:
        return run()
    except Exception:  # noqa: BLE001 — one bad table must not blank the page
        logger.exception("search source %s failed", kind)
        return []


def _search_source(db: Session, src: Source, query: str, like: str,
                   tenant_id: UUID) -> list[Hit]:
    tenant_col = getattr(src.model, src.tenant_column, None)
    q = db.query(src.model)
    if tenant_col is not None:
        q = q.filter(tenant_col == tenant_id)
    conditions = [c.ilike(like) for c in src.columns(src.model) if c is not None]
    if not conditions:
        return []
    rows = q.filter(or_(*conditions)).limit(_CANDIDATES_PER_SOURCE).all()
    hits = []
    for row in rows:
        best = score(query, *src.rank_on(row))
        if not best:
            # Matched only on a field we do not rank (a description, an
            # address). Still a real find, just a weak one.
            best = 15
        title, subtitle, image_url, route = src.present(row)
        if not title:
            continue
        hits.append(Hit(
            id=str(row.id), type=src.type, title=title, subtitle=subtitle,
            image_url=image_url, route=route, score=best + src.weight,
        ))
    return hits


def probe(db: Session) -> dict[str, str]:
    """Which sources can actually be queried right now.

    Production is unreachable from a development machine, so "search is
    failing" needs to become "this table is failing" without anybody having to
    read a log. One trivial query per source; the exception class is the
    finding. Names only — never a row, never a value.
    """
    report: dict[str, str] = {}
    for src in _sources():
        try:
            db.query(src.model).limit(1).all()
            report[src.type] = "ok"
        except Exception as exc:  # noqa: BLE001 — the failure IS the finding
            report[src.type] = type(exc).__name__
    try:
        from app.models.user import UserProfile
        db.query(UserProfile).limit(1).all()
        report["USER"] = "ok"
    except Exception as exc:  # noqa: BLE001
        report["USER"] = type(exc).__name__
    return report


def search(db: Session, query: str, tenant_id: UUID, *,
           lang: str = "en", types: Optional[list[str]] = None) -> list[Hit]:
    """Everything that answers this query, best first."""
    query = (query or "").strip()
    if len(query) < 2:
        return []

    wanted = {t.upper() for t in types} if types else None

    def allowed(kind: str) -> bool:
        return wanted is None or kind in wanted

    hits: list[Hit] = []

    # Places first, and they cannot fail: pure Python over a static list, no
    # database involved. Whatever else is broken, "Events" still opens the
    # events page.
    if allowed("DESTINATION"):
        hits += _search_destinations(query, lang)

    if allowed("USER"):
        hits += _isolated("USER", lambda: _search_people(db, query, tenant_id))

    like = f"%{query}%"
    for src in _sources():
        if not allowed(src.type):
            continue
        hits += _isolated(
            src.type, lambda s=src: _search_source(db, s, query, like, tenant_id))

    hits.sort(key=lambda h: (-h.score, h.title.lower()))
    return hits[:_MAX_RESULTS]
