# V2 Definition of Done

A slice is **done** only when every applicable box is true. This is the contract
that keeps quality consistent without re-litigating it each time.

## Every slice
- [ ] Builds clean; `flutter analyze` reports no errors (CI green).
- [ ] **Both CI jobs green** — mobile (`flutter analyze` + `flutter test`) and
      backend (`python -m pytest`) run on every PR and both must pass, whatever
      the change touched. Run pytest locally before pushing when backend changes.
- [ ] Brackets balanced in every edited `.dart` file.
- [ ] **No emoji in UI** — Material Symbols only. (Unicode chess piece glyphs are
      game data and exempt.)
- [ ] **Theme-aware** — correct in both light and dark; reads colours from tokens
      (`AppColors` / `context.c*`), never hardcoded off-palette hex.
- [ ] **Localized** — all user-facing strings via `tr(en/ta/hi/ml)`.
- [ ] Roadmap checkbox ticked in `docs/v2/README.md`.

## When it adds a component
- [ ] Lives in `mobile/lib/core/design_system/components/` if reusable.
- [ ] Has a widget test (mirror `test/core/design_system/ds_feature_card_test.dart`).
- [ ] Respects reduce-motion for any animation (see `FadeSlideIn`).
- [ ] Overflow-safe: flexible children (`Expanded`/`Flexible`), tested at small
      widths and long (Tamil) strings.

## When it adds/changes an endpoint
- [ ] Pydantic schema updated; response shape documented in `api-contracts.md`.
- [ ] Tenant-scoped (`X-Organization-ID` / `require_tenant_id`) where applicable.
- [ ] Auth gate correct (public vs member vs admin) and **no PII leaked to public
      responses** (e.g. contact numbers stay on authenticated paths).
- [ ] pytest covering the happy path + the key guard (auth/filter/empty).
- [ ] Additive schema migrations only — rely on the startup column-reconcile; no
      destructive table rewrites.

## When it changes layout (on-device gate)
- [ ] Screenshot-checked on device/emulator: **en + ta**, **light + dark**.
- [ ] No overflow/clipping; compact header collapses correctly; grids wrap.
- [ ] If no screenshot was possible, the PR says so and flags the risk — never
      claim visual verification that didn't happen.

## Honesty clause
Report outcomes faithfully. If tests fail, say so with the output. If a step was
skipped or a check couldn't run, state it. "Done" means verified, not hoped.
