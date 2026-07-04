# Sprint 1 — Status Report

Scope: `docs/SPRINT_PLAN.md` § Sprint 1 (Design System & Foundations). This
report is the honest accounting of what shipped, what was deliberately
deferred (and why), and what was verified vs. not verifiable in this
environment — written so nothing is silently incomplete.

## Delivered

### Design tokens & typography (D1)
- `mobile/lib/core/design_system/tokens.dart` — Deep Navy / Mint / Amber
  palette + semantic colors, 8dp spacing scale, the exact radius scale from
  the spec (card 24 / button 20 / dialog 28), three elevation levels only,
  200ms standard motion duration.
- `mobile/lib/core/design_system/typography.dart` — Plus Jakarta Sans (Latin)
  + Noto Sans Tamil/Devanagari/Malayalam, fixed Display/Heading/Title/Body/
  Label hierarchy, nothing below 14sp.
- **Additive, not a live re-theme.** `core/theme/app_theme.dart` (used by
  every shipping screen) is untouched. Cutting screens over to the new
  tokens is Sprint 2+ work, screen-by-screen, per the plan — flipping the
  live palette today would reskin the whole shipping app in one uncontrolled
  step instead of the planned, testable rollout.

### Component library (D2/D3)
`mobile/lib/core/design_system/components/`: `DSButton` (filled/outlined/
tonal/text/danger + loading/disabled), `DSCard` (7 kinds + `DSCardIcon`),
`DSInput` set (search/dropdown/OTP/date/location), `DSChip` (5 kinds + a
`.status()` convenience mapping live/upcoming/completed/etc.), `DSBadge` (6
kinds incl. a pulsing "LIVE"), `DSEmptyState`, `DSSkeletonBlock`/
`DSSkeletonList`, `DSErrorState` — the "never show raw No Data / 500" rule
from the spec is structural in these widgets (title+message+primary action
required by the constructor for empty state; human message+retry for error
state).

### Navigation shell + review surface (D1)
- `mobile/lib/core/design_system/shell/app_shell_v2.dart` — the 4-tab shell
  (Home/Play/Serve/Me) with a persistent SOS control reachable from every
  tab (per the locked IA decision — no separate Community tab).
- `mobile/lib/core/design_system/design_system_gallery_screen.dart` — one
  screen rendering every component in every state, with live dark-mode and
  language toggles, plus a button to preview the shell.
- Registered at **`/design-system`** in `app_router.dart`. **Not linked from
  any production screen or nav** — reachable only by direct route, for
  design/QA review this sprint. Zero risk to the shipping app.
- The shell itself is **not wired as the app's live entry point**. Cutting
  over happens in Sprint 2 once Home/Play/Serve/Me each have real migrated
  content — switching today would orphan every screen not yet sorted into a
  bucket (chess, green, gallery, directory, …), which is a regression, not a
  foundation.

### Backend hardening (D4)
- `GZipMiddleware` (main.py) — compresses list/feed responses.
- A catch-all `Exception` handler (main.py) — logs the real traceback
  server-side, returns one clean human message client-side. Verified it does
  **not** shadow FastAPI's own `HTTPException` handling (existing 400/403/404
  raises across the codebase are unaffected — Starlette resolves the
  most-specific registered handler first).
- `app/core/etag.py` — `compute_etag` / `set_etag` / `etag_not_modified`,
  applied to **4 representative list endpoints**: `GET /posts`,
  `GET /announcements`, `GET /events`, `GET /sports/tournaments`. This
  proves the pattern on high-traffic endpoints; it is **not** applied to all
  150+ routes in one sprint (too much surface to touch safely without
  per-endpoint regression coverage). Remaining endpoints are a Sprint 2+
  checklist, not silently dropped.
- `app/core/pagination.py` — a standard `pagination_params` dependency for
  **new** list endpoints going forward (default 20/page, max 50). Existing
  endpoints keep their current bounds (audit found real inconsistency:
  `audit.py` le=500, `chess.py` le=100/200, `posts.py` le=50, `news.py`
  per-feed constants) — rewriting all of them this sprint risked behavior
  changes across many routes with no dedicated test coverage; documented
  here rather than mass-edited.

### CI hardening + tests (D5)
- **New workflow `.github/workflows/ci-tests.yml`** — runs on every PR to
  `main` and every non-`main` branch push. This is a real gap fix: before
  this sprint, `flutter-build.yml` and `fly-deploy.yml` both trigger only on
  **push to main**, meaning nothing automated gated a merge — a broken PR
  had no check before landing. Two jobs: `pytest` (backend) and
  `flutter analyze` (errors only) + `flutter test` (mobile).
