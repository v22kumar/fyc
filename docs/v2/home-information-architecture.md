# V2 Home — Information Architecture

The target Home, section by section. This is the layout Phase 1 lays out and
Phases 2–3 fill with dynamic/personalized content. Order is deliberate:
**time-sensitive and personal first, evergreen and informational last.**

## Order (Citizen)

| # | Section | Source | Phase | Notes |
|---|---------|--------|-------|-------|
| 1 | **Compact header** | `AuthBloc`, hour | 1 | ~190px collapsing `SliverAppBar`: greeting · profile · notification · search only. No dead space. |
| 2 | **Floating search** | `SearchScreen` | 1 (voice/QR → 4) | Pinned, overlaps header. Recent + suggested chips already exist. |
| 3 | **Hero carousel** | `Announcement` (featured) | slot 1 / content 2 | Auto-scroll 5–6s; blood emergency, tournament, event, festival, plantation, volunteer, govt. Deep-links via CTA. |
| 4 | **Quick actions** | static routes | 1→2 | 8-tile grid: Blood, Sports, Events, Members, Education, Jobs, Complaints, Emergency. |
| 5 | **Continue where you left** | `GET /me/continue` | 3 | Draft complaint, pending reg, unfinished tournament. **Hidden when empty.** |
| 6 | **Community feed** | `/community/activities` (+ `/community/feed`) | enrich 2 | Volunteer joined, blood fulfilled, tree planted, match completed. Mini timeline. |
| 7 | **Upcoming events** | `/events` | 2 | Horizontal cards: banner, date, "N going", Register. |
| 8 | **Live sports** | `GET /sports/live` | 2 | Live matches (LIVE pulse), upcoming, results. |
| 9 | **Blood donation** | static hero | keep | Rose "Be a Hero" card. |
| 10 | **Daily news** | `NewsDataSource` | keep, collapsible 4 | 5-tab RSS. |
| 11 | **Thirukkural** | `ThirukkuralDataSource` | keep, collapsible 4 | Offline-seed. |
| 12 | **Today's info** | weather/gold (+fuel/AQI/rain 4) | 4 | Weather + Gold exist; fuel/AQI/rain new. |
| 13 | **Community stats** | `/community/stats` | 2 | Animated counters: members, volunteers, donors, trees, events, schools. |
| 14 | **Discover more** | `_MoreSheet` | keep | Full services grid. |

## Adaptive by time of day (Phase 3)

Same sections, re-weighted by hour:
- **Morning:** greeting, weather, today's events surfaced higher.
- **Midday:** live matches and community activity surfaced.
- **Evening:** news, results, tomorrow's events surfaced.

Implemented client-side from the existing hour logic in `_Header`.

## Role variants

- **Citizen:** the full order above (nearby / blood / news emphasis).
- **Volunteer:** assigned work + pending requests promoted above evergreen.
- **Manager:** analytics, pending approvals, reports promoted; then the rest.

Role is detected in `home_screen.dart` via `state.user.isAdmin` /
`state.user.isVolunteer` (existing `_ManagerDashboard` / `_VolunteerDashboard` /
`_CitizenDashboard`).

## Loading & empty states

- Loading: `DSSkeleton` blocks shaped like the real section (never a bare
  spinner or blank).
- Empty: `EmptyState` (icon path) with a friendly line + a primary action; or,
  for optional sections (continue-where-left, next-event), collapse to nothing.
- Entrance: `FadeSlideIn` staggered top-to-bottom (reduce-motion aware).
