import sqlalchemy
from sqlalchemy import create_engine, text
import os

def run():
    # Attempt to fetch DB URL, otherwise default to typical Fly.io env var
    db_url = os.environ.get('DATABASE_URL')
    if not db_url:
        print("DATABASE_URL not found, using generic local connection")
        return

    engine = create_engine(db_url)
    
    with engine.connect() as conn:
        try:
            print("Adding is_blocked to users table...")
            conn.execute(text("ALTER TABLE users ADD COLUMN is_blocked BOOLEAN DEFAULT FALSE"))
            print("Successfully added is_blocked")
        except Exception as e:
            print(f"Skipped is_blocked (might already exist): {e}")

        try:
            print("Adding blood_group to user_profiles table...")
            conn.execute(text("ALTER TABLE user_profiles ADD COLUMN blood_group VARCHAR(10)"))
            print("Successfully added blood_group")
        except Exception as e:
            print(f"Skipped blood_group (might already exist): {e}")
            
        conn.commit()

if __name__ == '__main__':
    run()
