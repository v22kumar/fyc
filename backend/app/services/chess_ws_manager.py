"""
In-memory WebSocket manager for live chess games.

One GameSession per active online game: holds both WebSocket connections
and the authoritative chess.Board.  Server validates every move before
broadcasting — clients cannot send illegal moves.

Scale note: single-process only (Fly.io single instance). For multi-instance
deploy, replace connections dict with Redis pub/sub and store board state
in Redis or recompute from DB moves on reconnect.
"""
import asyncio
import json
import logging
import time
from datetime import datetime, timezone
from typing import Dict, Optional

import chess
from fastapi import WebSocket

logger = logging.getLogger(__name__)

DISCONNECT_GRACE_SECONDS = 60


# (base_milliseconds, increment_milliseconds_per_move)
# The increment is a real Fischer increment, added to the mover's clock after
# each of their moves. It used to be folded into the base time as a one-off
# +2s, which meant "3+2" was really just 3:02 for the whole game.
TIME_CONTROLS: Dict[str, tuple] = {
    "bullet_1_0":     (1 * 60 * 1000, 0),
    "blitz_3_0":      (3 * 60 * 1000, 0),
    "blitz_3_2":      (3 * 60 * 1000, 2000),
    "blitz_5_0":      (5 * 60 * 1000, 0),
    "rapid_10_0":    (10 * 60 * 1000, 0),
    "classical_30_0": (30 * 60 * 1000, 0),
}


def _initial_time_ms(time_control: str) -> Optional[int]:
    """Starting milliseconds for each player, or None if untimed."""
    tc = TIME_CONTROLS.get(time_control)
    return tc[0] if tc else None


