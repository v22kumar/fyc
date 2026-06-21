# FYC Chess — Community Chess Ecosystem Design (2026)

> **Status:** DRAFT v0.1 — for review & iteration before build
> **Module name (working):** *FYC Chess* / *Caissa Club* (final name TBD)
> **Owner:** FYC Connect product team
> **Last updated:** 2026-06-20

This is a living plan. Edit freely, then we build in phases from the roadmap at the bottom.

---

## 0. First Principles — Why people quit chess apps

Before designing features, we name the failure modes. Every system below maps back to one of these.

| # | Why people quit | Our counter-design |
|---|-----------------|--------------------|
| 1 | **They lose and feel dumb.** Losing 10 in a row with no explanation = quit. | Confidence Protection, AI Coach explains *every* loss, adaptive matchmaking, separate "Learning" score that only goes up. |
| 2 | **No one they know plays.** Anonymous opponents feel hollow. | Built on an existing real community (FYC). Village/street/team rivalries. Player Cards with real identity. |
| 3 | **Improvement is invisible.** ELO ±8 means nothing emotionally. | Five visible scores, streaks, achievements, seasonal ranks, a personal "you improved at X" feed. |
| 4 | **It's a chore, not a habit.** No reason to open it today. | Daily streaks, daily puzzle, daily mission, club events on a calendar, gentle (non-manipulative) reminders. |
| 5 | **Toxicity / pressure.** Trash talk, sandbagging, time pressure anxiety. | Sportsmanship score, reaction-only chat for strangers, "casual" modes with no rating risk. |
| 6 | **It's lonely to learn.** Tutorials are dry and solo. | Mentor system, guided games, learning streaks shared with friends, Tamil + English coaching. |

**Design north star:** *A beginner should feel proud after their 5th loss, not humiliated. An expert should still find a worthy rival inside their own community.*

---

## 1. Product Vision

**One line:** *The chess experience that makes an entire community better together — where a 12-year-old in Nagercoil and a club elder improve side by side, and every game strengthens a real friendship.*

**Vision statement:**
FYC Chess turns chess from a solitary skill ladder into a **community ritual**. Members don't just climb a rating — they represent their street, mentor a newcomer, keep a learning streak alive, and earn recognition that's visible to people they actually know. We borrow Duolingo's habit science, Clash Royale's progression joy, LinkedIn's credible achievements, Discord's belonging, and Chess.com's intelligence — and we ground all of it in a **real-world club**, which is our unfair advantage. No global chess app has a pre-existing village.

**What it is NOT:**
- Not another anonymous matchmaking board.
- Not pay-to-win. Not gambling. No loot boxes with money.
- Not an addiction machine — streaks have *grace* and *freezes*, not guilt.

---

## 2. User Personas

| Persona | Name | Age | Chess level | Motivation | Biggest risk |
|---------|------|-----|-------------|------------|--------------|
| **The Nervous Newcomer** | Anitha | 14 | Knows the rules, loses a lot | Wants to belong, fears looking dumb | Quits after a losing streak |
| **The Comeback Adult** | Suresh | 34 | Played as a kid, rusty | Nostalgia + wants to beat his friends | Too busy; needs low-friction habit |
| **The Club Competitor** | Karthik | 19 | Strong club player | Wants to be #1 in FYC, respected | Gets bored without real challenge |
| **The Mentor / Elder** | Mr. Raj | 52 | Veteran, patient | Wants to teach, give back, stay relevant | Feels tech is "not for him" |
| **The Social Glue** | Divya | 22 | Casual | Loves events, organizing, hype | Will leave if community feels dead |
| **The Organizer / Admin** | Club Secretary | — | Any | Runs tournaments, drives participation | Needs easy tools, fair results |

Every feature below should serve at least two personas. We design **for Anitha and Mr. Raj first** — if the nervous beginner and the non-techy elder both thrive, everyone in between does too.

---

## 3. Dynamic Rating System — Five Scores

ELO answers only "who is stronger." We answer **five questions** a community cares about. Each score is independent, visible on the Player Card, and tuned so that **at least three of the five can always go up**, even after a loss. This is the single most important anti-quit mechanic.

### 3.1 Skill Score (SS) — "How well do you play?"
A Glicko-2 style rating (better than ELO: tracks rating *confidence* via RD — rating deviation — so new/returning players converge fast and fairly).

```
Standard Glicko-2 update per rated game.
Display = round(rating), starts at 1000, RD starts high (350) → matchmaking
uses RD so uncertain players aren't punished/rewarded too hard.
```
- Only changes in **Rated** games. Casual/learning games never touch it.
- Floor protection: cannot drop below `(season_peak − 150)` within a season → prevents demoralizing free-fall.

