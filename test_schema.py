from datetime import datetime
from pydantic import ValidationError
import sys

# Add backend to path
sys.path.append('backend')
from app.schemas.event import EventRegistrationCreate

payload = {
    'name': 'Test User',
    'dob': '2000-01-01T00:00:00.000',
    'gender': 'Male',
    'mobile_number': '1234567890',
    'email': None,
    'address': None,
    'school_college': 'Test College',
    'class_grade': None,
    'member_id': None,
    'competition_category': [],
    'remarks': None
}

try:
    obj = EventRegistrationCreate(**payload)
    print("Success:", obj)
except ValidationError as e:
    print("Validation Error:", e.json())
