# FYC Community Prestige Network — 10-Sprint Build Plan (0 → 100)

> Companion to `06_community_prestige_network.md`.
> This is the execution plan: 10 sprints, two weeks each (~20 weeks / 5 months).
> Each sprint has a **theme**, a **shippable outcome**, concrete **work items**, an
> **exit demo** (the one thing you show to prove it's done), and a **% complete** marker.
>
> Rule for every sprint: **ship something a member can feel.** No sprint ends with
> "backend only, nothing visible." Internal plumbing always lands paired with one
> member-facing moment.

---

## Sprint Map at a Glance

| Sprint | % | Theme | Member feels… |
|--------|---|-------|---------------|
| 0 | 0→10 | Foundation & Game Truth | "My games are recorded and counted." |
| 1 | 10→20 | Ratings & Reputation Graph | "The system knows who I am — six ways." |
| 2 | 20→30 | Prestige Titles | "I have a title. It means something." |
| 3 | 30→45 | Rivalry Engine | "My rivalry has a name and a story." |
| 4 | 45→55 | Weekly Recognition | "Every Friday, someone gets named. It could be me." |
| 5 | 55→65 | Daily Spotlight + Tamil Voice | "I got spotlighted. I sent it to my family." |
| 6 | 65→75 | Digital Legacy | "My whole journey is here. I can show it." |
| 7 | 75→85 | Village Pride & Area Wars | "Marthandam is my team. We're closing the gap." |
| 8 | 85→95 | Community Prestige Loops | "I don't play much, but I'm a known mentor." |
| 9 | 95→100 | AI Legends & Polish | "Legend Rajan is still here. I challenged him." |

---

## Sprint 0 — Foundation & Game Truth  (0 → 10%)

**Goal:** Every chess game produces clean, trustworthy data. Nothing downstream can be
built on bad records, so this comes first and is non-negotiable.

**Work items**
- [ ] `games` table: players, result, started/ended timestamps, duration, area snapshot, witness list
- [ ] Game result submission flow (server-authoritative; both players confirm or admin records)
- [ ] Anti-cheat baseline: verified-membership requirement, duplicate-result guard, result dispute flag
- [ ] Member registration captures **area/village** (required) and optional **mentor link**
- [ ] Move/result audit log (immutable) for later narrative + dispute resolution
- [ ] Seed script + 50 fake games for downstream dev/testing

**Exit demo:** Play (or record) a game → it appears in both players' game history with correct
result, duration, and area. Try to submit a duplicate → rejected.

**Definition of done:** every game creates records the prestige system can reason about.

---

## Sprint 1 — Ratings & Reputation Graph  (10 → 20%)

**Goal:** Turn raw games into the six-dimension picture of a member.

**Work items**
- [ ] `reputation_events` table (append-only) + computation service
- [ ] Glicko-2 rating job (runs after each game) → feeds **Skill**
- [ ] Trust (completion/no-ghost rate), Consistency (activity over time) from game data
- [ ] Contribution, Leadership seeded at 0 (filled by later sprints) — schema ready now
- [ ] Reputation = weekly recompute job from events; cached in Redis
- [ ] **Hexagonal radar** widget on profile (shape, not numbers, for others)

**Exit demo:** Open any active member's profile → see their reputation hexagon, and their
Skill dimension visibly moves after a few games.

**Definition of done:** every active member has a visible reputation shape backed by real data.

---

## Sprint 2 — Prestige Titles  (20 → 30%)

**Goal:** The public identity layer. Titles, not points.

**Work items**
- [ ] `prestige_titles` table + `prestige_engine.py` eligibility scoring (multi-signal)
- [ ] Community Council review queue in admin panel (algorithm proposes, humans confirm)
- [ ] Award flow: title stored, `is_current` flip, history preserved (titles only go forward)
- [ ] Title rendered on: game result cards, profile header, match-up screens ("Club Champion X vs Area Star Y")
- [ ] Title timeline on profile ("Rising Talent → Area Star")
- [ ] Notification: "The Community Council has recognized you as [Title]."

**Exit demo:** Admin promotes a member in the council queue → their title updates everywhere,
old title preserved in timeline, member gets the notification.

**Definition of done:** every active member has a title; promotions flow through human confirmation.

---

## Sprint 3 — Rivalry Engine  (30 → 45%)  ⭐ biggest emotional payoff

**Goal:** The heart of the product. Rivalries that are discovered, named, and narrated.

**Work items**
- [ ] `rivalries` + `rivalry_moments` tables
- [ ] `rivalry_engine.py`: detect conditions (volume ≥20, win-rate 40–60%, drama, recency)
- [ ] Auto-create Rivalry Card on threshold; auto-name it
- [ ] Moment capture per game: upset / comeback / streak-ender / marathon + witness count
- [ ] Claude narrative generation (Tamil + English), refreshed after each rival game (batched, off hot path)
- [ ] Rivalry Card page: head-to-head, narrative, biggest moment, "Challenge" CTA
- [ ] Shareable Rivalry Card PNG export
- [ ] Notifications: gap closing, streak, inactivity, challenge

**Exit demo:** Two seeded players cross 20 games → a named Rivalry Card appears with a real
AI-written story, biggest-moment highlight, and a share button that exports an image.

**Definition of done:** every 20+ competitive-game pair has a named rivalry with a living story.

---

## Sprint 4 — Weekly Recognition  (45 → 55%)

**Goal:** The Friday ritual. Seven named awards, story-based, shareable.

**Work items**
- [ ] `recognition_awards` table + `recognition_engine.py` nomination logic for all 7 awards
- [ ] Admin/council confirm-or-override interface
- [ ] Claude writes each award's story (Tamil + English)
- [ ] Scheduled publish Friday evening (push + WhatsApp broadcast hook)
- [ ] Award archived permanently → writes a `legacy_events` row (schema from S6 stubbed now)
- [ ] Award announcement screen + share button

**Exit demo:** Run the weekly job on seed data → 7 members nominated, council confirms,
Friday announcement renders as a shareable story card.

**Definition of done:** every week, 7 members get named, story-based public recognition.

---

## Sprint 5 — Daily Spotlight + Tamil Voice  (55 → 65%)

**Goal:** A daily screenshot moment, and the local energy that makes it spread.

**Work items**
- [ ] `spotlight_cards` table + `spotlight_engine.py` trigger selection
- [ ] Daily 7 AM IST job: pick the day's best story (comeback, new rivalry, mentee win, milestone…)
- [ ] Claude writes card copy; generate shareable PNG
- [ ] Push to spotlighted member + WhatsApp share
- [ ] Spotlight archive ("you were spotlighted 7 times")
- [ ] `tamil_voice.py`: expression templates wired into wins, upsets, comebacks, mentoring
- [ ] Default notifications to Tamil; bilingual rendering everywhere generated text appears

**Exit demo:** Trigger the daily job → today's Spotlight card renders with Tamil-first copy,
the member gets a push, and the share button produces an image.

**Definition of done:** one member spotlighted daily; celebration language feels local, not corporate.

---

## Sprint 6 — Digital Legacy  (65 → 75%)

**Goal:** A history, not a profile. Permanent and shareable.

**Work items**
- [ ] `legacy_events` table finalized + `legacy_builder.py` (append-only recorder)
- [ ] Backfill legacy events from existing data (first game/win, titles, awards, spotlights)
- [ ] Wire all live events to write legacy rows (titles, rivalries, awards, mentorships, witnessed games)
- [ ] Legacy page UI: 5 chapters (Beginning / Growth / Rivalries / Community / Era)
- [ ] Era context (cohort, club milestones during tenure)
- [ ] "Welcome back" retrieval after 30+ day absence
- [ ] Legacy summary shareable card

**Exit demo:** Open a 6-month member's Legacy → a chaptered story with real milestones;
simulate a 30-day return → "Welcome back, here's where we left off."

**Definition of done:** any 6-month+ member has a meaningful, shareable legacy story.

---

## Sprint 7 — Village Pride & Area Wars  (75 → 85%)

**Goal:** Collective identity. Areas become teams with narratives.

**Work items**
- [ ] `area_narratives` + `area_challenges` tables
- [ ] `area_narrative.py`: daily per-area narrative (rank, hot members, active rivalries)
- [ ] Area dashboard UI (narrative-first, not a bare leaderboard)
- [ ] Area vs Area challenge flow: issue → accept → track → resolve → narrate
- [ ] Aggregate area prestige from member data
- [ ] Organic area nicknames (AI-detected playstyle patterns)

**Exit demo:** Open the Marthandam dashboard → daily narrative + rank; issue a challenge to
Nagercoil, play it out on seed data, see the result narrated ("rematch is a matter of honor").

**Definition of done:** areas feel like teams with identities and live rivalries.

---

## Sprint 8 — Community Prestige Loops  (85 → 95%)

**Goal:** Everyone has a path to status — not just strong players.

**Work items**
- [ ] `mentorships` table + Mentor path: track mentee improvement, credit mentor on mentee wins
- [ ] Master Mentor designation feeds prestige + reputation Leadership/Contribution dimensions
- [ ] Community Architect path: event hosting → prestige credit per participant; name on event forever
- [ ] Chronicler path: game outcome predictions + accuracy track record ("Community Oracle")
- [ ] Spectator-Supporter path: witness tracking → "Faithful Witness", names on legendary games
- [ ] Mentorship-chain lineage visible on profiles ("trained by → trained by")
- [ ] Cross-path prestige events fire correctly (Legacy Win, Predicted-this badge, Full Journey)

**Exit demo:** A non-player member reaches Community Strategist purely via mentoring + organizing;
their mentee's win shows "coached by [name]" and credits the mentor's reputation.

**Definition of done:** non-players have visible, honored, named prestige paths.

---

## Sprint 9 — AI Legends & Polish  (95 → 100%)

**Goal:** The community becomes permanent. Then harden everything.

**Work items**
- [ ] `ai_legends` table + eligibility check (200+ games, Area Star+, 6+ months, council vote)
- [ ] Style-profile capture from game history (openings, style, pressure behavior, strengths/weaknesses)
- [ ] Legend Challenge interface: play against historical members
- [ ] Claude-generated Legend biography from legacy data; Legend gallery
- [ ] Mentorship-chain preservation across legends (lineage forever)
- [ ] **Polish pass:** the "30-day disappearance" test on real cohorts, performance, caching, notification tuning, accessibility, full Tamil audit
- [ ] Anti-pattern audit: no punishing streaks, no naked leaderboards, no English-only screens

**Exit demo:** Immortalize a seed veteran → a new member challenges "Legend Rajan", reads his
biography, and sees the mentorship lineage he founded.

**Definition of done:** former members live on as challengeable legends; the system passes the
"will people notice if you disappear?" test on real data.

---

## Cross-Cutting Tracks (run through every sprint)

- **Tamil-first:** no screen ships English-only. Audited each sprint, hardened in S9.
- **Human-in-the-loop:** algorithm proposes, Community Council confirms (titles, awards, legends).
- **Permanence:** legacy/reputation events are append-only from the moment they exist.
- **Shareability:** every recognition artifact (rivalry, award, spotlight, legacy) exports a PNG.
- **AI off the hot path:** all Claude calls batched/async and cached; never block a game move.
- **Anti-addiction:** never punish absence; reward return instead.

## Sequencing Logic (why this order)

1. **Data before meaning** (S0–S1): titles/rivalries are worthless on bad data.
2. **Identity before drama** (S2 before S3): a rivalry between two *titled* members hits harder.
3. **Rhythm before history** (S4–S5 before S6): weekly/daily recognition generates the events
   that make the Legacy worth reading.
4. **Individual before collective** (≤S6 before S7): area pride aggregates individual prestige.
5. **Inclusion before permanence** (S8 before S9): everyone needs a path before we immortalize anyone.

## Risk Register

| Risk | Sprint | Mitigation |
|------|--------|-----------|
| Bad game data poisons everything | S0 | Server-authoritative results + dispute flag + audit log |
| AI narratives feel generic/wrong | S3 | Human council can edit; templates per moment-type; Tamil review |
| Council becomes a bottleneck | S2,S4,S9 | Batch reviews; sensible auto-thresholds; multiple reviewers |
| Claude API cost/latency | S3+ | Batch, cache daily/weekly, never on hot path |
| Only strong players get status | S8 | Five independent prestige paths shipped explicitly |
| Legend style feels nothing like the person | S9 | Capture rich signals; council approves before publishing |

---

*Living plan — adjust scope after each exit demo. Re-baseline % if a sprint slips;
never cut the exit demo (the member-facing moment is the point).*
