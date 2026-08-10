"""Search, which was answering "No results found" to its own suggested query.

A member typed **Events** into a box whose placeholder reads "Search services,
events, and more", on a screen that offers "Events" as a suggestion, and got
nothing. Nothing was broken: search only ever matched the titles of *things*,
and no event is titled "Events".
"""
import uuid

from app.core.security import get_password_hash
from app.models.announcement import Announcement
from app.models.event import Event
from app.models.sports import Tournament
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"se-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _h(org_id):
    return {"X-Organization-ID": str(org_id)}


def _find(client, org_id, q, **params):
    r = client.get("/api/v1/search", params={"q": q, **params},
                   headers=_h(org_id))
    assert r.status_code == 200, r.text
    return r.json()


def _event(db, org_id, title, description="", **kw):
    import datetime
    e = Event(id=uuid.uuid4(), organization_id=org_id, title_en=title,
              title_ta=title, description_en=description, description_ta="",
              event_start=datetime.datetime(2026, 5, 1, 9, 0),
              event_end=datetime.datetime(2026, 5, 1, 12, 0), **kw)
    db.add(e)
    db.commit()
    return e


def _member(db, org_id, name, phone):
    u = User(organization_id=org_id, phone_number=phone,
             password_hash=get_password_hash("pass"), role="VOLUNTEER",
             is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_ta=name, full_name_en=name))
    db.commit()
    return u


def test_the_query_that_returned_nothing(client, db):
    """"Events" now opens the events page.

    This is the whole reason for the rewrite. The word names a *place*, and the
    old search could only match the titles of things — so the app's own
    suggested query returned "No results found".
    """
    org = _org(db)
    hits = _find(client, org.id, "Events")

    assert hits, "the app suggests this exact query on its search screen"
    top = hits[0]
    assert top["type"] == "DESTINATION"
    assert top["route"] == "/events"


def test_a_place_outranks_things_that_merely_mention_it(client, db):
    """Somebody typing "blood" wants the blood page, not a passing mention."""
    org = _org(db)
    _event(db, org.id, "Cricket final", description="Blood donors welcome")

    hits = _find(client, org.id, "blood")
    assert hits[0]["route"] == "/blood-donation"
    assert hits[0]["type"] == "DESTINATION"


def test_places_answer_in_tamil_too(client, db):
    org = _org(db)
    hits = _find(client, org.id, "ரத்த", lang="ta")
    assert hits[0]["route"] == "/blood-donation"
    assert hits[0]["title"] == "ரத்த தானம்"


def test_a_misspelt_near_miss_still_lands(client, db):
    """"donor", "blood bank", "O+" — what people actually type."""
    org = _org(db)
    for query in ("donor", "blood bank", "O+"):
        hits = _find(client, org.id, query)
        assert any(h["route"] == "/blood-donation" for h in hits), query


def test_an_exact_title_beats_a_passing_mention(client, db):
    """Relevance used to be an accident of which query ran first.

    Every source used `ilike('%q%')`, which is equally true for a title and for
    one word inside a paragraph, and the results were concatenated in code
    order — so a tournament that mentioned the word outranked the event
    actually named it.
    """
    org = _org(db)
    _event(db, org.id, "Pongal Celebration")
    db.add(Tournament(id=uuid.uuid4(), organization_id=org.id,
                      name_en="Summer Cup", name_ta="கோடை கோப்பை",
                      sport="CRICKET", year=2026,
                      description_en="Held during Pongal Celebration week"))
    db.commit()

    hits = _find(client, org.id, "Pongal Celebration")
    named = [h for h in hits if h["title"] == "Pongal Celebration"]
    assert named, "the thing actually called this must be found"
    assert hits[0]["title"] == "Pongal Celebration", \
        "an exact title must outrank a description that mentions it"


def test_a_word_in_the_middle_of_a_title_is_found(client, db):
    """"meet" finds "Annual Sports Meet" — the tier substring matching flattened."""
    org = _org(db)
    _event(db, org.id, "Annual Sports Meet")
    hits = _find(client, org.id, "meet")
    assert any(h["title"] == "Annual Sports Meet" for h in hits)


def test_a_member_is_found_and_leads_to_their_own_page(client, db):
    """Finding a person and being dropped at the full roster is not an answer."""
    org = _org(db)
    arun = _member(db, org.id, "Arun Kumar", "9500000001")

    hits = _find(client, org.id, "kumar")
    people = [h for h in hits if h["type"] == "USER"]
    assert people, "a surname must find the member"
    assert people[0]["route"] == f"/members/{arun.id}"


