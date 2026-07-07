import re

with open('mobile/lib/core/design_system/shell/sos_sheet.dart', 'r') as f:
    text = f.read()

text = re.sub(r'\s*bool _loudSiren = true;\n?', '\n', text)
text = re.sub(r'\s*final _addCtrl = TextEditingController\(\);\n?', '\n', text)
text = re.sub(r'\s*final siren = await SosService.getLoudSiren\(\);\n?', '\n', text)
text = re.sub(r'\s*_loudSiren = siren;\n?', '\n', text)
text = re.sub(r'\s*_addCtrl\.dispose\(\);\n?', '\n', text)

text = re.sub(
    r'\s*Future<void> _addContact\(\) async \{.*?\n  \}\n',
    '\n',
    text,
    flags=re.DOTALL
)

text = re.sub(
    r'\s*Future<void> _removeContact\(String n\) async \{.*?\n  \}\n',
    '\n',
    text,
    flags=re.DOTALL
)

with open('mobile/lib/core/design_system/shell/sos_sheet.dart', 'w') as f:
    f.write(text)