- 7 new Flutter widget-test files under `mobile/test/core/design_system/`
  covering every new component's rendering + interaction + disabled/loading
  states, plus the shell's tab-switching and SOS reachability.
- **Deliberate deviation from "golden tests" in the sprint plan wording:**
  wrote structural/interaction widget tests, not pixel-golden image tests.
  This environment has no way to render or visually verify actual pixels,
  and cross-platform font-rendering variance is a well-known source of
  flaky golden-test failures in CI. Widget tests (verify the right text/
  widget/state renders and the right callback fires) give real regression
  protection without that flakiness risk. Revisit pixel goldens once a
  designer/device is available to author and approve baseline images.
- 1 new backend test file (`tests/test_etag_and_errors.py`) — 6 tests, all
  passing (3 pure-function `compute_etag` tests + 3 real-HTTP-stack tests
  for gzip/ETag/304/clean-error-envelope via the existing `client`/`db`
  pytest fixtures).

## Verified vs. not verifiable here

**Backend — actually run and confirmed in this session:**
- `python -m pytest tests/test_etag_and_errors.py` → 6 passed.
- Full HTTP-stack checks via `TestClient`: `GET /posts` returns
  `Content-Encoding: gzip` and an `ETag` header; a matching `If-None-Match`
  returns `304` with an empty body; a stale one returns `200`; the same
  round-trip re-confirmed for `/announcements`, `/events`,
  `/sports/tournaments` after refactoring them to `Model.model_validate(...)`
  (needed so the ETag is computed over the exact shape the client receives)
  — output unchanged (`title_en`, `registration_count`, `phase` all still
  correct) so this is not a regression.
- **Pre-existing, unrelated flake noted, not introduced by this sprint:**
  the pytest `db` fixture's teardown (`Base.metadata.drop_all`) throws "no
  such table" warnings/errors on this SQLite test setup. Confirmed this
  happens identically on the **pre-existing** `tests/test_announcements.py`
  suite (9 passed / 9 teardown errors, before any Sprint 1 change) — so it's
  a pre-existing test-harness quirk, not something introduced here. All test
  *assertions* pass in both cases; only fixture teardown warns.

**Mobile — could not run locally; CI is the actual gate:**
This environment has no Flutter SDK, so none of the new Dart code (8
components, tokens/typography, shell, gallery screen, router edit, 7 test
files) could be compiled or executed locally. Written as carefully as
possible (verified against known-stable Flutter/Material3 APIs), but
`ci-tests.yml`'s `flutter analyze` + `flutter test` job — introduced in this
same sprint — is the first real compile/test check these files get. If it
surfaces a mistake, that's the system working as designed; noting this
plainly rather than claiming false certainty.

## Other sprint-scoped decisions

- **`google_fonts` API safety:** built on `GoogleFonts.getFont('Family Name')`
  (the package's stable dynamic lookup) rather than the auto-generated
  per-font methods (`GoogleFonts.plusJakartaSans()` etc.), because this
  environment has no way to verify the generated method names against the
  installed package version before CI runs. `getFont` with the official
  Google Fonts family-name string is documented, version-stable API.
- **Runtime font fetching, not bundled assets:** `DSFonts` uses
  `google_fonts`'s default runtime-fetch-and-cache behavior, matching the
  existing `app_theme.dart` convention (`GoogleFonts.outfit()`), rather than
  introducing a second font-loading strategy mid-sprint. Bundling fonts as
  offline assets is flagged as Sprint 3 (Offline & Performance Core) work —
  it's a connectivity concern, not a design-system one.
- **Logo:** `docs/LOGO_BRIEF.md` — a written brief only. No image-generation
  tool is available in this session, so no placeholder asset was fabricated
  (a placeholder would likely need redoing anyway). The brief gives a
  designer concrete directions + the villager-validation method to use
  before finalizing.

## Follow-up checklist (not silently dropped, just not this sprint)

- [ ] Apply `etag_not_modified`/`set_etag` to the remaining list endpoints
      beyond the 4 done this sprint (blood donors, directory, opportunities,
      gallery, notifications, chess lists, …).
- [ ] Migrate new list endpoints to `pagination_params`; consider aligning
      existing endpoints' bounds once there's dedicated coverage for each.
- [ ] Bundle Plus Jakarta Sans / Noto Sans (ta/hi/ml) as offline assets
      (Sprint 3).
- [ ] Produce and villager-validate 3–5 logo candidates from
      `docs/LOGO_BRIEF.md`, then integrate the chosen mark.
- [ ] Sprint 2: migrate real screens into the `AppShellV2` buckets and cut
      over the app's live entry point.
