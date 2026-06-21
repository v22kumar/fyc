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
from typing import Dict, Optional

import chess
from fastapi import WebSocket

logger = logging.getLogger(__name__)

DISCONNECT_GRACE_SECONDS = 60  # seconds before forfeit on disconnect


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
        self.connections: Dict[str, WebSocket] = {}  # user_id -> WebSocket
        self.san_list: list[str] = []
        self.fen_list: list[str] = ["rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]

        self.draw_offered_by: Optional[str] = None
        self._disconnect_tasks: Dict[str, asyncio.Task] = {}

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

    async def broadcast(self, msg: dict, exclude: Optional[str] = None) -> None:
        data = json.dumps(msg)
        for uid, ws in list(self.connections.items()):
            if exclude and uid == exclude:
                continue
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
        self.fen_list.append(self.board.fen())
        return move

    def game_over_result(self) -> Optional[dict]:
        """Return result dict if game is over, else None."""
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
        return {
            "type": "state",
            "color": color,
            "white_name": self.white_name,
            "black_name": self.black_name,
            "fen": self.board.fen(),
            "ply": len(self.san_list),
            "moves": [
                {"ply": i + 1, "san": s}
                for i, s in enumerate(self.san_list)
            ],
            "turn": "white" if self.board.turn else "black",
            "time_control": self.time_control,
        }

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