### 3.2 Community Score (CS) — "How much do you strengthen FYC?"
Rewards participation, not raw strength. This is how Mr. Raj and Divya can rank highly without being the strongest player.

```
CS = Σ ( event_participation × w1
       + games_played_with_distinct_members × w2
       + tournaments_hosted × w3
       + referrals_activated × w4
       + community_feed_positive_contrib × w5 )
decayed monthly by 5% so it reflects *recent* contribution.
Suggested weights: w1=20, w2=2, w3=50, w4=40, w5=5
```

### 3.3 Consistency Score (CS-c) — "Do you show up?"
A 0–100 rolling index from streak health and weekly activity. Rewards rhythm over bingeing.

```
Consistency = 100 × ( active_days_last_28 / 28 ) ^ 0.7
Bonus +5 (cap 100) if current daily streak ≥ 7.
The ^0.7 curve means showing up 4 days/week ≈ 80, so part-timers
still score well — we are NOT demanding daily play.
```

### 3.4 Sportsmanship Score (SP) — "Are you good to play with?"
Starts at 100. Peer signals + behavior move it. Gates access to ranked events (must be ≥ 70 to enter Club Wars).

```
SP starts 100.
+1 per opponent "Good Game" reaction (max +3/day)
−10 rage-quit / repeated abort
−15 confirmed report (slow-roll a lost game, abusive reaction)
+2 for completing a game you were clearly losing (no rage-quit)
Slowly regenerates +1/week toward 100 if no incidents.
```

### 3.5 Learning Score (LS) — "Are you getting better?"
**Monotonic — it only ever goes up.** This is Anitha's lifeline: even on a 0–10 day, LS climbs.

```
LS += puzzles_solved × 1
   += lessons_completed × 5
   += ai_coach_reviews_read × 2
   += "concept mastered" milestones × 25
   += first_time_tactics_executed_in_real_game × 10 (detected by engine)
Never decreases. Displayed as a level (LS/100 = level).
```

**Composite "FYC Rank"** for leaderboards blends them so no single dimension dominates:
```
FYC_Rank_Points = 0.40·norm(SS) + 0.20·norm(CS) + 0.15·norm(Consistency)
                + 0.10·norm(SP) + 0.15·norm(LS)
(norm = min-max normalized to 0–1000 within the active season)
```
Players can also filter leaderboards by any single score ("Top Mentors", "Most Improved", "Most Sporting").

---

## 4. Streak Engine

Streaks drive daily return — but we explicitly **avoid dark patterns**. Three rules:
1. **Streak Freeze** — earn/buy (with FYC Points, never cash) up to 2 freezes; a missed day auto-consumes one.
2. **Grace window** — the day rolls over at a member-friendly hour (configurable, default 3 AM IST) and a 4-hour grace.
3. **No loss-guilt** — losing a *streak* never shows shame copy. "Your 12-day streak rested. Start a new one?" — warm, not punishing.

| Streak | How to keep alive | Reward cadence | Notes |
|--------|-------------------|----------------|-------|
| **Daily Play** | Play ≥1 game (any mode) | 3/7/14/30/100 day milestones → FYC Points + badge | Casual games count. Inclusive. |
| **Learning** | Solve ≥1 puzzle OR finish 1 lesson | Same milestones, separate badge line | Lets non-competitive players streak too |
| **Winning** | Win consecutive rated games | Resets on loss (expected) — celebrates hot runs, low stakes | Capped display at "10+" to avoid pressure |
| **Club Participation** | Join any club event in a 7-day window | Monthly "Pillar of FYC" badge | Weekly cadence = forgiving |
| **Mentor** | Mentee plays/learns while you're their mentor | Mentor Points → unlock Mentor tiers | Aligns elder incentives with newcomer success |

