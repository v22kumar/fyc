import re

with open("backend/app/routers/chess_tournaments.py", "r") as f:
    code = f.read()

old_block = """    if tour.status not in ("REGISTRATION_OPEN", "REGISTRATION_CLOSED"):
        raise HTTPException(status_code=400, detail="Tournament already started")

    entries = _entries(db, tour_id)"""

new_block = """    if tour.status not in ("REGISTRATION_OPEN", "REGISTRATION_CLOSED"):
        raise HTTPException(status_code=400, detail="Tournament already started")

    # Optimistic lock: ensure we are the only ones starting it
    updated = db.query(ChessTournament).filter(
        ChessTournament.id == tour_id,
        ChessTournament.status.in_(["REGISTRATION_OPEN", "REGISTRATION_CLOSED"])
    ).update({"status": "STARTING_LOCK"})
    
    if updated == 0:
        db.rollback()
        raise HTTPException(status_code=400, detail="Tournament already starting or started")

    entries = _entries(db, tour_id)"""

if old_block in code:
    code = code.replace(old_block, new_block)
    with open("backend/app/routers/chess_tournaments.py", "w") as f:
        f.write(code)
    print("Patched start_tournament successfully!")
else:
    print("Could not find start_tournament block to patch.")
