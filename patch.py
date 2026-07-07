import re

with open("backend/app/routers/chess_tournaments.py", "r") as f:
    code = f.read()

# Replace the block in play_match:
old_block = """    if m.game_id is None:
        game = ChessGame(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            white_id=m.player_a_id,
            black_id=m.player_b_id,
            mode="online",
            status="waiting",
            time_control="untimed",
        )
        db.add(game)
        m.game_id = game.id
        m.status = "LIVE"
    db.commit()
    return {"game_id": str(m.game_id)}"""

new_block = """    if m.game_id is None:
        game = ChessGame(
            id=uuid.uuid4(),
            organization_id=tenant_id,
            white_id=m.player_a_id,
            black_id=m.player_b_id,
            mode="online",
            status="waiting",
            time_control="untimed",
        )
        db.add(game)
        db.flush()
        
        # Optimistic concurrency: ensure no other thread just created the game
        updated = db.query(ChessTournamentMatch).filter(
            ChessTournamentMatch.id == match_id,
            ChessTournamentMatch.game_id.is_(None)
        ).update({"game_id": game.id, "status": "LIVE"})
        
        if updated == 0:
            db.rollback()
            m = db.query(ChessTournamentMatch).filter(ChessTournamentMatch.id == match_id).first()
        else:
            m.game_id = game.id

    db.commit()
    return {"game_id": str(m.game_id)}"""

if old_block in code:
    code = code.replace(old_block, new_block)
    with open("backend/app/routers/chess_tournaments.py", "w") as f:
        f.write(code)
    print("Patched successfully!")
else:
    print("Could not find block to patch.")
