"""
Tournament-level time control.

Every match in a tournament inherits the clock the organizer picked. Matches
used to be hardcoded to "untimed", which meant a stalling player could never
lose on time and a multi-round event could not be run to a schedule.
"""
import uuid

import pytest

from app.core.security import get_password_hash
from app.models.chess import ChessGame
from app.models.chess_tournament import (
    ChessTournament,
    ChessTournamentEntry,
    ChessTournamentMatch,
)
from app.models.tenant import Organization
from app.models.user import User, UserProfile


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}",
                       name_ta="x", name_en="x")
    db.add(org)
    db.commit()
    return org


def _user(db, org, phone, role="ADMIN"):
    u = User(organization_id=org.id, phone_number=phone,
             password_hash=get_password_hash("x"), role=role, is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=f"P{phone[-3:]}",
                       full_name_ta=f"P{phone[-3:]}"))
    db.commit()
    return u


def _auth(client, u, org):
    from app.core.security import create_access_token
    return {
        "Authorization": f"Bearer {create_access_token(str(u.id), u.role, str(org.id))}",
        "X-Organization-ID": str(org.id),
    }


# ── Creation ──────────────────────────────────────────────────────────────────

def test_default_time_control_is_ten_minutes_each(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    r = client.post("/api/v1/chess/tournaments", json={"name": "Club Cup"},
                    headers=_auth(client, admin, org))
    assert r.status_code == 201, r.text
    assert r.json()["time_control"] == "rapid_10_0"


def test_organizer_can_choose_the_clock_at_creation(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    r = client.post("/api/v1/chess/tournaments",
                    json={"name": "Blitz Night", "time_control": "blitz_5_0"},
                    headers=_auth(client, admin, org))
    assert r.status_code == 201, r.text
    assert r.json()["time_control"] == "blitz_5_0"


def test_unknown_time_control_is_rejected(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    r = client.post("/api/v1/chess/tournaments",
                    json={"name": "Bad", "time_control": "rapid_9000"},
                    headers=_auth(client, admin, org))
    assert r.status_code == 400


def test_time_control_options_are_listed_for_the_picker(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    r = client.get("/api/v1/chess/tournaments/meta/time-controls",
                   headers=_auth(client, admin, org))
    assert r.status_code == 200, r.text
    body = r.json()
    values = [o["value"] for o in body["options"]]
    assert body["default"] == "rapid_10_0"
    assert "rapid_10_0" in values and "untimed" in values


# ── Editing ───────────────────────────────────────────────────────────────────

def test_organizer_can_change_the_clock_before_the_tournament_starts(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    tid = client.post("/api/v1/chess/tournaments", json={"name": "Cup"},
                      headers=_auth(client, admin, org)).json()["id"]

    r = client.patch(f"/api/v1/chess/tournaments/{tid}/settings",
                     json={"time_control": "blitz_3_2"},
                     headers=_auth(client, admin, org))
    assert r.status_code == 200, r.text
    assert r.json()["time_control"] == "blitz_3_2"


def test_clock_cannot_change_once_the_tournament_is_live(client, db):
    """Changing it mid-event would give later rounds a different time control
    from earlier ones."""
    org = _org(db)
    admin = _user(db, org, "9100000001")
    tid = client.post("/api/v1/chess/tournaments", json={"name": "Cup"},
                      headers=_auth(client, admin, org)).json()["id"]

    tour = db.query(ChessTournament).filter(ChessTournament.id == uuid.UUID(tid)).first()
    tour.status = "IN_PROGRESS"
    db.commit()

    r = client.patch(f"/api/v1/chess/tournaments/{tid}/settings",
                     json={"time_control": "bullet_1_0"},
                     headers=_auth(client, admin, org))
    assert r.status_code == 400


def test_players_cannot_change_the_clock(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    player = _user(db, org, "9100000002", role="USER")
    tid = client.post("/api/v1/chess/tournaments", json={"name": "Cup"},
                      headers=_auth(client, admin, org)).json()["id"]

    r = client.patch(f"/api/v1/chess/tournaments/{tid}/settings",
                     json={"time_control": "bullet_1_0"},
                     headers=_auth(client, player, org))
    assert r.status_code in (401, 403)


# ── The point of all this: matches actually inherit the clock ─────────────────

def test_match_game_inherits_the_tournament_clock_with_banked_time(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    a = _user(db, org, "9100000002", role="USER")
    b = _user(db, org, "9100000003", role="USER")

    tid = client.post("/api/v1/chess/tournaments",
                      json={"name": "Cup", "time_control": "rapid_10_0"},
                      headers=_auth(client, admin, org)).json()["id"]
    tour_id = uuid.UUID(tid)
    for u in (a, b):
        db.add(ChessTournamentEntry(id=uuid.uuid4(), organization_id=org.id,
                                    tournament_id=tour_id, user_id=u.id,
                                    status="APPROVED"))
    m = ChessTournamentMatch(
        id=uuid.uuid4(), organization_id=org.id, tournament_id=tour_id,
        round=1, slot=0, player_a_id=a.id, player_b_id=b.id,
        status="READY", activated=True, a_ready=True, b_ready=True,
    )
    db.add(m)
    db.commit()

    r = client.post(f"/api/v1/chess/tournaments/{tid}/matches/{m.id}/play",
                    headers=_auth(client, a, org))
    assert r.status_code == 200, r.text

    db.expire_all()
    m = db.query(ChessTournamentMatch).filter(ChessTournamentMatch.id == m.id).first()
    game = db.query(ChessGame).filter(ChessGame.id == m.game_id).first()

    assert game.time_control == "rapid_10_0"
    # Starting balances are written at creation, so a restart during the
    # opening move still resumes the real clock.
    assert game.white_time_ms == 600_000
    assert game.black_time_ms == 600_000


def test_untimed_tournament_leaves_game_clock_null(client, db):
    org = _org(db)
    admin = _user(db, org, "9100000001")
    a = _user(db, org, "9100000002", role="USER")
    b = _user(db, org, "9100000003", role="USER")

    tid = client.post("/api/v1/chess/tournaments",
                      json={"name": "Casual", "time_control": "untimed"},
                      headers=_auth(client, admin, org)).json()["id"]
    m = ChessTournamentMatch(
        id=uuid.uuid4(), organization_id=org.id, tournament_id=uuid.UUID(tid),
        round=1, slot=0, player_a_id=a.id, player_b_id=b.id,
        status="READY", activated=True, a_ready=True, b_ready=True,
    )
    db.add(m)
    db.commit()

    r = client.post(f"/api/v1/chess/tournaments/{tid}/matches/{m.id}/play",
                    headers=_auth(client, a, org))
    assert r.status_code == 200, r.text

    db.expire_all()
    m = db.query(ChessTournamentMatch).filter(ChessTournamentMatch.id == m.id).first()
    game = db.query(ChessGame).filter(ChessGame.id == m.game_id).first()
    assert game.time_control == "untimed"
    assert game.white_time_ms is None


def test_legacy_tournament_without_the_column_stays_untimed(db):
    """Rows created before this setting existed were played with no clock; they
    must not silently acquire one mid-event."""
    from app.routers.chess_tournaments import _tc
    org = _org(db)
    tour = ChessTournament(id=uuid.uuid4(), organization_id=org.id, name="Old",
                           status="IN_PROGRESS")
    db.add(tour)
    db.commit()
    # Simulate what the startup schema-reconcile does: the column is ADDed to an
    # existing row, leaving it NULL (the model default only applies on INSERT).
    from sqlalchemy import text
    db.execute(text("UPDATE chess_tournaments SET time_control = NULL WHERE id = :i"),
               {"i": tour.id.hex})
    db.commit()
    db.refresh(tour)
    assert _tc(tour) == "untimed"
