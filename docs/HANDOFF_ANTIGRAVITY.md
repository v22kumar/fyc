# Hand-off: Sprint 3 (Offline & Performance Core) + Go-Live Security Hygiene

**Assigned to:** a separate AI coding session (Antigravity CLI), working in
parallel with an ongoing session that owns Sprint 2 (nav shell cutover, Home,
Universal Search). This doc is the complete, self-contained brief — read it
fully before writing any code.

## Read first (in this order)

1. `docs/ROADMAP.md` — the product philosophy and full backlog. Section 0
   ("Go-live blockers") contains the security hygiene half of this
   assignment.
2. `docs/SPRINT_PLAN.md` — Sprint 3's full spec is under "SPRINT 3 — Offline
   & Performance Core." Also read the cross-cutting standards section near
   the top (design tokens, 4-language i18n, motion) — anything you build
   must follow it.
3. `docs/SPRINT_1_STATUS.md` — what already exists (design tokens, component
   library, the CI gate) and, importantly, the pattern this repo follows
   when a new CI check surfaces a pre-existing bug: fix it narrowly, note it
   plainly, don't silently skip it and don't turn it into a big refactor.
4. `docs/DEVICE_TEST_MATRIX.md` — the device/network/battery/storage
   conditions this whole sprint exists to serve. Test against this matrix,
   not just "does it compile."

## Why this sprint matters (don't skip this)

FYC Connect is a community app for a volunteer youth club in Kanyakumari
district, Tamil Nadu — many users are on 2G/3G, cheap Android phones, low
battery, low storage, prepaid data they're careful with. The product
philosophy (`ROADMAP.md`) is explicit: *"will this help a volunteer organize
people faster, and make the app feel welcoming to real youngsters — whether
opened in a village on 2G or a city on fibre?"* This sprint is the technical
foundation that makes that true. It is the highest-mission-value engineering
work in the whole plan — treat it accordingly, not as boilerplate.

## Scope — Part A: Sprint 3 (Offline & Performance Core)

Build these five pieces. They can land as separate PRs if that's cleaner for
you — don't feel obligated to land all of Sprint 3 in one PR.

1. **Device profile.** One signal combining connectivity type/quality
   (`connectivity_plus` + a rolling measure of recent response times),
   battery level + charging state + OS low-power mode (`battery_plus`), free
   storage, and the OS data-saver flag. Expose it as a simple
   Full/Balanced/Lite/Offline tier the rest of the app can read. Add a
   manual "Lite mode" toggle in Settings that forces the Lite tier
   regardless of the detected signal, defaulting on when the OS reports
   data-saver.
2. **Offline-first reads.** A local cache (Drift or Hive — pick one and be
   consistent) that Home, Feed, and Events read from first (render
   instantly), then refresh from network in the background. This is the
   single biggest UX change for a 2G user — prioritize it.
3. **Write outbox.** A queue for posts/comments (and flag the extension
   point for cricket ball-scoring, even if you don't wire scoring itself —
   that's Sprint 5's screen, not yours) with **client-generated idempotent
   IDs**, retried on reconnect, optimistic UI in the meantime. A dropped
   connection must never lose or double-submit an action.
4. **Adaptive images / Lite mode.** Serve smaller Cloudinary variants
   (thumbnail on Lite/Balanced, full-res only on WiFi or explicit tap);
   WebP where supported; no video autoplay outside the Full tier. Bounded
   LRU image + local-DB cache size, with a "Clear cache" action in Settings.
5. **Push over polling.** Audit the codebase for polling loops (there is at
   least one — the chess challenge screen polls every ~3s) and replace with
   FCM push + exponential backoff; stop all polling when the app is
   backgrounded. FCM is already wired (see `backend/app/services/
   notification_service.py` and `mobile/lib/main.dart`) — this is about
   removing polling, not building push from scratch.

**Acceptance bar:** cold Home render under ~1s from cache on a throttled 2G
profile (see `DEVICE_TEST_MATRIX.md` for how to simulate); no polling loop
left running while the app is backgrounded; a post/comment created offline
appears immediately (optimistic) and correctly syncs on reconnect without
duplicating.

## Scope — Part B: Go-live security hygiene (`ROADMAP.md` §0)

Small, independent, high-urgency, zero-overlap with Part A or with the
parallel Sprint 2 work:

1. **Remove hard-coded secrets.** `OTP_BYPASS_CODE` (backend) and any
   bootstrap-admin default password must come **only** from environment/Fly
   secrets — no fallback literal committed in the repo. Audit
   `backend/app/core/config.py` and any seed scripts. If a value must have a
   safe default for local dev, make it obviously fake/dev-only and
   documented, never something that could work in production if someone
   forgets to override it.