**Anti-addiction guardrails (explicit):**
- Hard cap on daily streak-reward value (diminishing returns after game #3).
- "Take a break" nudge after 90 min continuous play.
- No streaks on Sportsmanship or Skill (we never incentivize grinding *ranked* games for fear of loss).

---

## 5. FYC Points Economy

A **soft currency** (no cash value, can't be bought with money) that powers progression and a healthy sink economy. Design goal: faucets ≈ sinks so points stay meaningful and don't inflate.

### 5.1 Faucets (earning)
| Action | Points | Cap / anti-farm |
|--------|--------|-----------------|
| Play a rated game (completed) | 10 | Max 5 rewarded/day |
| Win a rated game | +15 | Diminishing vs much-weaker opponent |
| Daily puzzle solved | 20 | 1/day |
| Lesson completed | 25 | — |
| Daily streak milestone | 50–500 | Milestone-gated |
| Host a tournament (min 4 players finish) | 300 | Verified completion |
| Referral activated (referee plays 5 games) | 200 | Anti-self-referral checks |
| Mentor: mentee hits a milestone | 100 | Per genuine milestone |
| Win a Club War match | 250 | Event-gated |

### 5.2 Sinks (spending) — *this is what keeps the economy alive*
| Sink | Cost | Purpose |
|------|------|---------|
| Streak Freeze | 150 | Habit insurance |
| Cosmetic board/piece themes | 300–1500 | Self-expression (the big sink) |
| Player Card frames & flair | 500–2000 | Status, visible to community |
| Profile banner / animated avatar | 1000+ | Premium feel, no power |
| Enter premium tournament (prize = glory + cosmetics) | 100 | Commitment device |
| Gift points to a mentee | any | Pro-social sink |
| "Boost" a club event (more visibility) | 500 | Organizer tool |
| AI Coach "Deep Dive" extra analysis | 50 | Optional, the free tier already coaches |

**Critical rule:** Points **never** buy Skill advantage, rating, or matchmaking favors. Only cosmetics, convenience (freezes), and access (event entry that anyone can afford). This keeps it strictly **not pay-to-win** even if points were ever purchasable (they aren't, by current decision).

### 5.3 Anti-cheat / anti-farm
- **Engine-assistance detection:** server-side move-time + centipawn-loss analysis vs player's rating profile; flag suspiciously engine-correlated games (move-matching % over a rolling window). Shadow-review queue before any penalty.
- **Collusion/boosting detection:** graph analysis of who-beats-whom; detect rating-transfer rings and self-referral clusters.
- **Sybil / fake accounts:** tie accounts to verified FYC membership (we already have phone-verified users + org membership). One human ≈ one account — a massive advantage over public apps.
- **Rate limits & caps** on every faucet (above).
- **Server-authoritative game state** — clients never report their own results; the server runs the rules engine.

---

## 6. Community Features (our unfair advantage)

Because FYC is a *real* community with geography (we already store `geography`), we can do things Chess.com cannot.

| Feature | What it is | Why it's sticky |
|---------|-----------|-----------------|
| **Street vs Street / Village vs Village** | Aggregate scores of all members in a locality into a team; weekly territory leaderboard | Local pride, friendly trash talk with real neighbors |
| **Monthly Club Wars** | Whole-club bracket; members earn "war points" for their assigned squad | Everyone contributes regardless of skill (Community Score matters) |
| **Team Battles** | 5v5 simultaneous rated games; sum of results wins | Captaincy, strategy, belonging |
| **Festival Chess Challenges** | Themed events on Pongal, Diwali, club anniversary, etc. | Ties chess to the community calendar |
| **Blood Donor Chess Drive** | A chess event that doubles as a blood-donation awareness/registration drive (ties into existing Blood Donor module!) | Mission-aligned, uniquely FYC |
| **Relay Chess** | Team members alternate moves in one game | Hilarious, social, beginner-safe |
| **Elder vs Youth Day** | Generational friendly match event | Mentor bonding, story-worthy |
| **"Adopt a Beginner" weeks** | Mentors paired with newcomers; both earn for newcomer's progress | Directly attacks the #1 quit reason |
| **Live Watch Parties** | Spectate a featured club final with reactions in real time | Discord-style hype |

**New idea — "Home Ground":** each locality has a virtual clubhouse screen showing its team, recent wins, top mentor, upcoming event — a sense of *place*.

---

## 7. AI Coach

**Capabilities:** explains mistakes in plain Tamil/English, beginner & advanced modes, personalized improvement plans, post-game reviews, puzzle hints.

### 7.1 Architecture (hybrid — cost-aware)
```
[ Move analysis layer ]  → Stockfish (open-source engine) runs server-side
                            (or WASM client-side for casual hints) to get
                            best move + eval (centipawn loss) for each position.
                            This is FREE and deterministic. Do NOT use an LLM
                            to *calculate* chess — engines are better & cheaper.

[ Explanation layer ]    → Claude (claude-opus-4-8 / sonnet for cost) takes the
                            engine's structured output (FEN, your move, best move,
                            eval delta, tactical motif tags) and turns it into a
                            warm, level-appropriate explanation in TA/EN.

[ Plan layer ]           → Periodic job summarizes a player's recurring error
                            tags (e.g. "hangs pieces", "weak endgames") into a
                            personalized weekly mission set.
```
**Why this split:** engines do the *math* (accurate, free); the LLM does the *teaching* (empathetic, multilingual). Sending raw boards to an LLM and asking "what's the best move" is both expensive and weaker — we never do that.

### 7.2 Prompt shape (explanation layer)
```
System: You are a kind chess coach for a community club. The player is
{level}. Explain in {language}, {tone: encouraging}. Max 3 sentences.
Use simple words. Never shame.
Input (structured): { fen, player_move, best_move, eval_before, eval_after,
                      motif_tags: ["hanging_piece","missed_fork"],
                      player_recent_weakness: "tactics" }
Output: plain-language explanation + one concrete tip.
```

### 7.3 Cost controls
- Engine analysis cached per position (FEN hash) — shared across all players.
- LLM explanations cached per (FEN, move, level, lang) tuple.
- Free tier: post-game key-moment review (top 3 mistakes). "Deep Dive" (every move) is a small FYC-Points sink.
- Beginner hints during *learning* games are templated/engine-driven (no LLM call) for the common cases; LLM only for nuanced positions.

---

## 8. Beginner-Friendly Chess (Confidence Protection)

Directly engineered against quit-reason #1.

| Mechanism | How it works |
|-----------|-------------|
| **Adaptive matchmaking** | Uses Glicko RD; new players matched within a *protected* band; first 10 games are "placement" with no public rating shown |
| **Confidence Protection** | First 20 rated games: losses cost reduced SS; wins normal. After that, normal. |
| **Casual Mode** | Unlimited games with **zero** rating risk. AI hints allowed. |
| **Guided Games** | AI suggests good moves with explanation; player still chooses → learning by doing |
| **Learning Missions** | "Win a game using a fork", "Survive 20 moves vs the bot" — small, achievable, LS-rewarding |
| **Graceful bots** | Calibrated bot levels (engine depth-limited) labeled by *personality* not strength ("Patient Priya", "Bold Bala") so losing to a bot isn't ego-bruising |
| **No-clock option** | Anxiety reducer for elders & beginners |
| **"Takeback" in casual** | Opponent can grant takebacks; normalizes learning |

**Fairness preserved:** all protection is in *casual* or *placement*; once a player is established and in ranked/Club Wars, results are honest. Protection helps you *start*, never lets you *cheat the ladder*.

---

## 9. Seasonal System

| Cycle | Name | Length | Reward |
|-------|------|--------|--------|
| Monthly | **FYC Season** | 1 month | Seasonal rank badge, cosmetic, points; soft reset of SS toward mean (RD widened, not wiped) |
| Quarterly | **Club Championship** | 3 months | Engraved digital trophy on Player Card, Hall of Fame entry, exclusive cosmetic |
| Annual | **FYC Grand Masters Cup** | 1 year | Physical trophy at a real club event + permanent "GM Cup {year}" flair + top-of-Hall-of-Fame |

- **Soft reset** each season: ratings regress 25% toward 1000 and RD widens → everyone has a fresh shot, churned players can re-engage, but skill isn't erased.
- Rewards are **glory + cosmetics**, never cash, never power. Real-world trophies for annual cup tie digital → physical community.
- Separate seasonal ladders for each score so a "Most Improved of the Season" and "Most Sporting" are celebrated alongside the strongest.

---

## 10. Achievement Framework (100+)

Six categories. Tiered (Bronze/Silver/Gold/Platinum) where it makes sense. Achievements are **credible** (LinkedIn-style — they mean something and show on your Player Card).

**Learning (sample):** First Puzzle, Puzzle Streak 7/30/100, "Tactic Hunter" (100 forks executed), Endgame Apprentice→Master, Opening Explorer (try 10 openings), "Read the Coach" (50 reviews), Concept Master ×N.

**Winning:** First Win, Giant Slayer (beat someone 300+ SS higher), Comeback King (win from losing position, engine-verified), Flawless (win with <0.3 avg centipawn loss), 100/500/1000 wins, Checkmate Artist (deliver 10 named mates — Scholar's, Smothered, etc.).

**Community:** First Event, Host a Tournament, Recruit a Friend, "Pillar of FYC" (12-week participation streak), Street Champion, War Hero (decisive Club War win), Watch Party Regular.

**Leadership:** Become a Mentor, 1/5/25 mentees graduated, Captain a Team Battle, Organize a Festival event, "Built a Rivalry" (your street challenge gets 50+ games).

**Consistency:** 7/30/100/365-day streaks (Play & Learning), "Never Missed a Season", "Weekend Warrior", "Dawn Player" (play before 7 AM ×10).

**Strategy:** "Positional Python" (win without losing a piece), "Sacrificial Genius" (win after a sound piece sac, engine-verified), "Time Lord" (win 10 blitz on increment), "Defender" (hold 10 draws from worse positions), opening-specialist badges.

Target: **120 achievements at launch**, expandable. Each has TA + EN names and a short "why this matters."

---

## 11. Social Layer (with anti-toxicity by design)

| Feature | Design | Anti-toxicity guard |
|---------|--------|---------------------|
| **Reactions** | Emoji set incl. 🤝 "Good Game", 🔥, 🧠, 👏 | Strangers get **reaction-only** comms (no free text) |
| **Match Highlights** | Auto-generated clip of the key moment (brilliant move / mate) | Curated by engine, not user text |
| **Shareable Moments** | Beautiful image card of a win/brilliancy → share to FYC feed / WhatsApp | Ties to existing WhatsApp deep-links |
| **Player Cards** | Identity, five scores, top achievements, favorite opening, trophies | Real community identity = accountability |
| **Community Feed** | Wins, milestones, event results, "X mentored Y to first win" | Positive events only; no public loss-shaming |
| **Hall of Fame** | Season/quarter/annual champions, all-time mentors | Permanent honor |
| **Friends / Rivals** | Add friends, mark friendly rivals, challenge directly | Friend-gated text chat only |

**Toxicity model:** free-text chat is **opt-in and friend-gated**; strangers communicate via curated reactions only; Sportsmanship Score + reporting create real consequences; muting is one tap. We design the *default* to be safe, especially for Anitha (14) and elders.

---

## 12. Modern UI/UX — Screen-by-Screen

**Design language:** dark-first, glassmorphism over the existing FYC aurora (`#030C06` deep-forest base, forest-green `#0F5132`, gold `#D4AF37` accents — reuse the app's theme so Chess feels native, not bolted-on). Micro-animations, spring transitions, haptics on capture/check/checkmate/victory, full TA/EN, accessibility (scalable text, colorblind-safe board palettes, no-clock & high-contrast modes).

**Core flow:**
1. **Chess Home (Hub)** — aurora hero with your Player Card summary, current streaks (animated flames), "Play" CTA, daily puzzle card, today's mission, live club events strip.
2. **Play Sheet** — choose: Quick Rated · Casual · vs Bot (personalities) · Learning Game · Challenge a Friend · Join Event. Big, friendly, glass cards.
3. **In-Game** — minimal, elegant board; reaction bar; optional coach-hint button (casual); haptic + subtle sound on key events; graceful resign with no shame.
4. **Post-Game Review** — animated eval graph, top-3 moments with AI Coach explanations in your language, LS gained (always positive!), "share this win" if applicable.
5. **Learn** — puzzle ladder, lessons (TA/EN), your weakness-targeted missions, progress rings.
6. **Compete** — leaderboards (filter by any score / locality / friends), active events, Club Wars dashboard, your bracket.
7. **Community** — feed, Home Ground (your locality clubhouse), Hall of Fame, mentor/mentee space.
8. **Profile / Player Card** — five scores as a radar chart, achievements wall, trophy shelf, cosmetics, streak history, FYC Points wallet + shop.

Each screen: skeleton loaders, optimistic UI, offline-tolerant puzzle play.

---

## 13. Gamification Psychology (with ethics)

| Borrowed from | Mechanism | Our use | Ethical guard |
|---------------|-----------|---------|---------------|
| **Duolingo** | Streaks + freezes | Multi-streak engine | Freezes + grace + warm copy; no guilt |
| **Duolingo** | Daily bite-sized goal | Daily puzzle + 1 mission | Achievable in 3–5 min |
| **Clash Royale** | Visible progression & seasons | Five scores, seasonal ranks, cosmetics | No paid power, soft resets |
| **Chess.com** | Post-game insight | AI Coach reviews | Free core, empathetic tone |
| **LinkedIn** | Credible achievements/endorsements | Achievement wall, "Good Game" endorsements | Real identity, real meaning |
| **Discord** | Belonging, presence, events | Home Ground, watch parties, teams | Safe-by-default comms |
| **Reddit** | Recognition (upvote-like) | Reactions, feed highlights | Positive-only surfacing |

**Behavioral spine:** Hook model (trigger → action → *variable* reward → investment) used *honestly* — the "investment" is genuine skill + real relationships, not sunk-cost manipulation. Self-Determination Theory: we feed **competence** (Learning Score always up), **autonomy** (many modes, opt-in social), **relatedness** (it's your actual community). We explicitly refuse: FOMO timers that punish, infinite-scroll traps, paywalled fairness, manipulative loss-aversion copy.

---

## 14. Revenue Model (future, optional)

No ads. No pay-to-win. Revenue is **community-aligned** and entirely optional to the experience.

| Stream | What | Notes |
|--------|------|-------|
| **Club sponsorships** | Local businesses sponsor an event/season; tasteful branded tournament ("Saravana Stores Pongal Cup") | Sponsor logo on event card, not gameplay |
| **Premium analytics** | Power-user stats: deep trends, opening repertoire analysis, unlimited Deep Dive | Convenience/insight, never competitive power |
| **Tournament branding** | Organizers/sponsors pay to feature & brand a tournament | B2B-ish |
| **Donations** | "Support FYC Chess" tip jar; supporters get a cosmetic flair | Mission-driven |
| **Merch tie-in** | Physical boards/tees with FYC Chess branding at real events | Community/brand |

Cosmetics are bought with **FYC Points (earned, not money)** by current decision — keep this unless the club later opts to allow optional point purchases (still cosmetic-only).

---

## 15. Technical Architecture

> **Stack decision:** The prompt suggested Supabase, but FYC Connect **already runs FastAPI + SQLAlchemy + PostgreSQL on Fly.io, with a Flutter app and Firebase FCM.** Introducing Supabase would mean a second auth system, a second DB, and split membership/identity. **Recommendation: extend the existing backend** — reuse phone-verified membership, multi-tenant org model, and FCM we already have. Below targets our real stack; a Supabase mapping is noted where relevant for portability.

### 15.1 High-level
```
Flutter app (existing)
  └─ FYC Chess module (new feature package, mirrors existing feature/ structure)
        │  REST (Dio, existing ApiClient + JWT + X-Organization-ID)
        │  WebSocket (new) for live games & presence
        ▼
FastAPI backend (existing) + new routers:
  /api/v1/chess/...   game lifecycle, matchmaking, ratings, economy, events
  WebSocket gateway   real-time moves, clocks, spectating, presence
        │
        ├─ Rules & rating engine (server-authoritative): python-chess for legality,
        │  Stockfish subprocess/pool for analysis & bots
        ├─ PostgreSQL (existing) — durable state
        ├─ Redis (new) — live game state, clocks, matchmaking queue, pub/sub fan-out
        │  for WebSocket scaling, presence, rate-limit counters
        └─ Claude API (explanations) + Stockfish (calculation), both cached
Firebase FCM (existing) — turn reminders, event start, streak-at-risk nudges
```

### 15.2 Realtime architecture
- **WebSocket gateway** in FastAPI (or a small dedicated asgi service if it grows). Each live game = a room.
- **Redis pub/sub** fans out moves to both players + spectators and lets us run **multiple backend instances** on Fly (horizontal scale) — instances subscribe to the rooms their connected clients care about.
- **Server-authoritative**: client sends *intended move*; server validates with `python-chess`, updates state in Redis (fast) + journals to Postgres (durable), broadcasts the authoritative new state. Clocks tracked server-side to prevent cheating.
- **Reconnection**: game state in Redis lets a dropped player rejoin seamlessly; FCM nudge if it's their turn and they're away.

### 15.3 Matchmaking
- Redis sorted-set queue keyed by Glicko rating; pop nearest within an expanding RD-aware band; respect Sportsmanship gate for ranked; locality-aware option for community events.

### 15.4 Anti-cheat (engineering)
- Server-side Stockfish post-game scan → centipawn-loss & move-match% vs rating profile → anomaly score → shadow-review queue (human/admin confirms before penalty).
- Per-account analytics tied to verified membership (Sybil-resistant).
- All faucets server-counted with Redis rate-limit counters; results never client-trusted.

### 15.5 Scalability plan
- Stateless FastAPI instances behind Fly’s proxy; scale horizontally; Redis as shared live-state + pub/sub bus.
- Stockfish workers as a **separate pool** (CPU-bound) so analysis never blocks request handlers; queue via Redis; cache by FEN hash.
- Postgres: read replicas later if needed; heavy leaderboard queries pre-aggregated into summary tables on a schedule.
- Cost: engine + LLM caching keeps marginal cost near-zero for repeat positions.

---

## 16. Database Design (PostgreSQL, multi-tenant — reuse existing `organization_id` pattern)

Mirrors existing model conventions (UUID PKs, `organization_id` FK, timestamps). New tables under a `chess_` prefix.

```sql
-- Player profile / scores (1:1 with existing users)
chess_players (
  user_id UUID PK FK -> users.id,
  organization_id UUID FK,
  skill_rating REAL DEFAULT 1000,         -- Glicko-2
  skill_rd REAL DEFAULT 350,
  skill_vol REAL DEFAULT 0.06,
  community_score INT DEFAULT 0,
  consistency_score INT DEFAULT 0,
  sportsmanship_score INT DEFAULT 100,
  learning_score INT DEFAULT 0,           -- monotonic
  fyc_points INT DEFAULT 0,
  season_peak_skill REAL,
  created_at, updated_at
)

chess_games (
  id UUID PK, organization_id UUID,
  white_id UUID FK, black_id UUID FK,     -- nullable for bot games
  bot_level INT NULL,
  mode TEXT,                              -- rated|casual|learning|event
  event_id UUID NULL FK,
  pgn TEXT, final_fen TEXT,
  result TEXT,                            -- white|black|draw|abort
  termination TEXT,                       -- checkmate|resign|timeout|...
  white_rating_delta REAL, black_rating_delta REAL,
  white_acpl REAL, black_acpl REAL,       -- avg centipawn loss (anti-cheat + insight)
  time_control TEXT, started_at, ended_at
)

chess_moves (                            -- optional granular store; PGN may suffice
  game_id UUID FK, ply INT, san TEXT, fen_after TEXT,
  clock_ms INT, eval_cp INT NULL, PRIMARY KEY (game_id, ply)
)

chess_streaks (
  user_id UUID FK, type TEXT,            -- daily_play|learning|winning|club|mentor
  current INT, longest INT, last_active_date DATE,
  freezes_available INT DEFAULT 0,
  PRIMARY KEY (user_id, type)
)

chess_points_ledger (                    -- append-only, audit-friendly (we have audit patterns)
  id UUID PK, user_id UUID FK, organization_id UUID,
  delta INT, reason TEXT, ref_type TEXT, ref_id UUID, created_at
)

chess_achievements (
  id TEXT PK, category TEXT, tier TEXT,
  name_en TEXT, name_ta TEXT, desc_en TEXT, desc_ta TEXT, criteria JSONB
)
chess_player_achievements (
  user_id UUID FK, achievement_id TEXT FK, unlocked_at, progress JSONB,
  PRIMARY KEY (user_id, achievement_id)
)

chess_events (                           -- tournaments, club wars, festivals
  id UUID PK, organization_id UUID, type TEXT, name_en, name_ta,
  format TEXT, status TEXT, starts_at, ends_at, config JSONB
)
chess_event_participants (event_id, user_id, team TEXT, score INT, PK(event_id,user_id))

chess_teams (                            -- street/village/squad aggregates
  id UUID PK, organization_id UUID, geography_id UUID FK,  -- reuse geography!
  name TEXT, total_points INT
)

chess_mentorships (mentor_id, mentee_id, started_at, status, PK(mentor_id,mentee_id))

chess_coach_cache (fen_hash TEXT, move TEXT, level TEXT, lang TEXT,
                   explanation TEXT, PRIMARY KEY(fen_hash,move,level,lang))
```

Leaderboards: materialized/summary table `chess_leaderboard_season(season_id, user_id, fyc_rank_points, ranks_by_score JSONB)` refreshed on schedule.

### Supabase portability note
If ever moved to Supabase: tables map 1:1; Supabase Realtime replaces the Redis/WebSocket layer for moves; Supabase Auth would *replace* our JWT — **not recommended** because we'd lose the verified-membership Sybil resistance that makes our anti-cheat strong.

---

## 17. API Design (sketch)

```
# Player / scores
GET   /api/v1/chess/me                      -> player card (5 scores, points, streaks)
GET   /api/v1/chess/players/{id}            -> public player card
GET   /api/v1/chess/leaderboard?score=&scope=&season=

# Play
POST  /api/v1/chess/matchmaking/enqueue     {mode, time_control}
DELETE/api/v1/chess/matchmaking             -> leave queue
POST  /api/v1/chess/games/bot               {bot_level, mode}
WS    /ws/chess/game/{game_id}              -> {move|resign|draw_offer|react|chat}
GET   /api/v1/chess/games/{id}              -> full game + review
POST  /api/v1/chess/games/{id}/review       -> trigger/fetch AI Coach analysis

# Learn
GET   /api/v1/chess/puzzles/daily
POST  /api/v1/chess/puzzles/{id}/attempt
GET   /api/v1/chess/lessons | /missions

# Economy
GET   /api/v1/chess/wallet
POST  /api/v1/chess/shop/purchase           {item_id}
POST  /api/v1/chess/streaks/freeze

# Community
GET   /api/v1/chess/events | POST .../events (organizer)
POST  /api/v1/chess/events/{id}/join
GET   /api/v1/chess/teams | /hall-of-fame | /feed
POST  /api/v1/chess/mentorship              {mentee_id}
```
All authenticated via existing JWT + `X-Organization-ID`. Reuse existing rate-limiting (slowapi) and role checks (organizer actions = club admin role).

---

## 18. Success Metrics (KPIs & targets)

| Metric | Definition | Launch target (3 mo) | Mature target (12 mo) |
|--------|-----------|----------------------|------------------------|
| **DAU** | unique players/day | 15% of FYC members | 35% |
| **WAU** | unique players/week | 40% | 65% |
| **MAU** | unique players/month | 60% | 80% |
| **D1 / D7 / D30 retention** | return after 1/7/30 days | 45 / 25 / 15% | 60 / 40 / 28% |
| **Streak retention** | % keeping a ≥7-day streak | 20% | 35% |
| **Match completion** | games finished (not aborted) | 85% | 92% |
| **Beginner survival** | beginners still active after 10 losses | 50% | 70% (the key one) |
| **Community participation** | % joining ≥1 club event/month | 30% | 55% |
| **Mentor coverage** | % beginners with a mentor | 25% | 60% |
| **Sportsmanship health** | median SP score | ≥ 95 | ≥ 97 |

**Beginner survival is the headline metric** — it's the direct measure of beating quit-reason #1.

---

## 19. Launch Roadmap (phased)

| Phase | Scope | Outcome |
|-------|-------|---------|
| **P0 — Foundation** | DB schema, chess_players, server-side rules engine (python-chess), basic REST, Flutter board widget, vs-Bot (3 personalities), Casual mode, Skill+Learning scores only | Playable single-player + casual; no realtime yet |
| **P1 — Realtime PvP** | WebSocket gateway + Redis, matchmaking, rated games, Glicko-2, clocks, reconnection | Real members play each other live |
| **P2 — Habit & Economy** | Streak engine, FYC Points faucets/sinks, daily puzzle, basic achievements (~40), Player Card | Daily return loop active |
| **P3 — AI Coach** | Stockfish analysis pool, post-game review, Claude explanations (TA/EN), weakness missions | Learning loop + retention boost |
| **P4 — Community** | Events/tournaments, Club Wars, Street vs Street (geography teams), feed, Hall of Fame, mentorship | Community flywheel |
| **P5 — Polish & Seasons** | Seasonal system, 120 achievements, cosmetics shop, watch parties, anti-cheat scan, full a11y | Premium 2026 feel, sustainable |
| **P6 — Growth** | Shareable moments, referrals, festival events, sponsorships | Viral + (optional) revenue |

Each phase ships independently and is dogfooded with a small group of real FYC members before the next.

---

## 20. Growth Strategy

- **Seed with rivalry:** launch with a Street vs Street event — instant local stakes, WhatsApp-shareable.
- **Mentor-led onboarding:** recruit respected club elders as the first mentors; their mentees bring friends.
- **Shareable wins:** every brilliancy/first-win generates a beautiful card → WhatsApp/feed (reuse existing share deep-links).
- **Festival anchors:** big themed events on Pongal/Diwali/club anniversary as recurring tentpoles.
- **Referral loop:** points for activated referrals (anti-farmed), capped, pro-social.
- **Cross-module:** surface "Blood Donor Chess Drive", show chess achievements on the main FYC profile, push from existing home screen.
- **Web teaser:** lightweight web leaderboard/Hall of Fame (Astro) that's public → SEO + pride → app installs (ties into the new app-download flow).

---

## 21. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Cheating with engines** | Destroys trust, drives out honest players | Server-side Stockfish scan + verified-membership Sybil resistance + shadow review |
| **Cold-start / empty lobbies** | "No one's online" → quit | Strong bots as fallback, async puzzle/learning always available, scheduled event windows to concentrate players |
| **Toxicity** | Beginners & elders flee | Safe-by-default comms, SP score, reporting, friend-gated chat |
| **Addiction optics** | Community/parent backlash | Explicit guardrails (break nudges, freeze grace, no guilt copy), documented ethics |
| **AI cost blowup** | Unsustainable | Engine does math (free), LLM cached & tiered, free core / points Deep Dive |
| **Realtime scaling pain** | Lag, disconnects | Redis pub/sub + server-authoritative state + reconnection; load-test before festival events |
| **Scope creep** | Never ships | Strict phased roadmap; P0–P2 is a complete product on its own |
| **Low elder adoption** | Lose key persona | No-clock mode, large text, Tamil-first coaching, mentor status & respect |
| **Pay-to-win drift** | Kills fairness ethos | Hard rule in code review: points/money buy cosmetics & access only, never power |

---

## 22. Open Questions (decide before P0)

1. Final module name & branding (FYC Chess vs Caissa Club vs ...).
2. Cosmetics: points-only forever, or allow optional point top-ups later (cosmetic-only)?
3. Stockfish hosting: in-process subprocess pool on Fly vs a small dedicated analysis service?
4. Redis: add to Fly stack now (P1) — confirm budget/ops.
5. Which 3 bot "personalities" and their calibrated strengths for P0?
6. Geography granularity for teams — street, ward, or village level? (depends on existing `geography` data depth)
7. Do we want a public web leaderboard at launch or post-P4?

---

*End of v0.1. Edit any section; when the plan is locked, we start at Phase P0.*
