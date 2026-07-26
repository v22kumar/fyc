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
