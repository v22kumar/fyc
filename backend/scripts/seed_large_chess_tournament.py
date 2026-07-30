import sys
import os
import uuid
import random
from datetime import datetime, timezone

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.database import SessionLocal
from app.models.user import User, UserProfile
from app.models.tenant import Organization
from app.models.chess_tournament import ChessTournament, ChessTournamentEntry, ChessTournamentMatch
from app.core.security import get_password_hash

def seed_large_tournament():
    db = SessionLocal()
    try:
        org_id = uuid.UUID("8f8b80b7-4b71-4770-b183-5c5f49e49a1d")
        
        # 1. Create a tournament
        print("Creating tournament...")
        tour_id = uuid.uuid4()
        tour = ChessTournament(
            id=tour_id,
            organization_id=org_id,
            name="Mega 100-Player Automation Test",
            description="Created by E2E automation script",
            status="REGISTRATION_CLOSED",
            current_round=0,
            short_code="MEGA100"
        )
        db.add(tour)
        
        # 2. Create 100 users
        print("Creating 100 users...")
        users = []
        for i in range(100):
            uid = uuid.uuid4()
            u = User(
                id=uid,
                organization_id=org_id,
                phone_number=f"+91{9000000000 + i}",
                email=f"bot{i}@fycconnect.org",
                password_hash=get_password_hash("password123"),
                role="USER",
                is_verified=True,
                preferred_language="en"
            )
            users.append(u)
            db.add(u)
            
            p = UserProfile(
                user_id=uid,
                full_name_en=f"Bot Player {i+1}",
                full_name_ta=f"பாட் {i+1}"
            )
            db.add(p)
            
            # Register them to the tournament
            entry = ChessTournamentEntry(
                tournament_id=tour_id,
                user_id=uid,
                status="APPROVED",
                organization_id=org_id
            )
            db.add(entry)
            
        db.commit()
        
        # 3. Generate Bracket (Mimic start_tournament logic)
        print("Generating bracket...")
        players = [u.id for u in users]
        random.shuffle(players)
        
        import math
        n = len(players)
        depth = math.ceil(math.log2(n))
        bracket_size = 2 ** depth
        byes = bracket_size - n
        
        slots = []
        for i in range(bracket_size):
            slots.append(None)
            
        # standard seeding isn't strictly necessary for a random test, just interleave byes
        # distribute byes evenly
        for i in range(byes):
            slots[i * 2] = "BYE"
            
        p_idx = 0
        for i in range(bracket_size):
            if slots[i] != "BYE":
                slots[i] = players[p_idx]
                p_idx += 1
                
        round1_matches = []
        for i in range(0, bracket_size, 2):
            p_a = slots[i]
            p_b = slots[i+1]
            
            status = "PENDING"
            winner = None
            if p_a == "BYE" and p_b != "BYE":
                status = "BYE"
                winner = p_b
                p_a = None
            elif p_b == "BYE" and p_a != "BYE":
                status = "BYE"
                winner = p_a
                p_b = None
                
            m = ChessTournamentMatch(
                id=uuid.uuid4(),
                tournament_id=tour_id,
                organization_id=org_id,
                round=1,
                slot=i // 2,
                player_a_id=p_a,
                player_b_id=p_b,
                winner_id=winner,
                status=status,
                activated=True,
                activated_at=datetime.now(timezone.utc)
            )
            db.add(m)
            round1_matches.append(m)
            
        # Create empty slots for subsequent rounds
        for r in range(2, depth + 1):
            slots_in_round = bracket_size // (2 ** r)
            for s in range(slots_in_round):
                m = ChessTournamentMatch(
                    id=uuid.uuid4(),
                    tournament_id=tour_id,
                    organization_id=org_id,
                    round=r,
                    slot=s,
                    status="PENDING",
                    activated=False
                )
                db.add(m)
                
        tour.status = "IN_PROGRESS"
        tour.current_round = 1
        db.commit()
        
        # Advance byes
        print("Advancing byes...")
        for m in round1_matches:
            if m.status == "BYE":
                nxt = db.query(ChessTournamentMatch).filter(
                    ChessTournamentMatch.tournament_id == tour_id,
                    ChessTournamentMatch.round == 2,
                    ChessTournamentMatch.slot == m.slot // 2
                ).first()
                if nxt:
                    if m.slot % 2 == 0:
                        nxt.player_a_id = m.winner_id
                    else:
                        nxt.player_b_id = m.winner_id
                        
        db.commit()
        
        print("="*40)
        print("Tournament seeded successfully!")
        print(f"Tournament ID: {tour_id}")
        print("Test Player Account:")
        print(f"Phone: {users[0].phone_number}")
        print(f"Password: password123")
        print("="*40)
        
    except Exception as e:
        db.rollback()
        print(f"Failed to seed tournament: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_large_tournament()
