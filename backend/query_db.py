import sqlite3
import sys
import uuid
from datetime import datetime

sys.path.append('.')

org_id = '8f8b80b7-4b71-4770-b183-5c5f49e49a1d'
test_token = 'AVweKohajldemHxif0W11cIpdIm8RIbljpFaXD_Oc7vymmQHAZBjW01CWcxLuV9K0YbZ74MCDa58c84Dcq438WCsjWVu-RM_UWHY_i-YJ3ID1GbAvZ6onBkY_N8h-ZXdieHfZBGI4fbeM6gK6yoi0l8G0A'
phone = '+919487984964'

# 1. Patch SQLite Database & insert test user
conn = sqlite3.connect('./fyc_connect.db')
c = conn.cursor()
try:
    c.execute("ALTER TABLE users ADD COLUMN phone_verified_at DATETIME;")
    c.execute("ALTER TABLE users ADD COLUMN email_verified_at DATETIME;")
    c.execute("ALTER TABLE users ADD COLUMN is_blocked BOOLEAN DEFAULT 0;")
except Exception as e:
    pass

# Insert the mock org if it doesn't exist
try:
    c.execute("INSERT INTO organizations (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)", (org_id.replace('-', ''), 'Test Org', datetime.utcnow(), datetime.utcnow()))
except Exception:
    pass

# Insert the test user
user_id = str(uuid.uuid4()).replace('-', '')
try:
    c.execute("INSERT INTO users (id, organization_id, phone_number, role, is_verified, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)", (user_id, org_id.replace('-', ''), phone, 'SUPER_ADMIN', 1, datetime.utcnow(), datetime.utcnow()))
except Exception as e:
    print('SQLite insert user error:', e)
conn.commit()
conn.close()

# 2. Test the API endpoint
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

response = client.post(
    "/api/v1/auth/firebase/login",
    json={
        "id_token": test_token,
        "organization_id": org_id,
    }
)
print('Response Status:', response.status_code)
print('Response Body:', response.json())
