<!--
Restored to the repo from the original v2.0 planning document (previously only
referenced by HANDOFF_ANTIGRAVITY.md, never committed). Reconstructed from the
source screenshots; a few right-edge line endings were completed faithfully
from context. This is a living plan — update after each sprint's review.
-->

# FYC Connect v2.0 — Delivery Plan (10 Sprints × 15 days × 5 Developers)

**Design system:** Deep Navy + Mint + Amber · **Platforms:** Android (primary)
**Philosophy:** Community First • Productive • Simple • Human — "if a villager can't use it, it isn't done."

This plan takes the v2.0 UI/UX Specification and turns it into a sequenced,
staffed, testable build. It is written to be handed directly to a build team.

---

## 0. How this plan improves the spec (read first)

The UI/UX spec is excellent on *look and structure* but silent on the things
that decide whether FYC Connect actually works for its users. This plan adds a
foundation layer and re-sequences so features are built once, not twice.

1. **Foundations before features.** A design system + an offline/performance
   core are built in Sprints 1–3, *before* feature screens, so no screen is
   built twice. Building features first on a green/gold codebase and an old
   navy/mint system would mean rebuilding everything.
2. **Village-reality engineering** (missing from the spec, non-negotiable):
   quality tiers, **offline-first reads**, an **idempotent write outbox**,
   **adaptive images / Lite mode**, and **push instead of polling**. Without
   these, a premium UI is useless on 2G with a dying battery.
3. **Own records, rent media.** The feed *displays* FYC's Instagram/Threads
   presence and stores no heavy media — the app DB stays tiny and fast on
   low-storage phones.
4. **Safety sequenced early.** SOS lands as soon as its dependencies (push,
   offline/SMS) exist (Sprint 6), not as a late add-on.
5. **Vertical slices.** Every sprint ships something a user can open and use,
   not a horizontal layer that only pays off at the end.
6. **Builds on existing code.** Much of this is *redesign + harden* (cricket
   scoring, feed, events, tournaments already exist), not build-from-zero,
   which de-risks the timeline. Each sprint notes "new" vs "reskin/harden".
7. **Go-live hygiene is scheduled, not hoped for**: secret rotation, moderation,
   Play Store readiness, monitoring — explicit stories, not an afterthought.

**Navigation confirmed:** 4 bottom tabs — **Home · Play · Serve · Me**. No
Community tab (community lives inside Home). SOS is a persistent control /
screen, never a tab.

---

## 1. Team (5 developers)

| ID | Role | Primary focus |
|----|------|---------------|
| **D1** | Flutter Lead / Architect | Design system, navigation shell, architecture |
| **D2** | Flutter Engineer | Feature screens (Home, Play, Feed) |
| **D3** | Flutter Engineer | Feature screens (Serve, Me, SOS, Notifications) |
| **D4** | Backend Engineer (FastAPI) | APIs, data model, integrations |
| **D5** | Full-stack / QA / DevOps | Backend support, test automation, DevOps |

**Design:** a part-time designer (or D1) maintains the Figma component library;
validates screens against the spec. **Admin web** is maintained by D4/D5.

## 2. Working agreements

- **Sprint length:** 15 working days. Day 1 planning, Day 15 review + retro.
- **Definition of Done:** merged to main · behind a feature flag if risky.
- **No dead ends:** every list has an empty state with a primary action.
- **Every screen answers:** *What's happening? What can I do? What needs me?*
- **Flag** anything that can't ship this sprint rather than half-shipping it.

## 3. Cross-cutting standards (apply every sprint)

- **Design tokens:** Deep Navy (headers/nav/icons), Mint (primary actions), Amber (highlights).
- **Type:** Plus Jakarta Sans + Noto Sans Tamil; nothing below 14sp; fixed hierarchy.
- **Motion:** 200ms; card lift, ripple, page fade, hero transition. Nothing gratuitous.
- **Engineering:** offline-first read where sensible; idempotent writes; 4-language i18n.

---

