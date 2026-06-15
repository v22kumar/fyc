#!/usr/bin/env python3
"""
CI check: detect hardcoded user-visible strings in Flutter screens.
Fails (exit 1) if any .dart file outside l10n/ contains:
  - Hardcoded Tamil Unicode text in Text() or SnackBar() widgets
  - Common English user-visible phrases that should be in l10n
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
MOBILE_LIB = ROOT / "mobile" / "lib"
L10N_DIR = MOBILE_LIB / "core" / "l10n"

# Tamil Unicode range: U+0B80–U+0BFF
TAMIL_PATTERN = re.compile(r'Text\([\'"]([^\'"]*[஀-௿][^\'"]*)[\'"]')

# Common English phrases that should never be hardcoded (outside l10n)
BANNED_EN_PATTERNS = [
    re.compile(r'Text\([\'"]Loading\.\.\.[\'"]'),
    re.compile(r'Text\([\'"]Register as Donor[\'"]'),
    re.compile(r'Text\([\'"]Blood Donation Hub[\'"]'),
    re.compile(r'Text\([\'"]Please select your blood group[\'"]'),
    re.compile(r'Text\([\'"]Registered successfully[\'"]'),
]

violations = []

for dart_file in MOBILE_LIB.rglob("*.dart"):
    # Skip l10n directory (strings_en.dart etc. legitimately have raw strings)
    if L10N_DIR in dart_file.parents:
        continue

    content = dart_file.read_text(encoding="utf-8")
    lines = content.splitlines()

    for i, line in enumerate(lines, 1):
        # Check for hardcoded Tamil text in Text() widgets
        if TAMIL_PATTERN.search(line):
            # Allow: comments, l10n files, hint text (they're ok in TextField hints)
            if not any(skip in line for skip in ["//", "hintText", "data-ta", "placeholder"]):
                violations.append(f"{dart_file.relative_to(ROOT)}:{i}: hardcoded Tamil text → {line.strip()[:80]}")

        # Check for banned English phrases
        for pat in BANNED_EN_PATTERNS:
            if pat.search(line):
                violations.append(f"{dart_file.relative_to(ROOT)}:{i}: hardcoded English phrase → {line.strip()[:80]}")

if violations:
    print("❌ Hardcoded string violations found:")
    for v in violations:
        print(f"  {v}")
    print(f"\nTotal: {len(violations)} violation(s). Move strings to l10n files.")
    sys.exit(1)
else:
    print(f"✅ No hardcoded string violations found in {MOBILE_LIB}")
    sys.exit(0)
