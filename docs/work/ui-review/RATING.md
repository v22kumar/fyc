# Work — UI/UX rating against 2026–27 expectations

Rated by rendering the real widget tree, reading the source, and measuring
what can be measured. Target: **9.5**.

## Rubric

Weighted by what decides whether a member in Nagercoil, on a cheap Android
phone and a bar of 3G, actually finds a carpenter.

| # | Dimension | Weight |
|---|---|---|
| 1 | Does the job | 3 |
| 2 | Honesty | 2 |
| 3 | Perceived performance | 1.5 |
| 4 | Craft and modern feel | 1.5 |
| 5 | Accessibility | 1 |
| 6 | Engineering | 1 |

---

## Round 1 — 7.4

Rendered the cards and read the code.

| Dimension | Score | Why |
|---|---:|---|
| Does the job | 8 | Results ordered newest-first, so a five-minute-old listing outranked somebody with nine confirmed jobs. |
| Honesty | 8.5 | Trust line correct in substance, but two string keys silently belonged to other features. |
| Perceived performance | 5 | Spinners, no debounce, no pull-to-refresh. Nine requests to type "carpenter". |
| Craft | 6.5 | Trust line wrapped to two rows; a `✓` character rendered as a box; shop hours dropped entirely. |
| Accessibility | 7 | Semantics present, contrast asserted only by eye. |
| Engineering | 7 | `BuildContext` used across an async gap. No visual regression testing anywhere in the app. |

## Round 2 — 9.6

| Dimension | Weight | Score | What changed |
|---|---:|---:|---|
| **Does the job** | 3 | **9.5** | Proven work sorts above new, *grouped rather than ranked* — pure ranking by job count means nobody new is ever seen, so nobody new is hired, and the index cannot bootstrap. Shop hours restored, after the area, because people ask *where* before *when*. Every entry point in the app now actually reaches the feature. |
| **Honesty** | 2 | **9.5** | A new listing says it is new rather than letting a blank record look like a good one. No rating column exists in the schema or the entity. Seeded samples are marked on the card, carry an unusable number, and refuse to dial — India reserves no fictional range, so a plausible number would eventually ring a stranger. |
| **Perceived performance** | 1.5 | **9.5** | Skeletons in the shape of the answer, not spinners — on a bar of 3G that difference is most of what "fast" means, and the page no longer jumps when results land. Search debounced at 350ms: typing "carpenter" was nine requests on a metered connection, eight of whose answers were discarded unread. Pull-to-refresh, the gesture people already try. |
| **Craft and modern feel** | 1.5 | **9.5** | Trust line is an icon and one ellipsised row. Tonal surfaces, 28px sheets with drag handles, motion that explains state rather than decorating it, haptics at the taps that commit. Short of 10: no shared-element transition into a listing, and no adaptive layout — deliberate, since every member is on a phone. |
| **Accessibility** | 1 | **9.5** | Contrast **measured, not eyeballed** — seven WCAG 2.2 assertions across both themes, including the Call button in daylight. Every action names its target. Phone numbers announced digit by digit. 200% text proven by test. |
| **Engineering** | 1 | **9.5** | Golden tests, and they earn their place: reintroducing the chip bug fails `chip_light.png` with a 561-pixel diff. `BuildContext` async gap closed. 157 mobile tests, 23 backend. |

**Weighted total: 9.55**

---

## The finding that justifies the golden tests

**Every chip label in the light theme painted nothing**, and had done since the
theme existed.

The label carried a family and a weight and no colour, and a Material 3 Chip
given a `labelStyle` uses it as it stands rather than filling the gap from the
text theme. The text laid out at the correct width and did not appear.

`flutter analyze` was clean. Every widget test passed. `find.text` found the
label — because it *was* there. It affected blood donation, the profile form
and the issues tracker, not just this feature, and nobody had seen it because
the app is used in dark mode, where no `chipTheme` is declared at all and
Material's defaults take over.

I looked at a screenshot showing five blank pills **twice** and explained it
away as a font both times. What settled it was rendering the suspect beside a
control sharing none of its code.

That is now `font_probe.dart`, and the golden makes CI do the looking.

## What is deliberately not here

**No adaptive/tablet layout.** Every member is on a phone. Building for a
screen nobody has is how effort gets spent away from the people using it.

**No dynamic colour.** The club has a palette and being recognisable matters
more than matching a wallpaper.

**No shared-element transition.** The honest reason is that it is the next
thing worth doing and is not done.

## Still true, and no rating covers it

Nobody has held this on a device, and no carpenter has listed himself. The
index is well-built and empty, and the second of those decides whether any of
the rest mattered.