2. **Basic moderation.** A report-post endpoint + admin hide/delete for
   community posts (check `backend/app/routers/posts.py` — some of this may
   already partially exist from prior sprints; audit before building) and a
   simple user-block. This is a Play Store requirement for apps with
   user-generated content, not optional polish.
3. **Re-enable R8/resource shrinking** for the Android release build
   (`mobile/android/app/build.gradle.kts` — currently disabled with a
   comment explaining it was masking a Stockfish JNI issue; re-enable and
   verify on a physical/emulated release build that nothing breaks before
   committing to it).

## Hard constraints (learned the hard way this project — don't rediscover them)

- **CI is the real gate, not local success.** Whatever environment you run
  in, also open a PR against this repo and let `.github/workflows/
  ci-tests.yml` run — it executes `python -m pytest` (backend) and
  `flutter analyze --no-fatal-infos --no-fatal-warnings` + `flutter test`
  (mobile) on every PR. If backend tests need to run locally, use
  `python -m pytest`, not bare `pytest` — the latter fails with
  `ModuleNotFoundError: No module named 'app'` in this repo's layout.
- **Multi-tenant everywhere.** Every backend request carries an
  `X-Organization-ID` header; every router uses `require_tenant_id` /
  `get_current_user` from `app/dependencies.py`. Never query without
  scoping to the tenant.
- **4-language i18n is mandatory**, not optional, for any new user-facing
  string: use the `tr(en: ..., ta: ..., hi: ..., ml: ...)` helper
  (`mobile/lib/core/l10n/tr.dart`). No hardcoded English-only strings in new
  UI.
- **SQLite is single-writer; the backend runs a single uvicorn worker**
  (see `backend/Dockerfile` comment) because chess's live-game state is
  in-memory per-process. Don't add anything that assumes multiple workers
  without checking this constraint first.
- **Don't touch:** `mobile/lib/core/design_system/**` (Sprint 1's component
  library — read from it, don't modify it) and any Home/Play/Serve/Me
  screen content (that's the parallel Sprint 2 session's scope, to avoid
  merge collisions). If you need a UI component that doesn't exist yet in
  the design system, either build a minimal one in your own module or flag
  it rather than editing the shared library.
- **Never commit secrets, never disable CI checks to make them pass, never
  force-push to `main`.**

## Git workflow

Work on a new branch (e.g. `antigravity/sprint-3-offline-performance` and/or
`antigravity/security-hygiene` if you want to split Part A/B into separate
PRs). Open a PR against `main`; do not merge it yourself — this project's
convention is PR review before merge, even when the reviewer is another AI
session. Write a clear PR description covering what you built, what you
verified, and anything you deliberately deferred (this repo's established
convention — see how `docs/SPRINT_1_STATUS.md` is written — is to be
explicit about scope decisions, not silent about them).

---

## The literal prompt (paste this into Antigravity CLI)

```
You're picking up parallel work on FYC Connect, a Flutter + FastAPI app for a
volunteer youth club in rural Tamil Nadu. Another AI session already
delivered Sprint 1 (a design system + component library + a new CI gate at
.github/workflows/ci-tests.yml) and is now working on Sprint 2 (nav shell +
Home + search) in parallel with you.

Read docs/HANDOFF_ANTIGRAVITY.md in full first — it has your complete scope,
constraints, and acceptance criteria. Your assignment is:

Part A — Sprint 3 from docs/SPRINT_PLAN.md: Offline & Performance Core
(device profile, offline-first local cache for Home/Feed/Events, a write
outbox with idempotent IDs for posts/comments, adaptive/Lite-mode images,
and replacing polling with FCM push).

Part B — the "go-live security hygiene" items from docs/ROADMAP.md section
0: remove hard-coded secrets (OTP_BYPASS_CODE, bootstrap admin password),
add basic post moderation (report/hide/delete + user block), and re-enable
R8/resource shrinking on the Android release build.

Do not modify mobile/lib/core/design_system/** or any Home/Play/Serve/Me
screen content — that's the parallel session's scope. Work on a new branch,
verify against .github/workflows/ci-tests.yml (use `python -m pytest` for
the backend, not bare `pytest`), and open a PR rather than merging directly.
Follow the 4-language i18n convention (tr(en:,ta:,hi:,ml:)) for any new
user-facing text, and the multi-tenant X-Organization-ID pattern for any new
backend endpoint.

Start by reading docs/ROADMAP.md, docs/SPRINT_PLAN.md, docs/SPRINT_1_STATUS.md,
and docs/DEVICE_TEST_MATRIX.md, then report back your plan before writing code.
```
