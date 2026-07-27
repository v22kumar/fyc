"""A (re)created game session rebuilds its board from the persisted moves, so a
server restart/redeploy mid-game doesn't reset live games to move 1 or duplicate
ply numbers."""
from app.services.chess_ws_manager import GameSession, GameWSManager


def test_session_replays_initial_moves():
    s = GameSession("g", "w", "b", "White", "Black", "untimed",
                    initial_uci=["e2e4", "e7e5", "g1f3", "b8c6"])
    assert s.san_list == ["e4", "e5", "Nf3", "Nc6"]
    assert len(s.uci_list) == 4
    assert s.board.turn is True  # white to move after 4 half-moves
    # Next persisted ply must continue from the replayed count, not restart at 1.
    assert len(s.san_list) == 4


def test_get_or_create_seeds_only_on_create():
    mgr = GameWSManager()
    a = mgr.get_or_create("g1", "w", "b", "W", "B", "untimed", initial_uci=["e2e4"])
    assert len(a.san_list) == 1
    # Second call returns the SAME live session — it must NOT replay again.
    b = mgr.get_or_create("g1", "w", "b", "W", "B", "untimed", initial_uci=["e2e4", "e7e5"])
    assert b is a
    assert len(b.san_list) == 1


def test_illegal_stored_move_is_skipped_not_crashed():
    # A corrupt/illegal stored uci must not blow up session creation.
    s = GameSession("g", "w", "b", "W", "B", "untimed",
                    initial_uci=["e2e4", "zzzz", "e7e5"])
    assert "e4" in s.san_list and "e5" in s.san_list


def test_rollback_last_keeps_board_consistent():
    """When a move's persistence fails, rollback_last must undo it in memory so the
    board matches the database (no divergence)."""
    s = GameSession("g", "w", "b", "W", "B", "untimed", initial_uci=["e2e4", "e7e5"])
    assert len(s.san_list) == 2
    fen_before = s.board.fen()
    s.apply_move("g1f3")
    assert len(s.san_list) == 3
    s.rollback_last()
    assert s.san_list == ["e4", "e5"]
    assert s.uci_list == ["e2e4", "e7e5"]
    assert s.board.fen() == fen_before   # position fully restored
    assert s.board.turn is True          # white to move again
    # rollback_last on the start position is a safe no-op.
    empty = GameSession("g2", "w", "b", "W", "B", "untimed")
    empty.rollback_last()
    assert empty.san_list == []


def test_paused_flag_default_false():
    s = GameSession("g", "w", "b", "W", "B", "untimed")
    assert s.paused is False


def test_duplicate_ply_rejected(db):
    """The (game_id, ply) unique constraint turns a double-persist into a conflict
    instead of a silent duplicate row."""
    import uuid
    import pytest
    from sqlalchemy.exc import IntegrityError
    from app.models.tenant import Organization
    from app.models.chess import ChessGame, ChessMove

    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}", name_ta="x", name_en="x")
    db.add(org)
    db.commit()
    g = ChessGame(id=uuid.uuid4(), organization_id=org.id, mode="online", status="in_progress")
    db.add(g)
    db.commit()
    db.add(ChessMove(id=uuid.uuid4(), organization_id=org.id, game_id=g.id, ply=1, uci="e2e4", san="e4"))
    db.commit()
    db.add(ChessMove(id=uuid.uuid4(), organization_id=org.id, game_id=g.id, ply=1, uci="d2d4", san="d4"))
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_public_live_games_batched(client, db):
    """The live-games list resolves names + move counts in batch (no per-game
    N+1) and returns correct values."""
    import uuid
    from app.models.tenant import Organization
    from app.models.user import User, UserProfile
    from app.models.chess import ChessGame, ChessMove
    from app.core.security import get_password_hash

    org = Organization(id=uuid.uuid4(), slug=f"o-{uuid.uuid4().hex[:6]}", name_ta="x", name_en="x")
    db.add(org)
    db.commit()

    def _mk(name, phone):
        u = User(organization_id=org.id, phone_number=phone,
                 password_hash=get_password_hash("x"), role="VOLUNTEER", is_verified=True)
        db.add(u)
        db.flush()
        db.add(UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name))
        return u

    w = _mk("Alice", "9100000001")
    b = _mk("Bob", "9100000002")
    db.commit()
    g = ChessGame(id=uuid.uuid4(), organization_id=org.id, white_id=w.id, black_id=b.id,
                  mode="online", status="in_progress")
    db.add(g)
    db.commit()
    db.add(ChessMove(id=uuid.uuid4(), organization_id=org.id, game_id=g.id, ply=1, uci="e2e4", san="e4"))
    db.add(ChessMove(id=uuid.uuid4(), organization_id=org.id, game_id=g.id, ply=2, uci="e7e5", san="e5"))
    db.commit()

    r = client.get("/api/v1/chess/public/games/live", headers={"X-Organization-ID": str(org.id)})
    assert r.status_code == 200, r.text
    data = r.json()
    assert len(data) == 1
    assert data[0]["white_name"] == "Alice"
    assert data[0]["black_name"] == "Bob"
    assert data[0]["ply"] == 2
