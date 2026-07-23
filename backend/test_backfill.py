import os
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine
from app.models.sports import Tournament, Fixture, Team

def fix():
    _db = SessionLocal()
    try:
        # Check if we can parse the types properly
        _t = _db.query(Tournament).filter(Tournament.sport == "cricket").first()
        print(f"Tournament: {_t}")
        
        for _f in _db.query(Fixture).filter(Fixture.status == "COMPLETED").all():
            print(f"Fixture: {_f.id}, winner: {_f.winner_id}")
            _lt_id = _f.team_b_id if str(_f.team_a_id) == str(_f.winner_id) else _f.team_a_id
            print(f"Loser ID: {_lt_id}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    fix()
