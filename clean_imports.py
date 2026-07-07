with open('mobile/lib/core/router/app_router.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
seen = set()
for line in lines:
    if "import" in line and "settings_screen.dart" in line:
        if line not in seen:
            seen.add(line)
            new_lines.append(line)
    else:
        new_lines.append(line)

with open('mobile/lib/core/router/app_router.dart', 'w') as f:
    f.writelines(new_lines)
