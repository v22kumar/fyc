import sys
import os

# Ensure the app module is in the path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.database import engine
from sqlalchemy import text

def add_columns():
    with engine.connect() as conn:
        print("Checking if facebook_access_token exists...")
        try:
            conn.execute(text("ALTER TABLE organizations ADD COLUMN facebook_access_token VARCHAR"))
            print("Added facebook_access_token column.")
        except Exception as e:
            print(f"facebook_access_token might already exist: {e}")
            
        try:
            conn.execute(text("ALTER TABLE organizations ADD COLUMN facebook_page_id VARCHAR"))
            print("Added facebook_page_id column.")
        except Exception as e:
            print(f"facebook_page_id might already exist: {e}")
            
        conn.commit()

if __name__ == "__main__":
    add_columns()
    print("Database schema update complete.")
