with open('mobile/lib/core/design_system/shell/sos_sheet.dart', 'r') as f:
    text = f.read()

import re

# Remove SwitchListTile for Loud Siren and Trusted Contacts list and Add contact
text = re.sub(
    r'SwitchListTile\(.*?const SizedBox\(height: 8\),\s*const Text\(\'Trusted contacts\'.*?const SizedBox\(width: 8\),\s*IconButton\(\s*onPressed: _addContact,\s*icon: const Icon\(Icons\.add_circle_rounded,\s*color: Color\(0xFF16A34A\), size: 32\),\s*\),\s*\],\s*\),\s*',
    '',
    text,
    flags=re.DOTALL
)

with open('mobile/lib/core/design_system/shell/sos_sheet.dart', 'w') as f:
    f.write(text)