def test_the_things_that_were_never_searchable_are_searchable(client, db):
    """Fourteen screens' worth of content was invisible to search.

    Adding a type meant writing another twenty-line block in the router, so
    after the first seven nobody did. It is one entry in `_SOURCES` now.
    """
    from app.models.work import Listing
    from app.models.opportunity import Opportunity
    org = _org(db)
    owner = _member(db, org.id, "Owner", "9500000009")
    db.add(Listing(id=uuid.uuid4(), organization_id=org.id,
                   owner_user_id=owner.id,
                   display_name="Murugan Electricals", kind="SERVICE",
                   category="Electrician", about="House wiring", area="Ariyanad",
                   phone="9500000002"))
    db.add(Opportunity(id=uuid.uuid4(), organization_id=org.id,
                       type="COURSE", title_en="Merit Scholarship",
                       title_ta="தகுதி உதவித்தொகை", organizer_en="District"))
    db.commit()

    assert any(h["type"] == "WORK" for h in _find(client, org.id, "Murugan"))
    assert any(h["type"] == "OPPORTUNITY"
               for h in _find(client, org.id, "Scholarship"))


def test_results_never_leak_across_clubs(client, db):
    org = _org(db)
    elsewhere = _org(db)
    _event(db, elsewhere.id, "Somebody Else's Festival")

    hits = _find(client, org.id, "Festival")
    assert not [h for h in hits if h["type"] == "EVENT"], \
        "another club's event is not ours to show"


def test_one_ranked_list_with_a_route_on_every_row(client, db):
    org = _org(db)
    _event(db, org.id, "Cricket Final")
    db.add(Announcement(id=uuid.uuid4(), organization_id=org.id,
                        title_en="Cricket Final moved", title_ta="மாற்றம்",
                        body_en="Rain", body_ta="மழை",
                        category="GENERAL"))
    db.commit()

    hits = _find(client, org.id, "Cricket")
    assert len(hits) >= 2
    assert all(h["route"] for h in hits), "every result must know where it goes"
    scores = [h["score"] for h in hits]
    assert scores == sorted(scores, reverse=True), "best first, always"


def test_a_single_character_is_not_a_search(client, db):
    org = _org(db)
    r = client.get("/api/v1/search", params={"q": "a"}, headers=_h(org.id))
    assert r.status_code == 422


def test_a_type_filter_narrows_without_breaking_ranking(client, db):
    org = _org(db)
    _event(db, org.id, "Blood Drive")
    hits = _find(client, org.id, "blood", types=["EVENT"])
    assert hits and all(h["type"] == "EVENT" for h in hits), \
        "asking for events must not return the blood-donation page"


def test_one_broken_table_does_not_blank_the_whole_search(client, db, monkeypatch):
    """The fault that shipped with the rewrite.

    Search fans out across a dozen tables in one request, and `db.query(Model)`
    is `SELECT *` — so one column that has drifted out of step with its model
    took down *every* result, including the ones that were fine. The search box
    answered "Failed to load results" for every query, because of one table
    nobody was even searching for.

    A search that returns most of the answers beats one that returns an error
    page. Each source is isolated; a broken one costs only its own results.
    """
    from app.services import search as search_service

    org = _org(db)
    _event(db, org.id, "Drawing Competition")

    real_sources = search_service._sources()

    def _with_a_broken_one():
        # Break a source the query does not even need — the point is that its
        # failure used to take the healthy ones down with it.
        return [
            s._replace(columns=lambda m: (_ for _ in ()).throw(
                RuntimeError("column gone"))) if s.type == "WORK" else s
            for s in real_sources
        ]

    monkeypatch.setattr(search_service, "_sources", _with_a_broken_one)

    hits = _find(client, org.id, "Drawing")
    assert any(h["title"] == "Drawing Competition" for h in hits), \
        "a broken table must not blank the page"


def test_places_answer_even_if_every_table_is_broken(client, db, monkeypatch):
    """Destinations are pure Python over a static list — no database at all.

    Whatever else is down, "Events" still opens the events page. That is the
    floor this search should never fall below.
    """
    from app.services import search as search_service

    org = _org(db)

    real_sources = search_service._sources()
    broken = [s._replace(columns=lambda m: (_ for _ in ()).throw(
        RuntimeError("gone"))) for s in real_sources]

    monkeypatch.setattr(search_service, "_sources", lambda: broken)
    monkeypatch.setattr(search_service, "_search_people",
                        lambda *a, **k: (_ for _ in ()).throw(RuntimeError()))

    hits = _find(client, org.id, "Events")
    assert hits and hits[0]["route"] == "/events"


def test_the_app_can_say_which_search_source_is_broken(client):
    """"Search is failing" has to become "this table is failing" without
    anybody reading a log or holding production access."""
    body = client.get("/api/health/search").json()
    assert "sources" in body and body["sources"], "every source must report"
    assert body["all_sources_healthy"] is True
    assert body["broken"] == []
    assert "EVENT" in body["sources"] and "USER" in body["sources"]