def _increment_ms(time_control: str) -> int:
    """Per-move Fischer increment in milliseconds (0 when none)."""
    tc = TIME_CONTROLS.get(time_control)
    return tc[1] if tc else 0


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class GameSession:
    def __init__(
        self,
        game_id: str,
        white_id: str,
        black_id: str,
        white_name: str,
        black_name: str,
        time_control: str = "untimed",
        initial_uci: Optional[list] = None,
        initial_clock: Optional[dict] = None,
    ):
        self.game_id = game_id
        self.white_id = str(white_id)
        self.black_id = str(black_id)
        self.white_name = white_name
        self.black_name = black_name
        self.time_control = time_control

        self.board = chess.Board()
        self.connections: Dict[str, WebSocket] = {}
        self.spectators: Dict[str, WebSocket] = {}
        self.san_list: list[str] = []
        self.uci_list: list[str] = []
        self.fen_list: list[str] = ["rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]

        # Rebuild the position from the persisted moves when a session is
        # (re)created — e.g. after a redeploy or a spectator attaching to a game
        # whose in-memory session was lost. Without this, reconnecting silently
        # reset the board to move 1 and duplicated ply numbers in the DB.
        if initial_uci:
            for _uci in initial_uci:
                self.apply_move(_uci)

        self.draw_offered_by: Optional[str] = None
        self._disconnect_tasks: Dict[str, asyncio.Task] = {}

        # Set when a move could not be durably persisted: the game is frozen and
        # rejects further moves until an organizer intervenes, so the in-memory
        # board can never drift ahead of the database.
        self.paused: bool = False

        # ── Clock state (None = untimed) ──────────────────────────────────────
        # `white_time_ms`/`black_time_ms` are the BANKED times — what each side
        # had left the last time the clock changed hands. The side to move is
        # additionally charged for the time elapsed since `_last_move_at`, so
        # the true remaining time is always computed live via remaining_ms().
        # That is what makes a stalling player actually run out of time: the
        # old code only ever decremented on a move, so a player who simply
        # never moved could never flag and the board hung forever.
        _ms = _initial_time_ms(time_control)
        self.white_time_ms: Optional[int] = _ms
        self.black_time_ms: Optional[int] = _ms
        self.increment_ms: int = _increment_ms(time_control)
        # Wall-clock (not monotonic) so it can be persisted and resumed across
        # process restarts.
        self._last_move_at: Optional[datetime] = None
        self._clock_started: bool = False

        # Resume a persisted clock (redeploy / restarted process). We restore the
        # banked balances but deliberately restart the elapsed-time window at
        # "now" — a player must not be charged for server downtime.
        if initial_clock and _ms is not None:
            w = initial_clock.get("white_time_ms")
            b = initial_clock.get("black_time_ms")
            if w is not None and b is not None:
                self.white_time_ms = int(w)
                self.black_time_ms = int(b)
                if initial_clock.get("last_move_at") is not None:
                    self._clock_started = True
                    self._last_move_at = _utcnow()

        # Last time anything happened on this session — used to evict abandoned
        # sessions instead of leaking a board + task per unfinished game.
        self.last_activity: float = time.monotonic()

    # ── Spectator helpers ─────────────────────────────────────────────────────

    @property
    def spectator_count(self) -> int:
        return len(self.spectators)

    async def add_spectator(self, user_id: str, ws: WebSocket) -> None:
        self.spectators[str(user_id)] = ws
        self.last_activity = time.monotonic()

    async def remove_spectator(self, user_id: str) -> None:
        self.spectators.pop(str(user_id), None)

    def spectator_snapshot(self) -> dict:
        """Full state snapshot for a new spectator."""
        snap: dict = {
            "type": "state",
            "role": "spectator",
            "white_name": self.white_name,
            "black_name": self.black_name,
            "fen": self.board.fen(),
            "ply": len(self.san_list),
            "moves": [
                {"ply": i + 1, "san": s, "uci": self.uci_list[i]}
                for i, s in enumerate(self.san_list)
            ],
            "turn": "white" if self.board.turn else "black",
            "time_control": self.time_control,
        }
        clock = self.clock_snapshot()
        if clock:
            snap["clock"] = clock
        return snap

    # ── Identity ──────────────────────────────────────────────────────────────

    def get_color(self, user_id: str) -> Optional[str]:
        uid = str(user_id)
        if uid == self.white_id:
            return "white"
        if uid == self.black_id:
            return "black"
        return None

    def is_user_turn(self, user_id: str) -> bool:
        color = self.get_color(user_id)
        if color is None:
            return False
        return (color == "white") == self.board.turn

    def opponent_id(self, user_id: str) -> Optional[str]:
        uid = str(user_id)
        if uid == self.white_id:
            return self.black_id
        if uid == self.black_id:
            return self.white_id
        return None

    def both_connected(self) -> bool:
        return self.white_id in self.connections and self.black_id in self.connections

    # ── Messaging ─────────────────────────────────────────────────────────────

    async def broadcast(self, msg: dict, exclude: Optional[str] = None, players_only: bool = False) -> None:
        data = json.dumps(msg)
        for uid, ws in list(self.connections.items()):
            if exclude and uid == exclude:
                continue
            try:
                await ws.send_text(data)
            except Exception:
                pass
        if not players_only:
            for uid, ws in list(self.spectators.items()):
                try:
                    await ws.send_text(data)
                except Exception:
                    pass

    async def send_to(self, user_id: str, msg: dict) -> None:
        ws = self.connections.get(str(user_id))
        if ws:
            try:
                await ws.send_text(json.dumps(msg))
            except Exception:
                pass

    # ── Clock ─────────────────────────────────────────────────────────────────

    @property
    def is_timed(self) -> bool:
        return self.white_time_ms is not None

    @property
    def turn_color(self) -> str:
        return "white" if self.board.turn else "black"

    def _elapsed_ms(self) -> int:
        """Milliseconds the side to move has been thinking (0 if not running)."""
        if not self._clock_started or self._last_move_at is None or self.paused:
            return 0
        return max(0, int((_utcnow() - self._last_move_at).total_seconds() * 1000))

    def remaining_ms(self, color: str) -> Optional[int]:
        """TRUE remaining time for `color` right now — banked time minus the
        time already spent on the current move. This is the authoritative value
        for both display and flag adjudication."""
        if not self.is_timed:
            return None
        banked = self.white_time_ms if color == "white" else self.black_time_ms
        if banked is None:
            return None
        if color == self.turn_color:
            return max(0, banked - self._elapsed_ms())
        return max(0, banked)

    def clock_snapshot(self) -> Optional[dict]:
        """Live clock times as sent to clients. None if untimed."""
        if not self.is_timed:
            return None
        return {"white": self.remaining_ms("white"), "black": self.remaining_ms("black")}

    def deduct_time(self, user_id: str) -> None:
        """Commit the mover's thinking time and grant their increment. Called
        when a move is accepted, before the turn passes to the opponent."""
        if not self.is_timed:
            return
        color = self.get_color(user_id)
        if color is None:
            return

        if not self._clock_started or self._last_move_at is None:
            # Clock had not started ticking yet — just open the window.
            self._clock_started = True
            self._last_move_at = _utcnow()
            return

        # Computed from the elapsed window rather than remaining_ms() so this is
        # independent of whose turn it now is — the caller invokes it AFTER the
        # move is validated and applied (which flips the turn), so that an
        # illegal-move attempt can never earn an increment.
        banked = self.white_time_ms if color == "white" else self.black_time_ms
        remaining = max(0, (banked or 0) - self._elapsed_ms())
        # Increment is only earned if the move was made in time. A player who
        # moves on a dead clock does not get bailed out by the increment.
        if remaining > 0:
            remaining += self.increment_ms
        if color == "white":
            self.white_time_ms = remaining
        else:
            self.black_time_ms = remaining
        self._last_move_at = _utcnow()

    def flagged_color(self) -> Optional[str]:
        """The colour that has actually run out of time, or None.

        Only the side to move can flag — you cannot lose on time while it is
        your opponent's clock that is running.
        """
        if not self.is_timed or not self._clock_started or self.paused:
            return None
        turn = self.turn_color
        if (self.remaining_ms(turn) or 0) <= 0:
            return turn
        return None

    def is_flagged(self, color: str) -> bool:
        """True if `color` has genuinely run out of time."""
        return self.flagged_color() == color

    def start_clock(self) -> None:
        """Call when both players are connected and the game starts."""
        if self.is_timed and not self._clock_started:
            self._clock_started = True
            self._last_move_at = _utcnow()

    def clock_for_db(self) -> dict:
        """Persistable clock state — banked balances plus the current window."""
        return {
            "white_time_ms": self.white_time_ms,
            "black_time_ms": self.black_time_ms,
            "last_move_at": self._last_move_at,
        }

    # ── Move handling ─────────────────────────────────────────────────────────

    def apply_move(self, uci: str) -> Optional[chess.Move]:
        """Validate + apply UCI move. Returns the chess.Move or None if illegal."""
        try:
            move = chess.Move.from_uci(uci)
        except ValueError:
            return None
        if move not in self.board.legal_moves:
            return None
        self.last_activity = time.monotonic()
        san = self.board.san(move)
        self.board.push(move)
        self.san_list.append(san)
        self.uci_list.append(uci)
        self.fen_list.append(self.board.fen())
        return move

    def rollback_last(self) -> None:
        """Undo the most recently applied move — used when its DB persistence
        fails, so the live board stays in lockstep with what's durably stored."""
        if not self.uci_list:
            return
        try:
            self.board.pop()
        except Exception:
            return
        self.san_list.pop()
        self.uci_list.pop()
        if len(self.fen_list) > 1:
            self.fen_list.pop()

    def game_over_result(self) -> Optional[dict]:
        if self.board.is_checkmate():
            winner = "black" if self.board.turn else "white"
            return {"result": f"{winner}_wins", "reason": "checkmate"}
        if self.board.is_stalemate():
            return {"result": "draw", "reason": "stalemate"}
        if self.board.is_insufficient_material():
            return {"result": "draw", "reason": "insufficient_material"}
        if self.board.is_seventyfive_moves():
            return {"result": "draw", "reason": "seventy_five_moves"}
        if self.board.is_fivefold_repetition():
            return {"result": "draw", "reason": "repetition"}
        return None

    def state_snapshot(self, for_user_id: str) -> dict:
        """Full state for reconnect sync."""
        color = self.get_color(for_user_id)
        snap: dict = {
            "type": "state",
            "color": color,
            "white_name": self.white_name,
            "black_name": self.black_name,
            "fen": self.board.fen(),
            "ply": len(self.san_list),
            "moves": [
                {"ply": i + 1, "san": s, "uci": self.uci_list[i]}
                for i, s in enumerate(self.san_list)
            ],
            "turn": "white" if self.board.turn else "black",
            "time_control": self.time_control,
        }
        clock = self.clock_snapshot()
        if clock:
            snap["clock"] = clock
        return snap

    # ── Disconnect grace timer ─────────────────────────────────────────────────

    def cancel_disconnect_timer(self, user_id: str) -> None:
        task = self._disconnect_tasks.pop(str(user_id), None)
        if task:
            task.cancel()

    def start_disconnect_timer(self, user_id: str, on_forfeit) -> None:
        uid = str(user_id)
        self.cancel_disconnect_timer(uid)

        async def _timer():
            await asyncio.sleep(DISCONNECT_GRACE_SECONDS)
            await on_forfeit(uid)

        self._disconnect_tasks[uid] = asyncio.create_task(_timer())


class GameWSManager:
    def __init__(self):
        self._sessions: Dict[str, GameSession] = {}

    def create(
        self,
        game_id: str,
        white_id: str,
        black_id: str,
        white_name: str,
        black_name: str,
        time_control: str = "untimed",
        initial_uci: Optional[list] = None,
        initial_clock: Optional[dict] = None,
    ) -> GameSession:
        session = GameSession(
            game_id, white_id, black_id, white_name, black_name, time_control,
            initial_uci=initial_uci, initial_clock=initial_clock,
        )
        self._sessions[str(game_id)] = session
        return session

    def get(self, game_id: str) -> Optional[GameSession]:
        return self._sessions.get(str(game_id))

    def get_or_create(
        self,
        game_id: str,
        white_id: str,
        black_id: str,
        white_name: str,
        black_name: str,
        time_control: str = "untimed",
        initial_uci: Optional[list] = None,
        initial_clock: Optional[dict] = None,
    ) -> GameSession:
        existing = self.get(game_id)
        if existing:
            existing.last_activity = time.monotonic()
            return existing
        return self.create(game_id, white_id, black_id, white_name, black_name,
                           time_control, initial_uci=initial_uci,
                           initial_clock=initial_clock)

    def remove(self, game_id: str) -> None:
        self._sessions.pop(str(game_id), None)

    @property
    def active_count(self) -> int:
        return len(self._sessions)

    def sweep(self, max_idle_seconds: int = 3600) -> int:
        """Drop sessions with nobody attached that have been idle too long.

        Sessions were previously only removed on a clean game-over, so every
        abandoned game leaked a board (and its disconnect task) for the life of
        the process. Returns the number of sessions evicted.
        """
        now = time.monotonic()
        stale = [
            gid for gid, s in self._sessions.items()
            if not s.connections and not s.spectators
            and (now - s.last_activity) > max_idle_seconds
        ]
        for gid in stale:
            session = self._sessions.pop(gid, None)
            if session:
                for task in session._disconnect_tasks.values():
                    task.cancel()
        if stale:
            logger.info(f"[chess-sweep] evicted {len(stale)} idle session(s)")
        return len(stale)


# Module-level singleton — shared across all requests in this process
ws_manager = GameWSManager()
