"""
The chess reaper: games that stall must not freeze a knockout round forever.

Covers the three ways a game previously stayed `in_progress` for good — an
expired clock with nobody connected, a fully abandoned board, and a game created
but never started — plus the guarantee that the reaper never steals a game the
WebSocket handler is actively running.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.orm import sessionmaker

from app.core.security import get_password_hash
from app.models.chess import ChessGame, ChessMove
from app.models.tenant import Organization
from app.models.user import User, UserProfile
from app.services import chess_reaper
from app.services.chess_ws_manager import ws_manager


@pytest.fixture
def reaper_db(db, monkeypatch):
    """Point the reaper at the test database.

    The reaper opens its own short-lived SessionLocal (it runs on the scheduler,
    not inside a request), so it has to be rebound for tests. It is bound to the
    very connection the `db` fixture holds — that is where the test's rows live,
    inside an uncommitted outer transaction. `create_savepoint` makes the
    reaper's commits nest as savepoints so the fixture can still roll the whole
    thing back on teardown.
    """
    monkeypatch.setattr(
        chess_reaper, "SessionLocal",
        sessionmaker(bind=db.connection(), join_transaction_mode="create_savepoint"),
    )
    ws_manager._sessions.clear()
    yield db
    ws_manager._sessions.clear()


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}",
                       name_ta="x", name_en="x")
    db.add(org)
    db.commit()
    return org


def _player(db, org, name, phone):
    u = User(organization_id=org.id, phone_number=phone,
             password_hash=get_password_hash("x"), role="VOLUNTEER", is_verified=True)
    db.add(u)
    db.flush()
    db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
    db.commit()
    return u


def _game(db, org, w, b, **kw):
    kw.setdefault("status", "in_progress")
    g = ChessGame(id=uuid.uuid4(), organization_id=org.id, white_id=w.id,
                  black_id=b.id, mode="online", **kw)
    db.add(g)
    db.commit()
    return g


def test_expired_clock_is_decided_on_time(reaper_db):
    """White is to move with 5s banked but has been away for 10 minutes."""
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    g = _game(db, org, w, b,
              time_control="blitz_3_0",
              white_time_ms=5_000, black_time_ms=120_000,
              last_move_at=datetime.now(timezone.utc) - timedelta(minutes=10))

    summary = chess_reaper._reap_once()
    assert summary["timed_out"] == 1

    db.expire_all()
    g = db.query(ChessGame).filter(ChessGame.id == g.id).first()
    assert g.status == "ended"
    assert g.result == "black_wins"      # white was on move and flagged
    assert g.draw_reason == "time"


def test_side_to_move_is_derived_from_the_move_count(reaper_db):
    """After one move it is BLACK on the clock, so black is the one who flags."""
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    g = _game(db, org, w, b,
              time_control="blitz_3_0",
              white_time_ms=120_000, black_time_ms=5_000,
              last_move_at=datetime.now(timezone.utc) - timedelta(minutes=10))
    db.add(ChessMove(id=uuid.uuid4(), organization_id=org.id, game_id=g.id,
                     ply=1, uci="e2e4", san="e4"))
    db.commit()

    assert chess_reaper._reap_once()["timed_out"] == 1
    db.expire_all()
    assert db.query(ChessGame).filter(ChessGame.id == g.id).first().result == "white_wins"


def test_game_with_time_left_is_not_touched(reaper_db):
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    g = _game(db, org, w, b,
              time_control="rapid_10_0",
              white_time_ms=600_000, black_time_ms=600_000,
              last_move_at=datetime.now(timezone.utc) - timedelta(seconds=20))

    assert chess_reaper._reap_once()["timed_out"] == 0
    db.expire_all()
    assert db.query(ChessGame).filter(ChessGame.id == g.id).first().status == "in_progress"


def test_reaper_never_steals_a_game_with_a_connected_player(reaper_db):
    """The WS handler adjudicates instantly and owns any game it is running."""
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    g = _game(db, org, w, b,
              time_control="blitz_3_0",
              white_time_ms=0, black_time_ms=120_000,
              last_move_at=datetime.now(timezone.utc) - timedelta(minutes=10))

    session = ws_manager.create(str(g.id), str(w.id), str(b.id), "Alice", "Bob")
    session.connections[str(w.id)] = object()

    assert chess_reaper._reap_once()["timed_out"] == 0
    db.expire_all()
    assert db.query(ChessGame).filter(ChessGame.id == g.id).first().status == "in_progress"


def test_abandoned_game_is_closed_without_inventing_a_winner(reaper_db):
    """An untimed board nobody touched for hours is closed out, but the result
    is left for the organizer — the reaper must not guess a winner."""
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    g = _game(db, org, w, b, time_control="untimed",
              started_at=datetime.now(timezone.utc) - timedelta(hours=9))

    assert chess_reaper._reap_once()["abandoned"] == 1
    db.expire_all()
    g = db.query(ChessGame).filter(ChessGame.id == g.id).first()
    assert g.status == "ended"
    assert g.result == "abandoned"


def test_abandoned_game_is_not_rated(reaper_db):
    """_update_stats would score an abandonment as a double loss — it must not
    run for abandoned games."""
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    _game(db, org, w, b, time_control="untimed",
          started_at=datetime.now(timezone.utc) - timedelta(hours=9))

    chess_reaper._reap_once()

    from app.models.chess import ChessPlayerStats
    db.expire_all()
    stats = db.query(ChessPlayerStats).all()
    assert all(s.games_played == 0 for s in stats)


def test_recently_started_game_is_left_alone(reaper_db):
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    g = _game(db, org, w, b, time_control="untimed",
              started_at=datetime.now(timezone.utc) - timedelta(minutes=5))

    summary = chess_reaper._reap_once()
    assert summary["abandoned"] == 0
    db.expire_all()
    assert db.query(ChessGame).filter(ChessGame.id == g.id).first().status == "in_progress"


def test_already_ended_games_are_ignored(reaper_db):
    db = reaper_db
    org = _org(db)
    w = _player(db, org, "Alice", "9100000001")
    b = _player(db, org, "Bob", "9100000002")
    _game(db, org, w, b, status="ended", result="white_wins",
          time_control="blitz_3_0", white_time_ms=0, black_time_ms=0,
          last_move_at=datetime.now(timezone.utc) - timedelta(hours=9))

    summary = chess_reaper._reap_once()
    assert summary["timed_out"] == 0
    assert summary["abandoned"] == 0
