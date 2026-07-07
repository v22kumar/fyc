import re

with open('mobile/lib/core/router/app_router.dart', 'r') as f:
    text = f.read()

# Add import
text = text.replace(
    "import '../../service_locator.dart';",
    "import '../../service_locator.dart';\nimport '../../features/settings/presentation/screens/safety_settings_screen.dart';\nimport '../../features/settings/presentation/screens/settings_screen.dart';"
)

# Add route
route_to_add = """
    GoRoute(
      path: '/settings/safety',
      builder: (context, state) => const SafetySettingsScreen(),
    ),"""

text = text.replace(
    "path: '/settings',\n      builder: (context, state) => const SettingsScreen(),\n    ),",
    "path: '/settings',\n      builder: (context, state) => const SettingsScreen(),\n    )," + route_to_add
)

with open('mobile/lib/core/router/app_router.dart', 'w') as f:
    f.write(text)
