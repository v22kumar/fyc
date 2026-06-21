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
from typing import Dict, Optional

import chess
from fastapi import WebSocket

logger = logging.getLogger(__name__)

DISCONNECT_GRACE_SECONDS = 60


def _initial_time_ms(time_control: str) -> Optional[int]:
    """Return starting milliseconds for each player, or None if untimed."""
    return {
        "blitz_5_0": 5 * 60 * 1000,
        "blitz_3_0": 3 * 60 * 1000,
        "rapid_10_0": 10 * 60 * 1000,
        "bullet_1_0": 1 * 60 * 1000,
    }.get(time_control)


class GameSession:
    def __init__(
        self,
        game_id: str,
        white_id: str,
        black_id: str,
        white_name: str,
        black_name: str,
        time_control: str = "untimed",
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

        self.draw_offered_by: Optional[str] = None
        self._disconnect_tasks: Dict[str, asyncio.Task] = {}

        # Clock state (None = untimed)
        _ms = _initial_time_ms(time_control)
        self.white_time_ms: Optional[int] = _ms
        self.black_time_ms: Optional[int] = _ms
        self._last_move_at: Optional[float] = None  # monotonic timestamp

    # ── Spectator helpers ─────────────────────────────────────────────────────

    @property
    def spectator_count(self) -> int:
        return len(self.spectators)

    async def add_spectator(self, user_id: str, ws: WebSocket) -> None:
        self.spectators[str(user_id)] = ws

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

    def clock_snapshot(self) -> Optional[dict]:
        """Current clock times as sent to clients. None if untimed."""
        if self.white_time_ms is None:
            return None
        return {"white": self.white_time_ms, "black": self.black_time_ms}

    def deduct_time(self, user_id: str) -> None:
        """Deduct elapsed time from the player who just moved. Call before updating last_move_at."""
        if self.white_time_ms is None or self._last_move_at is None:
            # First move or untimed — just record the timestamp
            self._last_move_at = time.monotonic()
            return

        elapsed_ms = int((time.monotonic() - self._last_move_at) * 1000)
        color = self.get_color(user_id)
        if color == "white":
            self.white_time_ms = max(0, self.white_time_ms - elapsed_ms)
        elif color == "black" and self.black_time_ms is not None:
            self.black_time_ms = max(0, self.black_time_ms - elapsed_ms)

        self._last_move_at = time.monotonic()

    def is_flagged(self, color: str) -> bool:
        """True if the given color has run out of time."""
        if self.white_time_ms is None:
            return False
        if color == "white":
            return self.white_time_ms == 0
        return self.black_time_ms == 0

    def start_clock(self) -> None:
        """Call when both players are connected and game starts."""
        if self.white_time_ms is not None:
            self._last_move_at = time.monotonic()

    # ── Move handling ─────────────────────────────────────────────────────────

    def apply_move(self, uci: str) -> Optional[chess.Move]:
        """Validate + apply UCI move. Returns the chess.Move or None if illegal."""
        try:
            move = chess.Move.from_uci(uci)
        except ValueError:
            return None
        if move not in self.board.legal_moves:
            return None
        san = self.board.san(move)
        self.board.push(move)
        self.san_list.append(san)
        self.uci_list.append(uci)
        self.fen_list.append(self.board.fen())
        return move

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
    ) -> GameSession:
        session = GameSession(
            game_id, white_id, black_id, white_name, black_name, time_control
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
    ) -> GameSession:
        existing = self.get(game_id)
        if existing:
            return existing
        return self.create(game_id, white_id, black_id, white_name, black_name, time_control)

    def remove(self, game_id: str) -> None:
        self._sessions.pop(str(game_id), None)


# Module-level singleton — shared across all requests in this process
ws_manager = GameWSManager()
