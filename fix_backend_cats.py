import re

with open('backend/app/models/issue.py', 'r') as f:
    text = f.read()
text = text.replace('ROAD = "ROAD"', 'ROAD_TRAFFIC = "ROAD_TRAFFIC"')
text = text.replace('WATER = "WATER"', 'POWER_CUT = "POWER_CUT"\n    WATER = "WATER"')
text = text.replace('STREET_LIGHT = "STREET_LIGHT"\n    GARBAGE = "GARBAGE"\n    SAFETY = "SAFETY"', '')
with open('backend/app/models/issue.py', 'w') as f:
    f.write(text)

with open('backend/app/routers/issues.py', 'r') as f:
    text = f.read()
text = text.replace('"ROAD":         "Municipal Engineering / PWD",', '"ROAD_TRAFFIC": "Traffic Police / PWD",\n    "POWER_CUT": "TNEB",')
text = text.replace('"STREET_LIGHT": "TNEB",\n    "GARBAGE":      "Sanitary Inspector",\n    "SAFETY":       "Local Police Station",', '')
with open('backend/app/routers/issues.py', 'w') as f:
    f.write(text)
