# FYC Connect — Redesign Requirements (Living Document)

Status legend: ✅ done · 🟡 in progress · ⬜ planned

---

## 1. Premium Homepage (matches mockup) ✅
**Problem:** Old home felt like a government portal — thin content, no hierarchy.
**Why it matters:** The home screen is the first impression and the engagement hub.
**Built:**
- Dark header: logo + "FYC Connect / Welcome back!", translate/notification/profile actions
- Greeting + subtitle + glass search bar
- "Be a Hero" blood-donation hero card (custom-painted blood bag + heartbeat)
- Quick Services 4×2 grid (icon + label + sublabel) with View All
- Announcements strip
- Our Impact — 4 colour-tinted stat cards
- Upcoming Event + Latest News two-card row
- Bottom nav with elevated center **Create** FAB → create-actions sheet

---

## 2. Dark Mode (system-wide) 🟡
**Problem:** Mockups show both light & dark; app was light-only with hardcoded colours.
**Why it matters:** Dark mode is table-stakes for a modern app; reduces eye strain; matches Chess.com feel.
**Approach (non-breaking):**
- Keep existing `AppColors.*` light constants intact (no const breakage).
- Add dark constants: `darkBackground`, `darkCard`, `darkBorder`, `darkText`, `darkTextSecondary`.
- Add `AppTheme.dark` `ThemeData` (Material components adapt automatically).
- Add `extension AppColorsX on BuildContext` → theme-aware getters:
  `cBackground, cSurface, cText, cTextSecondary, cBorder`.
- `themeModeNotifier` (ValueNotifier<ThemeMode>) persisted in `LocalStorage`.
- Wire `darkTheme` + `themeMode` into `MaterialApp.router`.
**Scope:**
- ✅ Infrastructure + persistence + toggle
- ✅ Home screen fully theme-aware (both mockups)
- ⬜ Per-screen polish for: blood, opportunities, events, directory, green, sports, membership (Material defaults adapt; hardcoded surfaces need conversion to `context.cX`)

---

## 3. Settings Screen ⬜→✅
**Problem:** No place to change theme/language; toggle lived only as a header icon.
**Why it matters:** Users expect a Settings hub; needed to host the dark-mode switch.
**Built:**
- New `/settings` route + screen.
- Sections: Appearance (Light/Dark/System), Language (Tamil/English/Hindi/Malayalam),
  Account (profile placeholder), About, App version, Logout.
- Reached from More sheet + profile avatar.

---

## 4. Re-surface Daily Content ✅
**Problem:** Weather, Gold Price, Thirukkural, News removed from home in mockup pass.
**Why it matters:** These are genuinely useful daily-open drivers.
**Built:** "Today" section at the bottom of home re-introducing all four cards,
below Upcoming/News, clearly separated by a section header.

---

## 5. Engagement & Trust (carried from audit) ⬜
- Push-notification triggers (blood urgent, chess match, birthdays) — FCM already wired.
- Verified-donor badge ✅ (done earlier).
- Empty states everywhere ✅ (done earlier).
- Pull-to-refresh ✅ (done earlier).
- Skeleton loaders / cached images ✅ (CachedImage + offline banner done earlier).

---

## 6. Language Parity ✅
Tamil + English + Hindi + Malayalam (103 strings each); letter-based language icons.

---

## Build Order (this iteration)
1. ✅ Requirements doc (this file)
2. 🟡 Theme infrastructure (AppTheme.dark, context colour extension, themeModeNotifier, persistence, MaterialApp wiring)
3. 🟡 Home screen → theme-aware + "Today" section
4. 🟡 Settings screen + route + More-sheet/profile entry
5. ⬜ Background agent: convert remaining high-traffic screens to `context.cX`