## SPRINT 1 — Design System & Foundations
**Goal:** A production component library + tokens in the new Navy/Mint system.

- **D1:** Theme + tokens (colors, type, spacing, radius, elevation); light/dark.
- **D2:** Core components — Buttons (filled/outlined/tonal/text/danger), inputs.
- **D3:** Chips (status/sport/blood-group/category/role), Badges (live/upcoming/…).
- **D4:** API contract audit; enable gzip + ETag/304 on list endpoints.
- **D5:** CI/CD hardening; widget-test harness + golden tests for the components.
- **New logo:** kick off exploration (Tamil-name mark / concrete symbol).

**Deliverables:** component gallery screen; tokenized theme; empty/loading/error states.
**Acceptance:** every component renders in light/dark + 4 languages + accessible.

## SPRINT 2 — Navigation Shell + Home + Universal Search
**Goal:** The app's spine — the 4-tab shell and a Home that answers "what's happening."

- **D1:** Finalize routing/IA migration; bottom nav; persistent SOS control.
- **D2:** Home screen per spec — Greeting, stat cards, bento grid, upcoming events.
- **D3:** Services drawer/screen (the overflow of features that don't belong in tabs).
- **D4:** **Universal Search** backend (members/events/sports/issues/blood/…).
- **D5:** Search UI + recent/suggested; instrumentation/analytics baseline.

**Deliverables:** shippable shell + Home + one search across everything.
**Acceptance:** every existing feature reachable in ≤2 taps from its bucket.

## SPRINT 3 — Offline & Performance Core (the village layer)
**Goal:** Make it fast and usable on 2G, low battery, low storage. Invisible but vital.

- **D1:** Device profile — Full/Balanced/Lite/Offline tiers exposed app-wide; Lite-mode toggle in Settings.
- **D2:** Local cache (Drift/Hive) + **offline-first reads** for Home/Feed/Events.
- **D3:** **Write outbox** foundation (queue + retry + client-generated idempotent IDs).
- **D4:** **FCM push fully live** (provision Firebase service-account key).
- **D5:** **Adaptive image pipeline** (Cloudinary sizes/WebP; thumbnail on Lite).

**Deliverables:** app opens instantly from cache; pushes replace polling.
**Acceptance:** cold Home render < 1s from cache on 2G; battery drain measured.

## SPRINT 4 — Community Feed (display + create + moderation)
**Goal:** Community lives inside Home; display-only over FYC's social presence.

- **D2:** Feed UI (tabs: All/Club/Sports/Green/Events/My Posts); post cards.
- **D3:** Create Post (Photo/Video/Poll/Event/Tournament/Volunteer quick-actions).
- **D4:** **Own records, rent media** — feed references, stores no blobs.
- **D1:** Media upload/compress pipeline hooked to adaptive images; video handling.
- **D5:** **Moderation** — report post, admin hide/delete, block user.

**Deliverables:** a real, moderated community feed that stores no heavy media.
**Acceptance:** feed works in Lite tier (thumbnails, no autoplay); a report reaches admin.

## SPRINT 5 — Play (Sports + Weekly Member Games)
**Goal:** Weekly engagement — reskin tournaments and **open scoring to any member.**

- **D2:** Play tab (Today's Match, live scores, tournaments).
- **D3:** **Weekly member-created games** — any member creates a casual game.
- **D4:** Harden scoring APIs; member-game data model; leaderboards.
- **D1:** Chess arena integrated into Play; live-score realtime via WebSocket.
- **D5:** Load-test concurrent live scoring; regression suite for the full flow.

**Deliverables:** Play tab where members run their own weekly games end-to-end.
**Acceptance:** a member creates + scores a game offline, and it syncs correctly.

## SPRINT 6 — Serve + SOS + Incident Alerts (help & safety)
**Goal:** The "do good / get help" bucket, plus the safety features that matter most.

- **D3:** **SOS** — persistent control everywhere; hold-3s/shake trigger.
- **D2:** Serve tab — Blood (emergency banner, nearby donors, call/WhatsApp).
- **D4:** SOS backend (trusted contacts, dispatch to nearby members, SMS).
- **D1:** Issue-reporting timeline (Reported → In Progress → Resolved).
- **D5:** SOS reliability testing (airplane mode, no-data, low battery).

**Deliverables:** working SOS + incident alerts + a complete Serve bucket.
**Acceptance:** SOS fires with location on a device with **mobile data only / off.**

## SPRINT 7 — Me + Journey + Membership + Notifications
**Goal:** Identity, belonging, and a notification system that respects attention.

- **D3:** Me tab + Member Profile (cover/photo/name/role/QR card/member-since).
- **D2:** **Journey** — rewarding, not statistics (volunteer hours, blood, milestones).
- **D4:** Membership card + **QR** (foundation for offline attendance scan).
- **D1:** **Notifications inbox** — grouped (Today/Yesterday/Earlier), swipeable.
- **D5:** Notification delivery/read-state backend; analytics on engagement.

**Deliverables:** a profile people feel proud of + a respectful notification system.
**Acceptance:** notifications grouped + swipeable; account deletion works.

## SPRINT 8 — WhatsApp Reach + Events depth + Personalization
**Goal:** Meet people where they already are, and make Home feel personal.

- **D4:** **WhatsApp as the reach layer** — one-tap broadcast of events/alerts.
- **D2:** Events depth — hero, countdown, registration limit + closing.
- **D3:** Personalized Home (relevance ranking: your sports, your area's events).
- **D1:** Progressive disclosure pass across heavy screens (Important first).
- **D5:** Delivery reliability (push+WhatsApp), rate-limit/opt-out handling.

**Deliverables:** the app becomes the record feeding WhatsApp; richer events.
**Acceptance:** creating an event notifies via in-app + push + WhatsApp.

## SPRINT 9 — Hardening: Security, Accessibility, Performance, QA
**Goal:** Make it safe, inclusive, and reliable. No new features.

- **D4/D5:** **Security** — rotate/remove hard-coded secrets (OTP bypass, admin default).
- **D5:** Re-enable **R8/resource shrinking**; release signing; crash reporting.
- **D1:** **Accessibility** — 48dp targets, contrast, large fonts, screen readers.
- **D2/D3:** Bug bash from beta feedback; empty/loading/error audit across screens.
- **All:** load-test for event day (`backend/loadtest/`); performance budgets.

**Deliverables:** a secure, accessible, resilient v2.0 release candidate.
**Acceptance:** no hard-coded secrets; a11y checklist green; app usable on low-end devices.

## SPRINT 10 — Beta + Launch
**Goal:** Real villagers, then ship.

- **All:** Closed beta with real Nagercoil/Munchirai members + volunteers.
- **D5:** Play Store + iOS submission; store listing (Tamil + English); phased rollout.
- **D4:** Final integration checks (FCM, WhatsApp, Instagram, SMS) in prod.
- **D1/D2/D3:** Launch polish, onboarding (first-run, WhatsApp-familiar patterns).

**Deliverables:** FYC Connect v2.0 live, monitored, and rolling out via beta cohort.
**Acceptance:** beta cohort completes core journeys (see a game, report an issue, donate, RSVP).

---

## 4. Sequencing rationale (dependency spine)

```
S1 Design system ┐
S2 Shell + Home  ─┼─→ S4 Feed ──→ S5 Play ──→ S6 Serve+SOS ──→ S7 Me ──→ S8
S3 Offline/Perf  ┘         (every feature sprint rides on S1–S3)
```

Foundations (S1–S3) unblock everything; features (S4–S8) are vertical slices on
that base; S9–S10 harden and ship. SOS (S6) waits only for push+offline.

## 5. Risk register (top 5)

| Risk | Mitigation |
|------|-----------|
| Offline/outbox correctness (double-scored balls) | Idempotency ids + server-side dedupe |
| Instagram pull depends on Meta tokens | Graceful fallback to in-app posts |
| SOS reliability on no-data | SMS fallback + airplane-mode testing in S6 |
| Scope creep from "it helps the community" | Every story passes the *product question* |
| SQLite concurrency at events | Postgres decision gate in S9; load-test first |

## 6. Parking lot / explicitly NOT building

Volunteer certificates · monsoon/flood coordination · anything only tech-
impressive · anything a volunteer-run org can't operate. Revisit only if a real
user need appears.

---

*Cadence: 10 sprints × 15 working days ≈ 30 weeks with 5 developers. Adjust scope
per sprint at planning; protect S1–S3 (the foundation) from being cut — everything
above them depends on it.*

---

## 7. Mockup compliance audit (v2.0 UI) — ✅ done / ⬜ pending

Point-by-point against the v2.0 requirements mockup. ✅ shipped to `main`;
⬜ pending; 🟡 partial.

### Home
- ✅ Header: logo + "FYC CONNECT" + tagline, notification bell (badge), avatar
- ✅ Tamil greeting + subtitle
- ✅ Search bar (→ Universal Search)
- ✅ 4 stat cards: Members · Blood Donors · Events · Tournaments
- ✅ Important Update strip
- ✅ Discover bento (Home · Play · Feed · Serve) with sub-items
- ✅ Upcoming Events row
- ✅ Bottom nav (Home · Play · + · Serve · Me)
- ✅ **Quick Actions row** — Blood Request · Report Issue · Create Event · Weekly Game · Emergency Contacts (5 shortcut tiles)

### Feed · Community
- 🟡 Feed screen exists (threads-style + Instagram cross-post from earlier work)
- ✅ **Source tabs** (option c): All · Instagram · Threads · Green FYC · **Activity** — social posts filtered by source, plus an Activity tab showing the community activity feed (events/tournaments/issues/green). Backend `/posts?source=` filter added.
- 🟡 **Green FYC** tab filters by category `Green` (graceful-empty until green posts are tagged)
- 🟡 **Post card parity**: verify source badge/handle/timestamp, media grid, counts vs mockup

### Play
- ✅ Chess Arena entry + Tournaments reachable (pill), auto-scoring, SF/final app-or-in-person
- ⬜ **Tab bar**: All · Tournaments · Weekly Games · Chess (current shows sport filters instead)
- ⬜ **Weekly Member Games** — the "Sunday Match · Any Members" live card (organizer, LIVE badge, live score) + create/score flow — not built (large feature)
- 🟡 Upcoming Tournaments card (Registration Open, reg-closes date, trophy) — exists but not styled to mockup

### Serve / Help
- ✅ 4-icon row: Blood Donation · Report Issue · Volunteer · Opportunities
- ✅ Emergency Numbers (Police 100 · Ambulance 108 · Fire 101 · Electricity 1912) + View All — matches mockup

### Report an Issue
- ✅ Category chips, Use My Location, Description, Add Photo, Submit
- 🟡 **Categories**: has Road/Water (+others) — align to mockup set (Road/Traffic · Power Cut · Water · Other)

### Me
- ✅ Profile + QR card and list (My Profile · Membership Card · Member Directory · My Event Registrations · Settings · Help & Support)
- ✅ Card fields to mockup: **Member ID · Member Since · Valid Till** (fetched from the membership card; QR uses the card payload)

### Safety Center / SOS
- ✅ SOS trigger, Share Live Location (SMS), Alert Trusted Contacts, offline SMS fallback, emergency dial
- ⬜ **Notify Nearby Members** (broadcast alert to nearby FYC members)
- ⬜ **Loud Siren / Silent Mode** toggle
- ⬜ Branded **Safety Center** panel (feature list UI) + **Safety Settings** screen

### Priority order for the remaining pending items
1. ~~Home Quick Actions row~~ ✅ · ~~Me card fields~~ ✅
2. Feed **source tabs** + card parity (Sprint 4)
3. Play **tab bar** + **Weekly Member Games** (Sprint 5 — the big one)
4. **Safety Center** — Notify Nearby + Siren/Silent + settings (Sprint 6 depth)
5. Report Issue — align category set (Power Cut / Traffic / Other)
