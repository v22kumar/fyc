"""
Clock, flag and increment behaviour for live chess.

This is the logic that decides tournament games, and it previously had no tests
at all — which is how "a stalling player can never flag" survived. Every test
here asserts an outcome a player would feel at the board.
"""
from datetime import datetime, timedelta, timezone

import pytest

from app.services.chess_ws_manager import GameSession, GameWSManager

WHITE = "11111111-1111-1111-1111-111111111111"
BLACK = "22222222-2222-2222-2222-222222222222"


def _session(time_control="blitz_3_0", **kw) -> GameSession:
    return GameSession(
        game_id="g1", white_id=WHITE, black_id=BLACK,
        white_name="W", black_name="B", time_control=time_control, **kw,
    )


def _rewind(session: GameSession, seconds: float) -> None:
    """Pretend the side to move has been thinking for `seconds`."""
    session._last_move_at = datetime.now(timezone.utc) - timedelta(seconds=seconds)


# ── Untimed games ─────────────────────────────────────────────────────────────

def test_untimed_game_has_no_clock_and_never_flags():
    s = _session("untimed")
    assert s.is_timed is False
    assert s.clock_snapshot() is None
    s.start_clock()
    _rewind(s, 10_000)
    assert s.flagged_color() is None


# ── The headline bug: a stalling player must run out of time ──────────────────

def test_stalling_player_flags_without_ever_moving():
    """The old clock only decremented when a player MOVED, so someone who simply
    never moved could never flag and the board hung forever."""
    s = _session("blitz_3_0")  # 3 minutes
    s.start_clock()

    _rewind(s, 100)
    assert s.flagged_color() is None          # still has ~80s
    assert s.remaining_ms("white") == pytest.approx(80_000, abs=1_500)

    _rewind(s, 200)                            # beyond the 180s budget
    assert s.flagged_color() == "white"
    assert s.remaining_ms("white") == 0


def test_only_the_side_to_move_can_flag():
    """You cannot lose on time while your opponent's clock is running."""
    s = _session("blitz_3_0")
    s.start_clock()
    _rewind(s, 500)
    # White is to move, so white flags — black is untouched despite the same wall time.
    assert s.flagged_color() == "white"
    assert s.remaining_ms("black") == 180_000
    assert s.is_flagged("black") is False


def test_opponents_clock_does_not_drain_while_you_think():
    s = _session("rapid_10_0")
    s.start_clock()
    _rewind(s, 120)
    assert s.remaining_ms("white") == pytest.approx(480_000, abs=1_500)
    assert s.remaining_ms("black") == 600_000


# ── Deduction + increment ─────────────────────────────────────────────────────

def test_moving_banks_the_elapsed_time():
    s = _session("blitz_3_0")
    s.start_clock()
    _rewind(s, 30)
    s.apply_move("e2e4")
    s.deduct_time(WHITE)
    assert s.white_time_ms == pytest.approx(150_000, abs=1_500)
    # Black's clock is now the one running, and starts intact.
    assert s.remaining_ms("black") == pytest.approx(180_000, abs=1_500)


def test_fischer_increment_is_added_per_move_not_once_at_the_start():
    """'blitz_3_2' used to just be 3:02 for the whole game — the increment was
    folded into the base time instead of granted per move."""
    s = _session("blitz_3_2")
    assert s.white_time_ms == 180_000       # base is exactly 3:00, not 3:02
    assert s.increment_ms == 2_000
    s.start_clock()

    for _ in range(3):
        _rewind(s, 1)                        # spend ~1s, gain 2s
        s.deduct_time(WHITE)
    # Three moves at ~1s each with +2s increment ⇒ roughly +3s overall.
    assert s.white_time_ms == pytest.approx(183_000, abs=1_500)


def test_increment_is_not_granted_on_a_dead_clock():
    """Moving after your time is gone must not resurrect you via the increment."""
    s = _session("blitz_3_2")
    s.start_clock()
    _rewind(s, 400)
    s.deduct_time(WHITE)
    assert s.white_time_ms == 0


def test_deduction_is_independent_of_whose_turn_it_is():
    """deduct_time() runs AFTER the move is applied (so illegal attempts can't
    farm increments), by which point the turn has already flipped."""
    s = _session("blitz_3_0")
    s.start_clock()
    _rewind(s, 20)
    s.apply_move("e2e4")            # turn is now black's
    assert s.turn_color == "black"
    s.deduct_time(WHITE)            # still charges white correctly
    assert s.white_time_ms == pytest.approx(160_000, abs=1_500)


# ── Durability across a restart ───────────────────────────────────────────────

def test_clock_resumes_from_persisted_state_after_restart():
    """A redeploy used to hand both players a fresh full clock mid-game."""
    s = GameSession(
        game_id="g1", white_id=WHITE, black_id=BLACK,
        white_name="W", black_name="B", time_control="blitz_3_0",
        initial_uci=["e2e4", "e7e5"],
        initial_clock={
            "white_time_ms": 42_000,
            "black_time_ms": 61_000,
            "last_move_at": datetime.now(timezone.utc) - timedelta(seconds=5),
        },
    )
    assert s.white_time_ms == 42_000
    assert s.black_time_ms == 61_000
    assert len(s.san_list) == 2


def test_restart_does_not_charge_players_for_server_downtime():
    """The banked balances survive, but the elapsed window restarts at 'now' so
    an outage doesn't silently eat the mover's clock."""
    s = GameSession(
        game_id="g1", white_id=WHITE, black_id=BLACK,
        white_name="W", black_name="B", time_control="blitz_3_0",
        initial_clock={
            "white_time_ms": 42_000,
            "black_time_ms": 61_000,
            # Server was down for an hour.
            "last_move_at": datetime.now(timezone.utc) - timedelta(hours=1),
        },
    )
    assert s.flagged_color() is None
    assert s.remaining_ms("white") == pytest.approx(42_000, abs=1_500)


def test_clock_for_db_round_trips():
    s = _session("blitz_3_0")
    s.start_clock()
    _rewind(s, 10)
    s.deduct_time(WHITE)
    state = s.clock_for_db()
    revived = _session("blitz_3_0", initial_clock=state)
    assert revived.white_time_ms == s.white_time_ms
    assert revived.black_time_ms == s.black_time_ms


# ── Paused games ──────────────────────────────────────────────────────────────

def test_paused_game_does_not_flag():
    """A game frozen because a move failed to persist must not then be lost on
    time by the player who was waiting for the organizer."""
    s = _session("blitz_3_0")
    s.start_clock()
    s.paused = True
    _rewind(s, 500)
    assert s.flagged_color() is None


# ── Session eviction (memory leak) ────────────────────────────────────────────

def test_sweep_evicts_idle_unattached_sessions():
    m = GameWSManager()
    m.create("abandoned", WHITE, BLACK, "W", "B")
    m.create("busy", WHITE, BLACK, "W", "B")
    m.get("busy").connections[WHITE] = object()   # someone is still attached

    m.get("abandoned").last_activity -= 7200
    m.get("busy").last_activity -= 7200

    assert m.sweep(max_idle_seconds=3600) == 1
    assert m.get("abandoned") is None
    assert m.get("busy") is not None


def test_sweep_keeps_recently_active_sessions():
    m = GameWSManager()
    m.create("fresh", WHITE, BLACK, "W", "B")
    assert m.sweep(max_idle_seconds=3600) == 0
    assert m.get("fresh") is not None
