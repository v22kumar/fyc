# Mobile architecture — the rules, and where they came from

An audit (2026-08-09) scored this layer 5.5/10: 75 presentation files
reached into the service locator, 39 call sites did their own HTTP with a
raw Dio, four API classes were static-method bags, and the two largest
features (chess, feed) had no repository at all. The rebuild that followed
closed all of that. This records the rules so they hold.

## The shape

Every feature is `features/<name>/{data,domain,presentation}`:

- **domain/repositories/** — the interface the feature's screens and blocs
  bind to. This is the testing seam: a widget test hands the screen a fake
  repository; nothing bends production code for tests.
- **data/** — models (wire shapes), datasources (the HTTP), repository
  impls. `.dio` may appear here and only here.
- **presentation/** — blocs, screens, widgets. No HTTP, no storage reads,
  no tournament/chess/cricket rule that belongs on an entity.

## The rules a review enforces

1. **No HTTP in presentation.** `grep -rn "\.dio" lib/features/*/presentation`
   must return nothing. It did return 39 sites once; each became a
   repository operation.
2. **No static API classes.** A class of `static Future`s resolving a Dio
   per call is unmockable; all four (feed, blood requests, civic,
   issue-complaint) became registered repositories.
3. **Dependencies arrive by constructor.** Router-built screens receive
   their repository from `app_router.dart` — the composition root, where
   `sl<>` is legitimate. Widgets never resolve another feature's bloc.
4. **Bottom sheets bind to domain interfaces.** Sheets open through the
   root navigator, outside the route's provider scope, so they resolve
   `sl<XRepository>()` at their construction point. That is the accepted
   exception — the seam is still the domain interface, and a test
   re-registers a fake.
5. **Language comes from `trLang()`**, never from a storage lookup in a
   widget. The resolver is wired once, by whoever constructs the
   `LocalStorage`.
6. **The rulebook lives on entities.** "Which button do I show" is domain
   logic — see `chess_tournament/domain/entities/tournament_entities.dart`
   (`actionFor`, `blocking`, `canStartNextRound`) for the reference shape.

## Known remaining debt, deliberately carried

- `features/ai` runs on Riverpod — the app's second DI system, one file.
- `home_screen.dart` (2,700 lines) and `cricket_scoring_screen.dart`
  (2,000) deserve splitting into widgets/; their data access is already
  behind repositories.
- `thirukkural`, `news`, `opportunities` bind to datasources directly —
  read-only single-endpoint features, smallest offenders left.
