# FYC Connect — "Kolam" Elite Redesign (Material Design 3)

**Status:** Approved direction · Phase 1 shipping
**Owner:** Design/Engineering
**Scope:** Mobile app (Flutter), both light & dark themes

---

## 1. The idea in one paragraph

FYC Connect stops looking like a generic white-card admin tool and starts
looking like what it is: the digital home of a 25-year-old Tamil youth club.
We adopt Material Design 3's *tonal surface* system — **no pure white
anywhere** — layered over a subtle, culturally-rooted **kolam pattern**
(the South Indian dot-grid geometry drawn at every Tamil doorstep). Depth
comes from *tone*, not shadows; identity comes from *pattern and color*, not
decoration. One palette (Deep Navy · Live Mint · Amber), one pattern
language, both themes.

## 2. Why this direction (the "pro" reasoning)

1. **White is the absence of a decision.** Pure `#FFFFFF` cards on
   near-white background is the default look of every unstyled app. MD3's
   answer is the tonal ladder: five `surfaceContainer*` steps tinted with
   the brand hue, so hierarchy reads through *tone* instead of borders and
   shadows. Cheaper to render, calmer to look at, obviously intentional.
2. **Pattern must mean something.** Random geometric noise is wallpaper.
   A kolam dot-grid is instantly recognizable to every member in Nagercoil,
   renders beautifully at 2–4% opacity, is trivially cheap to paint
   (`CustomPainter`, `shouldRepaint: false`), and scales from a splash
   screen hero to an empty-state accent without new assets.
3. **We already own the seeds.** DSColors (navy/mint/amber) shipped in
   Sprint 1 and `AppColors` is aliased to it — the codebase comment says it
   directly: *"Change these five and every legacy screen re-skins."* This
   redesign pulls that lever instead of forking a third system.

## 3. Design tokens

### 3.1 Light theme — tonal surface ladder (navy-seeded, zero white)

| Token | Hex | Use |
|---|---|---|
| `surfaceBright`   | `#F9FAFE` | Cards, sheets (the "paper") — tinted, not white |
| `surface` (bg)    | `#F2F4FA` | Scaffold background |
| `surfaceContainerLow` | `#ECEFF7` | Inset panels, chips at rest |
| `surfaceContainer`    | `#E6EAF4` | Text-field fill, secondary panels |
| `surfaceContainerHigh`| `#E0E5F1` | Hover/pressed containers, dividers-as-areas |
| `surfaceDim`      | `#DDE1EC` | Skeletons, disabled fills |

Ink stays `navy900 #0A1128` / slate `#5B6478`. Border `#E3E7F0` is retained
but **demoted**: tone difference is the primary separator; borders only
where tone alone is ambiguous (inputs, selected states).

### 3.2 Dark theme

Already navy-black (`#080B14` / `#141A2B` / `#242B3D`) — conforms as-is.
Add the same relative container ladder: `#10162A` (low), `#171E33`
(container), `#1E2740` (high).

### 3.3 Color roles (unchanged, re-affirmed)

- **Primary** Deep Navy `#16255A` — structure, headers, nav
- **Accent** Live Mint `#14B891` — the *only* CTA color
- **Highlight** Amber `#F59E0B` — awards, live/sports moments
- **Danger** Rose `#F43F5E` — blood/SOS/destructive only
- Semantic pairs from DSColors for success/warning/info surfaces.

### 3.4 The kolam pattern

`KolamPattern` — a `CustomPainter` drawing a *pulli* (dot) grid with
quarter-circle loops around alternating dots, the simplest classical kolam
form:

- Grid: 28dp spacing; dots r=1.2dp; loops stroke 1dp.
- Opacity: **3%** ink in light theme, **4%** white in dark — texture you
  *feel* more than see. Never behind body text blocks at higher opacity.
- Painted once (`shouldRepaint => false`), no shaders, no assets — zero
  size cost, negligible raster cost.
- Exposed as `KolamBackground(child: …)` which layers pattern between the
  scaffold color and content.

Placement rules:
| Surface | Pattern? |
|---|---|
| App shell (behind all 4 tabs) | ✅ 3% |
| Aurora auth screens (dark hero) | ✅ 4%, white |
| Hero headers (Home, Feed) | ✅ inside the gradient, 6% white |
| Empty states | ✅ 5%, doubles as illustration backdrop |
| Cards / sheets / dialogs | ❌ never — paper stays clean |

### 3.5 Shape scale (MD3)

xs 8 · sm 12 · md 16 (buttons/inputs = current `radiusBtn`) · lg 20
(cards = current `radiusCard`) · xl 28 (sheets, hero cards). FAB stays
circular (SOS identity).

### 3.6 Elevation & motion

- Elevation = tone step first, shadow second. `cardShadow` kept only for
  floating layers (FAB, sheets, SOS).
- Motion: MD3 emphasized easing (`Curves.easeInOutCubicEmphasized`) for
  page/sheet transitions; existing `FadeSlideIn` stagger (45ms/item,
  400ms cap) is already conformant — keep.

## 4. Component directives (Phase 2 checklist)

1. **Buttons:** `FilledButton` (mint) = primary CTA; `FilledButton.tonal`
   (surfaceContainerHigh) = secondary; `OutlinedButton` demoted to rare
   tertiary. One primary CTA per screen.
2. **Cards:** drop `side: BorderSide(...)` from `CardThemeData`; cards sit
   on tone (`surfaceBright` on `surface`). Border only on interactive
   selection states.
3. **Chips/tabs/inputs:** rest on `surfaceContainerLow`, selected =
   primary-tonal; input fill → `surfaceContainer`.
4. **Headers:** gradient heroes (already navy `gradientAurora`) gain the
   kolam layer; flat white app bars are eliminated app-wide (they become
   `surface` with tonal scroll-under: `surfaceContainerHigh` at offset).
5. **Snackbars/dialogs/sheets:** `surfaceBright`, radius xl, no border.

## 5. Build plan

| Phase | Content | Size | Risk |
|---|---|---|---|
| **1 (this PR)** | Tonal ladder into `AppColors`/`DSColors` values (no renames — value-level reskin), `KolamPattern` + `KolamBackground` widget, wire pattern into app shell + aurora auth screens, kill pure-white `surface` | S | Low — value changes ride the existing alias lever; widget tests assert structure, not hex |
| **2** | Component sweep: CardTheme border removal, FilledButton hierarchy, chip/input tonal fills, app-bar scroll-under | M | Medium — visual QA pass needed per screen |
| **3** | Hero headers + empty states adopt pattern; motion curves; scroll-under app bars | M | Low |
| **4** | Per-screen polish sweep (Play, Serve, Me) + remove remaining `Colors.white` literals (≈ audit list) | L | Low, mechanical |

Verification per phase: `flutter analyze` + widget tests in CI; manual
screenshot pass on the 4 tabs in both themes.

## 6. Non-goals

- No new fonts (Outfit stays; per-language families remain the separate
  DSTypography follow-up already noted in `app_theme.dart`).
- No dynamic color / Material You wallpaper extraction — club brand > user
  wallpaper.
- No redesign of the aurora auth identity — it already conforms (dark,
  patterned, branded); it gains kolam, nothing else.
