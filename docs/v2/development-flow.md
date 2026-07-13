# V2 Development Flow

The point of this document: **no distraction.** Anyone picking up V2 knows
exactly how a change goes from idea to merged, without re-deciding process.

## Branch

- All V2 work happens on **`claude/v2-redesign`**, branched from `main`.
- It stays **independent** of `claude/end-to-end-readiness-b531n1` (V1 readiness).
  V1 fixes do not stack on V2; V2 slices do not land on the readiness branch.
- Keep in sync with `main` by rebasing/merging `main` in when needed — never the
  reverse.

## One slice = one PR

A **slice** is the smallest change that is independently reviewable and
shippable. Examples of a good slice:
- "Add `DSAnimatedCounter` + its widget test."
- "Add `GET /sports/live` + pytest."
- "Wire the hero carousel into Home."

Not a slice: "Phase 2" (too big), "counter + carousel + token refactor" (batched
and unrelated).

## The loop

1. Pick the next unchecked box in `README.md`.
2. Build it. Reuse first (check the reuse map). Tests included.
3. Self-verify: analyzer/tests locally where possible; bracket-balance every
   edited `.dart`; confirm no UI emoji.
4. Commit (Conventional Commits), push, open a PR describing the slice.
5. **Wait for CI green** — `flutter analyze` + `flutter test` (mobile) and
   `python -m pytest` (backend). Fix red before anything else.
6. Squash-merge. Tick the box in `README.md` (part of the same or a trailing PR).
7. Repeat.

Because the branch is shared and force-pushed per PR, **only one slice is in
flight at a time** — merge before starting the next.

## CI is the gate

- Mobile: `flutter analyze` (no fatal infos/warnings config) + `flutter test`.
  This is the **only** automated Dart check — there is no local Flutter here, so
  treat CI as authoritative.
- Backend: `python -m pytest` (runs locally too — run before pushing).
- A PR does not merge until all checks are green.

## On-device gate (layout-sensitive slices)

`flutter analyze` cannot catch overflow, clipping, or a header that collapses
wrong. Slices that change layout — compact header, carousel, animated counters,
grids — get an **on-device or emulator screenshot check** before merge, in both
**en and ta** (Tamil strings are longest) and **light + dark**. If a screenshot
isn't available, say so in the PR and flag the risk rather than claiming it's
verified.

## Commit convention

`type(scope): summary` — e.g. `feat(home): compact collapsing header (v2 1.1)`.
Reference the roadmap slice number. No model identifiers or internal IDs in
commit messages, PR bodies, or code.

## When to stop and ask

Ask the user (not guess) when a slice needs a product decision the plan didn't
settle — e.g. which 8 actions in the quick-actions grid, or how "nearby" is
scoped for recommendations. Otherwise, follow the plan and keep moving.
