import sys
import os
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.database import SessionLocal
from app.models.user import User, UserProfile
from app.models.chess_tournament import ChessTournament, ChessTournamentEntry, ChessTournamentMatch
from app.routers.chess_tournaments import start_tournament, _advance

def _make_user(db, org_id, phone, role="VOLUNTEER", name="Player"):
    u = User(id=uuid.uuid4(), organization_id=org_id, phone_number=phone, role=role)
    db.add(u)
    p = UserProfile(user_id=u.id, full_name_en=name, full_name_ta=name)
    db.add(p)
    db.commit()
    return u

def seed():
    db = SessionLocal()
    mgr = db.query(User).filter_by(phone_number="+919876543210").first()
    if not mgr:
        mgr = db.query(User).first()
        
    org_id = mgr.organization_id
    
    t = ChessTournament(
        id=uuid.uuid4(),
        organization_id=org_id,
        name="FYC Horizontal Bracket View",
        description="Swipe to see panning layout!",
        status="REGISTRATION_CLOSED",
        current_round=1,
        created_by_user_id=mgr.id
    )
    db.add(t)
    db.commit()
    
    players = []
    for i in range(1, 9):
        phone = f"+91888881111{i}"
        u = db.query(User).filter_by(phone_number=phone).first()
        if not u:
            u = _make_user(db, org_id, phone, name=f"Player {i}")
        players.append(u)
        
        entry = ChessTournamentEntry(
            id=uuid.uuid4(),
            organization_id=org_id,
            tournament_id=t.id,
            user_id=u.id,
            status="APPROVED"
        )
        db.add(entry)
    db.commit()
    
    # generate bracket
    start_tournament(t.id, db=db, tenant_id=org_id, current_user=mgr)
    
    matches = db.query(ChessTournamentMatch).filter_by(tournament_id=t.id).order_by(ChessTournamentMatch.round, ChessTournamentMatch.slot).all()
    # Advance first match
    if matches and len(matches) > 0:
        m1 = matches[0]
        m1.winner_id = m1.player_a_id
        m1.status = "DONE"
        _advance(db, t, m1, m1.winner_id)
        
        if len(matches) > 1:
            m2 = matches[1]
            m2.winner_id = m2.player_b_id
            m2.status = "DONE"
            _advance(db, t, m2, m2.winner_id)
        
        db.commit()
        
    print(f"Tournament {t.id} successfully created and seeded!")

if __name__ == "__main__":
    seed()
