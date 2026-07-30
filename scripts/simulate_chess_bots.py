import sys
import os
import asyncio
import json
import uuid
import random
import time
from datetime import datetime, timezone
import websockets
import chess
import httpx

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../backend')))

from app.core.database import SessionLocal
from app.models.user import User
from app.models.chess_tournament import ChessTournament, ChessTournamentMatch
from app.routers.chess_tournaments import _auto_resolve
from app.core.security import create_access_token
from app.core.config import settings

API_BASE_URL = "http://localhost:8000/api/v1"
WS_BASE_URL = "ws://localhost:8000/api/v1"

async def play_game(bot_id: uuid.UUID, token: str, game_id: str):
    uri = f"{WS_BASE_URL}/chess/games/{game_id}/ws?token={token}"
    print(f"[Bot {bot_id}] Connecting to {uri}")
    
    try:
        async with websockets.connect(uri) as ws:
            color = None
            board = chess.Board()
            
            while True:
                try:
                    message_str = await asyncio.wait_for(ws.recv(), timeout=30.0)
                    msg = json.loads(message_str)
                    msg_type = msg.get("type")
                    
                    if msg_type == "waiting":
                        color = msg.get("color")
                        print(f"[Bot {bot_id}] Waiting... Assigned color: {color}")
                        
                    elif msg_type == "game_start":
                        color = msg.get("color", color) 
                        board.set_fen(msg.get("fen", chess.STARTING_FEN))
                        turn = msg.get("turn")
                        print(f"[Bot {bot_id}] Game started. I am {color}. Turn is {turn}.")
                        
                        if turn == color:
                            await asyncio.sleep(random.uniform(1.0, 3.0))
                            legal_moves = list(board.legal_moves)
                            if legal_moves:
                                move = random.choice(legal_moves)
                                await ws.send(json.dumps({"type": "move", "uci": move.uci()}))
                                
                    elif msg_type == "move":
                        board.set_fen(msg.get("fen"))
                        turn = msg.get("turn")
                        
                        if msg.get("turn") == color:
                            await asyncio.sleep(random.uniform(1.0, 3.0))
                            legal_moves = list(board.legal_moves)
                            if legal_moves:
                                move = random.choice(legal_moves)
                                await ws.send(json.dumps({"type": "move", "uci": move.uci()}))
                                
                    elif msg_type == "game_over":
                        print(f"[Bot {bot_id}] Game over: {msg.get('result')}")
                        break
                        
                    elif msg_type == "error":
                        print(f"[Bot {bot_id}] WS Error: {msg.get('message')}")
                        
                except asyncio.TimeoutError:
                    # Send a ping or just wait
                    await ws.send(json.dumps({"type": "ping"}))
                    
    except Exception as e:
        print(f"[Bot {bot_id}] WebSocket closed or failed: {e}")

