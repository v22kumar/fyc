import re

# Update backend
with open('backend/app/models/issue.py', 'r') as f:
    be = f.read()
be = re.sub(
    r'ISSUE_CATEGORIES\s*=\s*\[.*?\]',
    'ISSUE_CATEGORIES = ["ROAD_TRAFFIC", "POWER_CUT", "WATER", "OTHER"]',
    be
)
with open('backend/app/models/issue.py', 'w') as f:
    f.write(be)

# Update admin
with open('admin/src/types/index.ts', 'r') as f:
    ad = f.read()

ad = re.sub(
    r'export type IssueCategory =\s*\| \'ROAD\'\s*\| \'WATER\'\s*\| \'STREET_LIGHT\'\s*\| \'GARBAGE\'\s*\| \'SAFETY\'\s*\| \'OTHER\';',
    "export type IssueCategory =\n  | 'ROAD_TRAFFIC'\n  | 'POWER_CUT'\n  | 'WATER'\n  | 'OTHER';",
    ad
)

ad = re.sub(
    r'export const CATEGORY_LABELS: Record<IssueCategory, string> = \{.*?OTHER:\s*\'Other\',\s*\};',
    "export const CATEGORY_LABELS: Record<IssueCategory, string> = {\n  ROAD_TRAFFIC: 'Road / Traffic',\n  POWER_CUT: 'Power Cut',\n  WATER: 'Water',\n  OTHER: 'Other',\n};",
    ad,
    flags=re.DOTALL
)
with open('admin/src/types/index.ts', 'w') as f:
    f.write(ad)

# Update mobile
with open('mobile/lib/features/issues/presentation/screens/submit_issue_screen.dart', 'r') as f:
    mo = f.read()

new_categories = """const _categories = [
  _Cat('ROAD_TRAFFIC', '🛣️', 'சாலை / போக்குவரத்து', 'Road/Traffic', 'Potholes, Blockages, etc.', Color(0xFF16A34A)),
  _Cat('POWER_CUT',    '⚡',  'மின் தடை',          'Power Cut',    'Outages, Broken wires',    Color(0xFFD97706)),
  _Cat('WATER',        '💧',  'தண்ணீர் பிரச்சனை',    'Water',        'Leakages, Supply, etc.',   Color(0xFF2563EB)),
  _Cat('OTHER',        '📋',  'மற்றவை',             'Other',        'Other general issues',     Color(0xFF6B7280)),
];"""

mo = re.sub(
    r'const _categories = \[.*?\];',
    new_categories,
    mo,
    flags=re.DOTALL
)
mo = mo.replace("'ROAD'", "'ROAD_TRAFFIC'")

with open('mobile/lib/features/issues/presentation/screens/submit_issue_screen.dart', 'w') as f:
    f.write(mo)

