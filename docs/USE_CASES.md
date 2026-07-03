# FYC Connect — Use Cases & Test Matrix

Full inventory of what the Android app must do, for every role, with the test
method and current status. Compiled during the end-to-end QA pass (July 2026).

Roles: **Guest** (not logged in) · **Citizen** (PUBLIC_CITIZEN) · **Volunteer** ·
**Member** (CLUB_MEMBER) · **Manager** (EXECUTIVE_MEMBER) · **Admin** (ADMIN / SUPER_ADMIN)

Status legend: ✅ verified working · 🔧 was broken, fixed in this pass · ⚠️ known limitation

---

## 1. Authentication & Account

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| A1 | Login with phone + OTP | All | Backend journey test (`/auth/otp/send` → `/auth/otp/verify`) | ✅ |
| A2 | Login with username + password (admin bootstrap) | Admin | Backend journey test (`/auth/login/password`) | ✅ |
| A3 | Login with Google | All | Endpoint contract check; live-tested earlier (#56) | ✅ |
| A4 | Register new account | Guest | Backend journey test | ✅ |
| A5 | Logout clears session **and Google account picker** | All | Fixed & shipped in #56 | ✅ |
| A6 | Switch to a different account after logout | All | Fixed in #56 (Google session cleared before sign-in) | ✅ |
| A7 | View/edit own profile | All logged in | `/users/me/profile` journey test | ✅ |

## 2. Home & Dashboards

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| H1 | Home hub with activity shortcuts | All | UI review; shipped #43 | ✅ |
| H2 | Daily Thirukkural, news, weather, gold price cards | All | Backend endpoints journey-tested | ✅ |
| H3 | Volunteer dashboard "Today's Activities" card opens Green FYC | Volunteer | Dead-button audit — "View all" did nothing | 🔧 wired to `/green` |
| H4 | Manager dashboard "Pending Items" card | Manager | Dead-button audit — hardcoded fake "3 New Approvals", tap did nothing | 🔧 now opens Sports (team approvals) with honest copy |
| H5 | Manager dashboard "Registrations" card | Manager | Fake "12 New Members" count | 🔧 honest copy, opens Community |
| H6 | Manager "Recent Reports" card | Manager | Fake "Street Light Broken" placeholder | 🔧 honest copy, opens issue tracker |

## 3. Blood Donors

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| B1 | Search donors by blood group / taluk | All | Journey test (4,677 seeded donors) | ✅ |
| B2 | Register as donor | Logged in | Journey test | ✅ |

## 4. Issues (citizen reports)

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| I1 | Submit issue (category, description, photo, location) | Logged in | Journey test; blank-description guard verified | ✅ |
| I2 | Track submitted issues | Logged in | Journey test | ✅ |
| I3 | "Not sure? See examples" link on category picker | Logged in | Dead-button audit — tap did nothing | 🔧 opens category-examples sheet |
| I4 | Issue stats row (resolved %, response time) | All | `/issues/stats` journey test | ✅ |

## 5. Events, Announcements, Gallery, Directory, Community

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| E1 | Browse events / RSVP | All / Logged in | Journey test | ✅ |
| E2 | Announcements list | All | Journey test | ✅ |
| E3 | Gallery albums | All | Journey test + asset audit | ✅ |
| E4 | Member directory | Logged in | Journey test | ✅ |
| E5 | Community feed (posts) | Logged in | Journey test | ✅ |

## 6. Membership & Volunteering

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| M1 | Digital membership card | Member+ | `/membership/my-card` journey test | ✅ |
| M2 | Volunteer certificate | Volunteer+ | `/volunteers/my-certificate` journey test | ✅ |
| M3 | Green FYC stats / drives / tree registry | All | Journey tests | ✅ |
| M4 | Opportunities board | All | Journey test | ✅ |

## 7. Sports Tournaments (cricket / kabaddi / volleyball)

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| S1 | Browse tournaments by sport | All | Journey test | ✅ |
| S2 | View tournament detail: teams, fixtures, standings | All | Fixed in #61 (was empty on Android) | ✅ |
| S3 | Register a team | Logged in | Journey test | ✅ |
| S4 | Approve/reject teams | Manager+ | Journey test (PATCH team status) | ✅ |
| S5 | Generate round-robin fixtures (needs ≥2 approved teams) | Manager+ | Journey test | ✅ |
| S6 | Kabaddi/volleyball score entry (live-entry, approval flow) | Member+ | Journey test | ✅ |
| S7 | **Cricket: initialise match (toss, overs, openers)** | Manager+ | Scripted full-lifecycle test | 🔧 backend 500'd (missing organization_id) — fixed; mobile had no init UI — rebuilt |
| S8 | **Cricket: ball-by-ball scoring (runs, 4s/6s, extras, wickets)** | Manager+ | Scripted test: 6-ball over incl. wicket + new batter | 🔧 was unusable (operator had to type player UUIDs); now fully guided |
| S9 | Cricket: strike rotation + end-of-over bowler picker | Manager+ | Cubit logic + scripted backend test | 🔧 built |
| S10 | Cricket: undo last ball (also reverts innings-break/completion) | Manager+ | Scripted test | 🔧 backend kept stale status — fixed |
| S11 | Cricket: innings break → start 2nd innings with target | Manager+ | Scripted test (target = score+1 verified) | 🔧 built end-to-end |
| S12 | Cricket: completed match → correct winner on fixture | Manager+ | Scripted chase test | 🔧 backend awarded the **bowling** side on a successful chase — fixed |
| S13 | Cricket: resume scoring after app restart (confirm players) | Manager+ | UI flow (squad fetched from team players API) | 🔧 built |
| S14 | Cricket URLs (mobile ↔ backend) | — | API-contract audit | 🔧 mobile called `/sports/fixtures/...`, backend mounts `/fixtures/...` — every call 404'd; fixed |

## 8. FYC Chess Arena

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| C1 | Play online chess vs member (WebSocket) | Logged in | Live-tested earlier; load-tested (#64) | ✅ |
| C2 | Challenges (send / accept) | Logged in | Journey test | ✅ |
| C3 | Spectate live games | All | Endpoint contract check | ✅ |
| C4 | Chess knockout tournaments: register until close date | Logged in | Full-loop scripted test (#62) | ✅ |
| C5 | Admin starts tournament → bracket with byes | Admin | Scripted test (5 players → 8-slot bracket) | ✅ |
| C6 | Play tournament match in Arena; result advances bracket | Logged in | Scripted test (white_wins → next round) | ✅ |
| C7 | Draw stays LIVE for admin decider; final can be physical | Admin | Scripted test | ✅ |
| C8 | Dead "Bonus!" button on chess home | — | Dead-button audit | 🔧 removed (no backing feature) |
| C9 | 25 simultaneous games / 50 users | — | Hardened in #64 (single worker + WAL + 1GB RAM); loadtest script in `backend/loadtest/` | ✅ run from laptop before event day |

## 9. Settings, Updates & Localisation

| # | Use case | Roles | How tested | Status |
|---|----------|-------|-----------|--------|
| U1 | Mandatory in-app update (download + install + cleanup) | All | Shipped #50/#52; version.json on GitHub release is source of truth | ✅ |
| U2 | Check for updates manually | All | Live-tested | ✅ |
| U3 | Language switch en/ta/hi/ml — every screen localised | All | 31 screens swept (#58–#60); crash fixed (#57) | ✅ |
| U4 | Theme switch | All | UI review | ✅ |
| U5 | Privacy & Security row | All | Dead-button audit — did nothing | 🔧 opens privacy sheet (en/ta) |
| U6 | About page | All | UI review | ✅ |

## 10. Cross-cutting technical checks (this QA pass)

| Check | Method | Result |
|-------|--------|--------|
| All mobile routes resolve | Route-integrity parse of `app_router.dart` | ✅ no dead routes |
| Mobile API paths ↔ backend routes | Contract diff (82 mobile paths vs 157 backend routes) | 🔧 only cricket paths mismatched — fixed |
| All referenced assets exist | Asset audit | ✅ |
| Dead buttons | `onTap: () {}` grep + manual review | 🔧 6 fixed (sections above) |
| 28-endpoint journey smoke (all features, real auth) | `TestClient` with lifespan + seeded org/admin | ✅ 28/28 pass |
| Cricket scoring lifecycle | Direct-router scripted test (init → over → wicket → break → undo → 2nd innings → chase → winner) | ✅ all pass after fixes |
| Concurrency (SQLite WAL) | 10×50 concurrent inserts | ✅ 0 errors |

---

## Manual test script for event day (run on a real phone)

1. **Update**: open app → must prompt for the new version → install → old APK auto-removed.
2. **Cricket**: Admin creates a cricket tournament (web or app) → two teams register in-app → manager approves both → generate fixtures → open fixture → *Start match* (toss, overs, openers) → score one over incl. a boundary, a wide and a wicket → check strike rotation and bowler prompt at over end → finish innings → start 2nd innings → complete the chase → fixture shows the right winner in the fixtures list.
3. **Chess tournament**: create with registration close date → 3+ members register → admin starts → both players open the match and play in Arena → bracket advances → champion shown.
4. **Languages**: switch to Tamil, Hindi, Malayalam — home, sports, cricket scorer, chess and settings must all render translated.
5. **Resume**: kill the app mid-cricket-over → reopen → scorer asks to confirm players → continue scoring.
