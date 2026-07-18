# FYC Connect — Version 2

> From a **dashboard of components** to a **living, personalized community platform.**

V2 is a deliberate, phased upgrade centred on a real Home redesign, then dynamic
content, personalization, and delight. This folder is the **single source of
truth** for the effort — follow it top to bottom and there is no guesswork.

- **[development-flow.md](./development-flow.md)** — how we ship (branch, PR, CI, cadence).
- **[definition-of-done.md](./definition-of-done.md)** — the checklist every slice must pass.
- **[home-information-architecture.md](./home-information-architecture.md)** — the target Home, section by section.
- **[api-contracts.md](./api-contracts.md)** — endpoints V2 consumes and the new ones it adds.

## Track

- Branch: **`claude/v2-redesign`** (fresh from `main`, independent of the V1
  readiness branch). No V2 work lands on the readiness branch.
- Cadence: **one slice → one PR → CI-gated → squash-merge**, then the next.

## Guiding principle — build with maturity

Reuse the widgets and endpoints we already have (see the reuse map below) before
writing anything new. Token discipline, theme + 4-language correctness, and a
test per component/endpoint are defaults, not afterthoughts.

## Reuse map (enhance, don't rebuild)

| Need | Already exists | Where |
|------|----------------|-------|
| Home stats / feed / next-event | live endpoints wired | `GET /community/stats`, `/community/feed`, `/events` |
| Hero carousel data | `Announcement` (`banner_url`, `is_pinned`, `category`, `expires_at`) | `backend/app/routers/announcements.py` |
| Activity timeline | built but **dormant** — wire it | `CommunityActivity` + `ActivityEngine` (`services/activity_engine.py`) |
| Search | `SearchScreen` + `/search` (+ recent, chips) | `mobile/lib/features/search/…/search_screen.dart` |
| Cards / chips / badges / skeletons | design system | `mobile/lib/core/design_system/components/*` (`DSFeatureCard`, `DSCard`, `DSChip`, `DSBadge` w/ LIVE pulse, `DSSkeleton`) |
| Entrance motion (reduce-motion aware) | `FadeSlideIn` | `mobile/lib/core/widgets/entrance.dart` |
| Image caching + Cloudinary tiering | `CachedImage` | `mobile/lib/core/widgets/cached_image.dart` |
| Premium texture | `KolamBackground` | `mobile/lib/core/design_system/patterns/kolam_background.dart` |

**Genuinely new:** compact collapsing header, hero carousel widget, animated
counters, cross-tournament live endpoint, continue-where-you-left, recommendation
engine, voice/QR search, unified token system.

## Phased roadmap

Tick each box as the slice merges. Each line is one PR unless noted.

### Phase 0 — Foundations
- [x] 0.1 `docs/v2/` scaffold (this folder)
- [x] 0.2 Shared primitives: `DSAnimatedCounter`, `DSCarousel`, `DSCollapsibleSection`, `DSSectionHeader`, `LastUpdatedPill`, `Haptics` (+ tests)
- [x] 0.3 Token unification (`DSColors` ↔ `AppColors`, reconcile `radiusCard`)

### Phase 1 — Home structure & hierarchy (flagship)
- [x] 1.1 Compact collapsing header (~190px) + `ListView`→`CustomScrollView`
- [x] 1.2 Pinned floating search overlapping the header → `SearchScreen` (delivered by 1.1 — search pill is the pinned SliverAppBar bottom)
- [x] 1.3 Recommended section order (see IA doc)
- [x] 1.4 `FadeSlideIn` stagger + `DSSkeleton` on all sections + `EmptyState` icon path
- [ ] 1.5 Animated stat counters (`_TodayImpactHub` / `_ImpactStats`)
- [ ] 1.6 Pull-to-refresh with real last-updated timestamp
- [ ] 1.7 Remove dead code (`_UpcomingAndNews`, in-file `_SearchSheet`)

### Phase 2 — Dynamic content (existing data)
- [ ] 2.1 Hero carousel — backend (`Announcement` featured/CTA + enum) + `DSCarousel`
- [ ] 2.2 Live sports strip — `GET /sports/live` aggregate + Home widget (closes V1 task #31)
- [ ] 2.3 Upcoming events — horizontal cards from `/events`
- [ ] 2.4 Community activity — wire `ActivityEngine` + `GET /community/activities`
- [ ] 2.5 Community stats — add `total_members`, `total_schools` (+ cache)
- [ ] 2.6 Quick-actions 8-tile grid

### Phase 3 — Personalization & adaptivity
- [ ] 3.1 Continue where you left — `GET /me/continue` + section (hides when empty)
- [ ] 3.2 Adaptive-by-time-of-day ordering
- [ ] 3.3 Smart recommendations — service + `GET /me/recommendations` + cards
- [ ] 3.4 Personalized role dashboards enrichment
- [ ] 3.5 Universal search — add jobs/schools branches + filters

### Phase 4 — Delight, accessibility, performance, extras
- [ ] 4.1 Accessibility — `Semantics`, `Haptics`, dynamic type, touch targets, contrast
- [ ] 4.2 Micro-interactions + confetti for achievements
- [ ] 4.3 Voice + QR search (`speech_to_text`, `mobile_scanner`)
- [ ] 4.4 Today's info — fuel price, AQI, rain alert
- [ ] 4.5 Bottom-nav badges (Feed/Notifications)
- [ ] 4.6 Context-aware FAB
- [ ] 4.7 Collapsible daily cards
- [ ] 4.8 Performance — lazy slivers, `precacheImage`, pagination, rebuild minimization

## Out of scope (tracked, not dropped)
- Chess Unicode piece glyphs stay (game data, not decoration).
- POCO/Xiaomi install-failure — device/signature issue, owner: user.
