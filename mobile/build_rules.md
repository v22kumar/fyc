# Build Rules for FYC Connect Mobile

Strict rules to preserve existing implementations during package updates and bug fixing:

1. **Feature Preservation**: Do not alter, delete, or refactor any functional or UI implementation of the newly pulled features (e.g., the Chess ecosystem, prestige system, or AI/online game pages).
2. **Dependency Resolution**: Only modify package versions in `pubspec.yaml` (e.g., correcting the unavailable `stockfish_chess_engine` version `^3.0.0` to the actual latest release version `^0.8.2`) to permit package resolution and compile success.
3. **Local Testing Bypass**: Allow a dedicated local-only credential bypass (`admin` / `password123`) to resolve login blockages during APK testing without altering the production API auth endpoint integration.