async def bot_manager():
    active_tasks = {}
    
    while True:
        try:
            db = SessionLocal()
            try:
                # Find the MEGA100 tournament
                tour = db.query(ChessTournament).filter(ChessTournament.short_code == "MEGA100").first()
                if not tour or tour.status == "COMPLETED":
                    print("Tournament MEGA100 not found or is COMPLETED. Exiting...")
                    break
                    
                # Auto-resolve finished games to advance winners up the bracket
                _auto_resolve(db, tour)
                    
                # Auto-Advance logic: Check if the current round is fully decided
                all_matches = db.query(ChessTournamentMatch).filter(ChessTournamentMatch.tournament_id == tour.id).all()
                cur = tour.current_round or 0
                undecided = [m for m in all_matches if m.round == cur and m.winner_id is None and m.status != "BYE"]
                if cur > 0 and len(undecided) == 0:
                    total_rounds = max((m.round for m in all_matches), default=0)
                    nxt = cur + 1
                    if nxt <= total_rounds:
                        print(f"Round {cur} finished. Auto-advancing to Round {nxt}...")
                        for m in all_matches:
                            if m.round == nxt:
                                m.activated = True
                                m.activated_at = datetime.now(timezone.utc)
                                if m.player_a_id and m.player_b_id and m.winner_id is None:
                                    m.status = "READY"
                        tour.current_round = nxt
                        db.commit()
                        db.refresh(tour)
                    
                # Find all PENDING, READY, or LIVE matches where BOTH players are bots
                # (A bot is a user with email starting with bot)
                matches = db.query(ChessTournamentMatch).filter(
                    ChessTournamentMatch.tournament_id == tour.id,
                    ChessTournamentMatch.activated == True,
                    ChessTournamentMatch.winner_id == None,
                    ChessTournamentMatch.player_a_id != None,
                    ChessTournamentMatch.player_b_id != None
                ).all()
                
                for m in matches:
                    u_a = db.query(User).filter(User.id == m.player_a_id).first()
                    u_b = db.query(User).filter(User.id == m.player_b_id).first()
                    
                    if not u_a or not u_b:
                        continue
                        
                    # We only simulate if at least one is a bot
                    is_a_bot = u_a.email.startswith("bot")
                    is_b_bot = u_b.email.startswith("bot")
                    
                    if not is_a_bot and not is_b_bot:
                        continue # A human vs human match
                        
                    if m.status in ("PENDING", "READY"):
                        # Mark ready and play
                        async with httpx.AsyncClient() as client:
                            if is_a_bot and not m.a_ready:
                                token_a = create_access_token({"sub": str(u_a.id)})
                                await client.post(
                                    f"{API_BASE_URL}/chess/tournaments/{tour.id}/matches/{m.id}/ready",
                                    headers={"Authorization": f"Bearer {token_a}", "X-Organization-ID": str(tour.organization_id)}
                                )
                                print(f"Bot {u_a.email} marked ready")
                                
                            if is_b_bot and not m.b_ready:
                                token_b = create_access_token({"sub": str(u_b.id)})
                                await client.post(
                                    f"{API_BASE_URL}/chess/tournaments/{tour.id}/matches/{m.id}/ready",
                                    headers={"Authorization": f"Bearer {token_b}", "X-Organization-ID": str(tour.organization_id)}
                                )
                                print(f"Bot {u_b.email} marked ready")
                                
                        db.refresh(m)
                        if m.a_ready and m.b_ready and not m.game_id:
                            # Start the game
                            async with httpx.AsyncClient() as client:
                                token = create_access_token({"sub": str(u_a.id if is_a_bot else u_b.id)})
                                res = await client.post(
                                    f"{API_BASE_URL}/chess/tournaments/{tour.id}/matches/{m.id}/play",
                                    headers={"Authorization": f"Bearer {token}", "X-Organization-ID": str(tour.organization_id)}
                                )
                                if res.status_code == 200:
                                    print(f"Match {m.id} started. Game ID assigned.")
                                else:
                                    print(f"Failed to play match: {res.text}")
                                    
                    elif m.status == "LIVE" and m.game_id:
                        game_key = f"{m.game_id}_{m.player_a_id}"
                        if is_a_bot and game_key not in active_tasks:
                            token_a = create_access_token({"sub": str(u_a.id)})
                            active_tasks[game_key] = asyncio.create_task(play_game(u_a.id, token_a, str(m.game_id)))
                            
                        game_key_b = f"{m.game_id}_{m.player_b_id}"
                        if is_b_bot and game_key_b not in active_tasks:
                            token_b = create_access_token({"sub": str(u_b.id)})
                            active_tasks[game_key_b] = asyncio.create_task(play_game(u_b.id, token_b, str(m.game_id)))
            finally:
                db.close()
                
            # Clean up finished tasks
            done_tasks = [k for k, t in active_tasks.items() if t.done()]
            for k in done_tasks:
                del active_tasks[k]
                
        except Exception as e:
            print(f"Error in bot manager: {e}")
            
        await asyncio.sleep(5)

if __name__ == "__main__":
    print("Starting Chess Bot Simulator...")
    asyncio.run(bot_manager())
