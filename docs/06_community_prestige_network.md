# FYC: Community Prestige Network — System Design

> **The Fundamental Shift**
>
> FYC is not building a chess app with social features.
> FYC is building a **community prestige network** where chess is the first expression of competition.
>
> The fuel is not engagement. The fuel is **recognition, pride, status, rivalry, belonging, significance.**
>
> The ultimate design test: *"If this member disappears for 30 days, will people notice?"*
> If yes, the system is working. If no, the system has failed — regardless of DAU, ratings, or streaks.

---

## Table of Contents

1. [Core Philosophy](#1-core-philosophy)
2. [Prestige System — Titles, Not Points](#2-prestige-system)
3. [Rivalry Engine — Narrative, Not Rankings](#3-rivalry-engine)
4. [Reputation Graph — The Full Human Picture](#4-reputation-graph)
5. [Community Prestige Loops — Everyone Has a Path](#5-community-prestige-loops)
6. [AI-Powered Weekly Recognition](#6-ai-powered-weekly-recognition)
7. [FYC Spotlight — Daily Screenshot Moments](#7-fyc-spotlight)
8. [Village Pride — Narrative, Not Leaderboard](#8-village-pride)
9. [Digital Legacy — A History, Not a Profile](#9-digital-legacy)
10. [AI Legends — The Community Lives Forever](#10-ai-legends)
11. [Tamil Identity Layer](#11-tamil-identity-layer)
12. [Technical Architecture](#12-technical-architecture)
13. [Database Schema](#13-database-schema)
14. [Phased Roadmap](#14-phased-roadmap)
15. [Design Principles & Anti-Patterns](#15-design-principles--anti-patterns)

---

## 1. Core Philosophy

### What members actually want

Not ratings. Not badges. Not streaks.

People want to feel:
- **Respected** — "people here know who I am and what I've done"
- **Remembered** — "my history matters; it's not lost when I log out"
- **Recognized** — "when I do something special, someone notices and says so"
- **Significant** — "this community would be different without me"
- **Proud** — "I can show this to my family and they'll understand why it matters"
- **Part of something** — "Marthandam vs Colachel — our rivalry has a story, I'm in it"

### The design question for every feature

Before building anything, ask: **"Does this make a member feel more recognized, more significant, or more remembered?"**

If the answer is "mildly entertaining" — don't build it.
If the answer is "yes, and they'll tell someone else about it" — build it first.

### Chess is the beginning, not the product

Chess provides:
- A skill arena with clear outcomes (win/loss — no ambiguity)
- A natural rivalry mechanism (rematches, grudges, redemption arcs)
- A prestige gradient (beginner → legend is legible to everyone)
- A community gathering point (watching, coaching, trash-talking, celebrating)

Future arenas: Carrom. Kabaddi. Quiz. Prediction markets. Art/Poetry contests.
The prestige system, reputation graph, and recognition engine work across ALL arenas.

---

## 2. Prestige System

### Titles replace points

Points are private scores. Titles are **public identities**.

A member doesn't say "I have 2,847 points." A member says "I'm a **Club Champion**."

That title means something to every other FYC member. It carries weight. It's earned, not bought.

### The Eight Titles

| Title | Tamil Name | Threshold Concept |
|-------|-----------|-------------------|
| **Rising Talent** | உயரும் திறமை | New member showing early promise — first wins, first rivalries |
| **Area Star** | ஏரியா ஸ்டார் | Known and respected within their area; people seek them out |
| **Community Strategist** | சமூக சிந்தனையாளர் | Not just plays — teaches, organizes, contributes |
| **Silent Killer** | அமைதி கொலையாளி | Underestimated, then devastating; consistency over flash |
| **Master Mentor** | குரு | Others have improved because of them directly; leaves a legacy of skill |
| **Club Champion** | கிளப் சாம்பியன் | Proven across events, rivalries, and community — the full picture |
| **FYC Legend** | FYC புராணம் | Rare. Transcended competition — their story defines the club era |
| **Kumari Icon** | குமரி ஐகான் | Once in a generation. The region knows their name. |

### How titles are assigned

**Not by a single score.** Titles emerge from a multi-signal reputation graph assessment:

```
Title eligibility = f(
  games_played,
  rivalry_outcomes,
  community_contributions,
  mentorship_impact,
  event_participation,
  longevity_and_consistency,
  peer_recognition_signals,
  spotlight_appearances
)
```

An algorithm surfaces candidates. A **Community Council** (senior members) confirms.
This matters: **humans in the loop preserve legitimacy.** The algorithm proposes; the community decides.

### Title display rules

- Title appears on every game result card, next to the member's name
- In group match-ups: "**Club Champion** Varun vs **Area Star** Arjun" — the tension is narrative, not numerical
- Past titles are permanently visible in Digital Legacy: "Was **Rising Talent** → **Area Star** → **Community Strategist**"
- Titles can only go forward. You never lose a title — you earn the next one.

### What does NOT affect title

- Winning a single tournament
- A hot streak
- Being online a lot
- Anything that can be gamed by grinding

---

## 3. Rivalry Engine

### Rivalries are discovered, not created

The system watches who plays who repeatedly. It identifies patterns:

- **Volume**: 20+ games between two players
- **Tension**: win rate between 40–60% (competitive, not one-sided)
- **Drama**: momentum swings (one player dominant, then the other catches up)
- **Recency**: still active, not a cold rivalry

When these conditions are met, the system creates a **Rivalry Card** — a living narrative object.

### Rivalry Card structure

```
┌─────────────────────────────────────────────────────┐
│  ⚔️  THE MARTHANDAM DUEL                           │
│                                                     │
│  VARUN "Silent Killer" KRISHNAN                     │
│         vs                                          │
│  ARJUN "Area Star" SELVAM                          │
│                                                     │
│  47 battles · Started Oct 2024                     │
│  Varun leads: 25–22                                │
│                                                     │
│  📖 STORY                                          │
│  Arjun won 8 in a row last December.               │
│  Varun came back to win 6 straight in March.       │
│  Current streak: Arjun +3.                         │
│                                                     │
│  🔥 BIGGEST MOMENT                                 │
│  March 14 — Varun's 5-hour comeback game           │
│  after being down queen + rook.                    │
│  The club watched live. 23 people present.         │
│                                                     │
│  📅 NEXT CHAPTER                                   │
│  They haven't played in 11 days.                  │
│  [Challenge Arjun now →]                           │
└─────────────────────────────────────────────────────┘
```

### Rivalry narrative generation

Key moments are stored per-game:
- Upset wins (lower-prestige player beats higher)
- Comeback wins (lost material advantage recovered)
- Streak-enders (one player breaks other's win run)
- Marathon games (longest duration)
- Witness count (how many community members watched)

The AI generates the narrative text from these signals in Tamil and English.
Updated automatically after each game.

### Rivalry types

| Type | Description | Example |
|------|-------------|---------|
| **Personal** | Two individuals | Varun vs Arjun |
| **Sibling** | Literal brothers/cousins | The Kumar Brothers |
| **Teacher-Student** | Mentor vs mentee | "The Student Rises" arc |
| **Area** | Two neighborhoods | Marthandam vs Colachel (aggregated scores) |
| **Era** | Cross-time challenge | Challenge an AI Legend from 2024 |

### Rivalry notifications

When rivals are matched or when the gap shifts:
- "Arjun just cut your lead to 1. He's coming."
- "Varun hasn't played in 2 weeks. Your rivalry cools. Resume it?"
- "3 people are watching your rivalry card today."

---

## 4. Reputation Graph

### Six dimensions — chess rating is one input, not the center

```
                    SKILL
                      │
   LEADERSHIP ────── [MEMBER] ────── TRUST
                      │
              CONTRIBUTION
                      │
    CONSISTENCY ─────┤
                      │
                   PRESTIGE
```

| Dimension | What it measures | Chess contribution |
|-----------|-----------------|-------------------|
| **Skill** | Chess ability, learning trajectory, improvement rate | Primary input (Glicko-2 rating + trend) |
| **Trust** | Reliability — shows up, doesn't ghost games, completes commitments | Secondary input (game completion rate) |
| **Contribution** | Teaching, organizing, volunteering, event running | Not chess-specific |
| **Consistency** | Long-term presence over months/years, not hot-and-cold | Activity pattern over time |
| **Leadership** | Others follow their example; they elevate the group | Mentorship outcomes |
| **Prestige** | How the community perceives them — aggregated from all above | Emergent, not directly gamed |

### Reputation Graph visualization

A hexagonal radar chart. Not numbers — visual shape.

A great mentor who doesn't play much has a very different shape than a tournament winner who never helps anyone. Both shapes are valid. Both are respected. Neither is "better" by default.

This is intentional: **there is no one right way to be valuable here.**

### Public vs private

- Members can see their own graph at any resolution
- Others see a simplified version (no raw numbers — just the shape and relative size)
- Numbers are deemphasized in the UI; shape and narrative are primary

---

## 5. Community Prestige Loops

### Everyone has a path to status — not just the best players

Most "gamified" platforms fail because only top performers accumulate status. Everyone else is audience.

FYC's model: multiple independent prestige paths that cross and interact.

### The Five Paths

#### Path 1: Competitor
Win games → build rivalries → earn prestige titles → become an AI Legend
The obvious path. Expected. Respected. Not the only way.

#### Path 2: Mentor
Teach beginners → track their improvement → earn **Master Mentor** designation
Mentors are publicly credited when their students win.
"Arjun's first tournament win — coached by Varun"
Mentors earn prestige from other people's games.

#### Path 3: Community Architect
Organize events → host tournaments → build area pride
Event hosts get a community prestige credit for every person who participates in events they organized.
The organizer's name is on the event forever in the Digital Legacy.

#### Path 4: Chronicler / Analyst
Predict game outcomes → build a prediction track record → earn "Community Oracle" recognition
Comment on games → earn recognition for insight
Create content (match summaries, player profiles, area reports) → build a reputation as the club's voice

#### Path 5: Spectator-Supporter
Consistent presence at matches → named "loyal witness" on big moments
Members who were *watching* when a legendary game happened get noted in that game's history
"17 community members witnessed this match — [names]"
Being present for history IS a form of participation.

### Cross-path interactions

- A Mentor's student wins a tournament → Mentor gets a "Legacy Win" prestige event
- An Architect's event produces a legendary game → Architect's name on that game's legacy card
- A Chronicler's prediction is correct on an upset → "Predicted this" badge on that game forever
- A Spectator-Supporter who watched a player's first match and their hundredth gets "Full Journey" recognition

### No path is locked by chess skill

A non-player can reach **Community Strategist** prestige through mentorship, organizing, and chronicling.
This is not a consolation prize. It's a legitimate and honored role.

---

## 6. AI-Powered Weekly Recognition

### Named awards, not category trophies

Every week, the AI nominates one member per award. A brief human review (Community Council) confirms or overrides. Awarded on Friday evening — highest engagement moment.

### The Seven Weekly Awards

| Award | Tamil | Who Earns It |
|-------|-------|-------------|
| **Most Improved** | மிகவும் வளர்ந்தவர் | Largest positive skill trajectory change this week (not absolute level) |
| **Biggest Comeback** | மிகப்பெரிய திரும்புதல் | Won after largest material deficit, or won after longest losing streak |
| **Silent Assassin** | அமைதி கொலையாளி | Underestimated opponent (lower prestige) who beat a much higher player |
| **Community Hero** | சமூக ஹீரோ | Highest non-game contribution: organized, mentored, helped, showed up |
| **Rising Star** | உதயமான நட்சத்திரம் | Newest active member with highest relative performance |
| **The Storyteller** | கதையாளர் | Best match commentary, prediction accuracy, or content created |
| **Faithful Witness** | உண்மையான சாட்சி | Most matches attended/watched — the fan who never misses |

### Award announcement format

Not a dry notification. A story.

```
🌟 THIS WEEK'S SILENT ASSASSIN: PRIYA SUBRAMANIAN

Everyone expected Kumar to win. He's a Club Champion.
Priya is a Rising Talent with 3 months of experience.

She played 1.d4 — an opening Kumar had never faced from her.
Midgame: she sacrificed her bishop. Everyone watching thought it was a mistake.
It wasn't. 14 moves later: checkmate.

Kumar's streak: ended at 9.
Priya's statement: she's here.

Priya receives the ⚔️ Silent Assassin recognition for the week of June 16.

[View the game] [Send Priya a message] [Share]
```

This is shareable. Members screenshot it and send it on WhatsApp.
That is organic growth.

### Award history

Every award is permanently recorded in the member's Digital Legacy.
"Week of March 3: Biggest Comeback of the Week"
Ten years later, this is still there.

---

## 7. FYC Spotlight

### Daily, screenshot-worthy, one member at a time

Every day at 7:00 AM IST, one member is spotlighted.
Not the best player. The most interesting story of the day.

### Spotlight triggers

The system watches for:
- First win after a long losing streak
- A new rivalry beginning (two players just had their 5th head-to-head game)
- A teaching milestone (a mentor's student just beat their first opponent)
- A streak milestone (10 games, 20 games, 50 games played)
- A comeback from long absence (returned after 30+ days and won immediately)
- An unexpected upset that the community witnessed
- A younger member beating their parent/elder for the first time

### Spotlight card design (shareable image)

```
╔═══════════════════════════════════════════╗
║         ★ FYC SPOTLIGHT · JUNE 20 ★       ║
╠═══════════════════════════════════════════╣
║                                           ║
║   [MEMBER AVATAR]  KARTHIK PILLAI         ║
║   Area Star · Nagercoil                   ║
║                                           ║
║   "After 8 losses in a row, he came back ║
║    and won 3 straight this morning.       ║
║    Nobody counted him out faster          ║
║    than he counted himself back in."      ║
║                                           ║
║   🔥 Current streak: 3 wins               ║
║   🎯 Greatest rival: Suresh (22–19)       ║
║   📅 Member since: Oct 2023               ║
║                                           ║
║   fyc-web.fly.dev · FYC Connect           ║
╚═══════════════════════════════════════════╝
```

This is designed to be screenshotted and sent to WhatsApp groups.
The member's family will see it. Their friends will ask about it.

### Spotlight notification

The member receives a push notification:
"🌟 You're today's FYC Spotlight. [View your card]"
Optional: share button directly to WhatsApp.

### Archive

Every Spotlight is stored permanently. A member can revisit every time they were spotlighted.
"You were spotlighted 7 times. Here are your moments."

---

## 8. Village Pride

### Narrative, not a leaderboard

A leaderboard shows: Marthandam — 1,423 points. Nagercoil — 1,891 points.
Nobody reads it after the first week.

A narrative shows: "Marthandam is 3 wins away from their best month ever. Karthik and Priya are carrying the flag."

The system auto-generates area-level narrative updates daily.

### Area Pride Dashboard

```
🏘️ MARTHANDAM UPDATE · June 20

📈 Area Prestige: Climbing
   3rd in Kanyakumari district · Up from 5th last month

🔥 Hot Right Now
   Karthik Pillai — 3-game win streak
   Priya on debut rivalry with Nagercoil's top player

⚔️ Active Rivalries
   Marthandam vs Colachel — Area rivalry score: 14–17
   (Colachel leads, but Marthandam closing gap)

🌟 Area's Best Moment This Month
   June 14 — Karthik beat Club Champion Rajan in overtime.
   5 Marthandam members witnessed it live.

📣 Next Area Challenge
   Nagercoil has called out Marthandam for a 5-game team match.
   3 players needed. [Sign up]
```

### Cross-area challenges

Areas can formally challenge each other.
Admin creates the challenge; the system tracks aggregate results.
5 games, 3 different players per area. Best of 5 wins.

The losing area's narrative: "Nagercoil defeated us 3–2. The rematch is now a matter of honor."
This language is intentional. Pride is motivating.

### Area identity earned over time

- Areas develop nicknames organically: "The Nagercoil Fortress" (defensive players), "The Marthandam Attackers"
- The AI identifies and names these patterns from actual game data
- Members adopt these identities — they write them in their bios

---

## 9. Digital Legacy

### A history, not a profile

A profile page is: name, rating, games played, win rate. Static. Cold. Forgettable.

A Digital Legacy is: the story of someone's entire journey here. Alive. Personal. Worth showing your children.

### What the Digital Legacy contains

**Chapter 1: The Beginning**
- First game (date, opponent, result)
- First win (opponent's name, how long it took)
- First rivalry to emerge
- First recognition received

**Chapter 2: Growth**
- Title progression timeline: "Rising Talent → Area Star → Community Strategist"
- Skill curve (visual, not numbers)
- Turning point moments: games that changed their trajectory

**Chapter 3: Rivalries**
- Every active and concluded rivalry with full narrative
- Head-to-head records
- Most memorable moment from each rivalry

**Chapter 4: Community Footprint**
- Members mentored (and their outcomes)
- Events organized or participated in
- Weekly awards received (permanent)
- Spotlights received (permanent)
- Matches witnessed by this member (they are part of those stories too)

**Chapter 5: Era Context**
- "When you joined, the top player in Kanyakumari was Rajan with Club Champion title."
- "You were part of the 2024 cohort — 23 members who all joined around the same time."
- "During your first year, FYC ran 12 events. You participated in 7."

### Viewing someone else's legacy

When a newer member views a senior member's legacy, they see:
- The full story arc — not just current stats
- The low points (losing streaks that were overcome)
- The community impact (mentees, events, witness appearances)
- The titles earned over time

This makes senior members **inspiring** rather than just **intimidating**.

### Permanence guarantee

Legacy data is append-only. Nothing can be deleted by the member.
(Admins can remove content that violates community standards, but the member cannot erase their own history.)

The reason: if a member leaves and comes back 3 years later, their history is intact.
"Welcome back, Karthik. Here's where we left off."

---

## 10. AI Legends

### The community becomes self-preserving

Problem with community platforms: when top players leave, newer members never get to experience them.
The history dies with the active user.

FYC's solution: after sufficient participation, a member's playing style is **immortalized as an AI bot** that future members can challenge.

### Eligibility threshold (approximate)

- Minimum 200 rated games played
- Achieved at least "Area Star" prestige
- 6+ months of activity
- Community approval (Community Council votes to immortalize them)

The threshold is high. Being an AI Legend is an honor, not a default.

### What the AI Legend captures

From the member's game history:
- Opening preferences (which first moves, which openings avoided)
- Playing style signature (aggressive, positional, tactical, defensive)
- Decision patterns under pressure (time pressure behavior, comeback tendency)
- Strength and weakness profile (endgame vs. openings, etc.)

The AI is trained to approximate their style — not to be perfect chess, but to feel like playing *them*.

### The Legend Challenge UI

```
⚔️ CHALLENGE AN FYC LEGEND

RAJAN "Club Champion" KRISHNAMURTHY
   Active: 2023–2025 · Marthandam
   Games played: 847 · Peak title: Club Champion
   Playing style: Aggressive center control, relentless pawn storms
   Strength: Middlegame combinations
   Weakness: Endgame technique (exploitable)
   
   "Rajan built the foundation of FYC chess culture.
   He trained 14 current active members.
   He left in 2025, but never really left."

[Challenge Legend Rajan] [Read his Legacy] [See who he mentored]
```

### Mentorship chain preservation

When a Legend trained other members, those members' pages show:
"Trained by: Legend Rajan Krishnamurthy"

When the Legend's training is documented in a current member's legacy, the chain is visible:
- Rajan trained Varun.
- Varun trained Priya.
- Priya is now training two newer members.

The community's skill passes down visibly and named. This is how culture is preserved.

---

## 11. Tamil Identity Layer

### The local energy, not corporate gamification

Standard gamification: "Achievement Unlocked! 🎉 You completed 10 games!"
FYC Tamil layer: "Semma move da! Area la ellaarum pesuvaanga!" 🔥

The difference is the difference between a notification and a moment that makes you call your friend.

### Language philosophy

- All content is available in Tamil and English
- Tamil is the default for celebration and community moments
- English is available for those who prefer it
- Bilingual is the norm: show both naturally, not as a toggle

### Tamil expressions built into the system

| Moment | Tamil Expression |
|--------|-----------------|
| Brilliant unexpected move | "Semma move! 🔥" |
| Area reputation: everyone will hear about this | "Area la pesuvaanga!" |
| Strategic genius move | "Mind game aarambam!" |
| Comeback win | "Thirumba vandhutten!" |
| Long game finally won | "Patience payoff! Sonnavan naan!" |
| Mentoring someone to a win | "என் student! 🙏" |
| Upset win over a legend | "Legend fall! 😱" |
| First rivalry card created | "இப்போ நம்ம story aarambam!" |

### Local identity signals

- Player cards show their area/village name prominently
- Area rivalries use local geographic references
- Tournament names: "Kanyakumari Open", "Kumari Cup", "Nagarkovil Derby"
- Event timing around local festivals and Tamil calendar
- Notifications in Tamil by default: "வணக்கம் Karthik! உன் rival Arjun challenge விட்டான்!"

### Celebration design

FYC celebrations feel like a street gathering, not a corporate achievement wall.

- Win notifications sound and feel like someone in the neighborhood shouting congratulations
- Big wins get a brief audio celebration clip option (sharable)
- Weekly awards are announced as if at a community meeting — named, described, applauded

---

## 12. Technical Architecture

### Backend additions to existing stack (FastAPI + PostgreSQL + Redis)

```
backend/app/
├── services/
│   ├── prestige_engine.py        # title eligibility scoring + Community Council queue
│   ├── rivalry_engine.py         # rivalry detection, narrative generation, updates
│   ├── reputation_graph.py       # six-dimension computation + normalization
│   ├── recognition_engine.py     # weekly award nomination logic
│   ├── spotlight_engine.py       # daily spotlight selection + card generation
│   ├── area_narrative.py         # village/area narrative generation
│   ├── legacy_builder.py         # append-only legacy event recorder
│   ├── ai_legends.py             # legend eligibility + style capture + bot interface
│   └── tamil_voice.py            # expression templates + localization
├── routers/
│   ├── prestige.py               # GET /prestige/titles, /prestige/my-title
│   ├── rivalries.py              # GET /rivalries/my, /rivalries/{id}, POST /rivalries/challenge
│   ├── reputation.py             # GET /reputation/{member_id}
│   ├── recognition.py            # GET /recognition/weekly, /recognition/history
│   ├── spotlight.py              # GET /spotlight/today, /spotlight/archive
│   ├── legacy.py                 # GET /legacy/{member_id}, /legacy/me
│   ├── legends.py                # GET /legends, POST /legends/{id}/challenge
│   └── area.py                   # GET /area/{area_name}/narrative
└── models/
    ├── prestige.py
    ├── rivalry.py
    ├── reputation_event.py
    ├── recognition_award.py
    ├── legacy_event.py
    └── ai_legend.py
```

### AI integration points

| Feature | Claude Role | Stockfish/Algorithmic Role |
|---------|------------|---------------------------|
| Rivalry narrative | Writes the story text | Detects rivalry conditions from data |
| Weekly award announcement | Writes the member story | Selects the winner algorithmically |
| Spotlight text | Writes the card copy | Selects the spotlight trigger |
| Area narrative | Writes the daily update | Aggregates stats and trends |
| Legacy chapters | Writes narrative sections | Structures the raw event data |
| Tamil expressions | Translates + localizes | Selects the appropriate moment |
| AI Legends | Explains the style for challengers | Captures the playing pattern |

Claude API calls are batched and asynchronous — not on the hot path of game moves.
Generated text is cached for the day/week and refreshed on schedule.

### Redis usage

```
prestige:candidate_queue         # members flagged for council review
rivalry:active:{member_id}       # current rivalries (fast lookup)
spotlight:today                  # current spotlight card (cached)
recognition:weekly:nominations   # current week's award candidates
area:narrative:{area}            # cached area narrative (daily refresh)
```

### Notification triggers

| Event | Recipient | Message |
|-------|-----------|---------|
| Rivalry card created | Both members | "Your rivalry with [name] is now official. 47 games. This has a name." |
| Weekly award won | Winner | Full award announcement story |
| Spotlight selected | Spotlighted member | "You're today's FYC Spotlight." |
| Title upgraded | Recipient | "The Community Council has recognized you as [Title]." |
| Legacy milestone | Member | "You've been here 1 year. [View your Legacy]" |
| Rival challenges | Challenger + Recipient | "Arjun has challenged you. The rivalry continues." |

---

## 13. Database Schema

```sql
-- Prestige titles
CREATE TABLE prestige_titles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES users(id),
    title TEXT NOT NULL,           -- 'rising_talent', 'area_star', etc.
    title_ta TEXT NOT NULL,        -- Tamil name
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    awarded_by TEXT NOT NULL,      -- 'community_council' | 'system'
    council_notes TEXT,            -- why the council voted yes
    is_current BOOLEAN DEFAULT true
);

-- Rivalries
CREATE TABLE rivalries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_a UUID REFERENCES users(id),
    member_b UUID REFERENCES users(id),
    started_at TIMESTAMPTZ NOT NULL,
    last_game_at TIMESTAMPTZ,
    total_games INT DEFAULT 0,
    a_wins INT DEFAULT 0,
    b_wins INT DEFAULT 0,
    rival_name TEXT,               -- "The Marthandam Duel"
    current_narrative TEXT,        -- AI-generated; refreshed after each game
    current_narrative_ta TEXT,
    biggest_moment_game_id UUID,   -- reference to game that defined this rivalry
    is_active BOOLEAN DEFAULT true,
    UNIQUE(member_a, member_b)
);

-- Rivalry key moments
CREATE TABLE rivalry_moments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rivalry_id UUID REFERENCES rivalries(id),
    game_id UUID,                  -- foreign key to game table
    moment_type TEXT NOT NULL,     -- 'upset', 'comeback', 'streak_ender', 'longest_game'
    description TEXT,
    description_ta TEXT,
    witness_count INT DEFAULT 0,
    occurred_at TIMESTAMPTZ NOT NULL
);

-- Reputation graph events (append-only; graph is computed from these)
CREATE TABLE reputation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES users(id),
    dimension TEXT NOT NULL,       -- 'skill', 'trust', 'contribution', 'consistency', 'leadership', 'prestige'
    delta NUMERIC NOT NULL,        -- positive or negative change
    reason TEXT NOT NULL,          -- human-readable reason
    source_type TEXT NOT NULL,     -- 'game', 'mentorship', 'event', 'award', 'council'
    source_id UUID,                -- id of the source entity
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Weekly recognition awards
CREATE TABLE recognition_awards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES users(id),
    award_type TEXT NOT NULL,      -- 'most_improved', 'biggest_comeback', etc.
    week_start DATE NOT NULL,
    announcement_text TEXT,        -- AI-generated story
    announcement_ta TEXT,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(award_type, week_start)
);

-- Daily spotlight
CREATE TABLE spotlight_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES users(id),
    spotlight_date DATE NOT NULL UNIQUE,
    trigger_type TEXT NOT NULL,    -- 'comeback', 'rivalry_start', 'mentee_win', etc.
    card_text TEXT NOT NULL,       -- AI-generated copy
    card_text_ta TEXT NOT NULL,
    card_image_url TEXT,           -- generated image URL
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Digital legacy events (append-only)
CREATE TABLE legacy_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES users(id),
    event_type TEXT NOT NULL,      -- 'first_game', 'first_win', 'title_earned', 'rivalry_started', 'award_won', etc.
    chapter TEXT NOT NULL,         -- 'beginning', 'growth', 'rivalries', 'community', 'era'
    headline TEXT NOT NULL,        -- one-sentence summary
    detail TEXT,                   -- longer narrative text
    detail_ta TEXT,
    occurred_at TIMESTAMPTZ NOT NULL,
    source_type TEXT,
    source_id UUID,
    metadata JSONB                 -- flexible storage for event-specific data
);

-- Area narratives (cached, daily)
CREATE TABLE area_narratives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    area_name TEXT NOT NULL,
    narrative_date DATE NOT NULL,
    prestige_rank INT,
    narrative_text TEXT NOT NULL,
    narrative_ta TEXT NOT NULL,
    hot_members JSONB,             -- [{id, name, reason}]
    active_rivalries JSONB,
    generated_at TIMESTAMPTZ NOT NULL,
    UNIQUE(area_name, narrative_date)
);

-- AI Legends
CREATE TABLE ai_legends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES users(id),
    legend_name TEXT NOT NULL,
    title_at_immortalization TEXT,
    active_period_start DATE,
    active_period_end DATE,
    games_played INT,
    style_profile JSONB NOT NULL,  -- captured playing style parameters
    model_weights_url TEXT,        -- S3/storage reference to trained model
    biography TEXT,
    biography_ta TEXT,
    challenge_count INT DEFAULT 0, -- how many times challenged by others
    approved_by_council BOOLEAN DEFAULT false,
    immortalized_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mentorship tracking
CREATE TABLE mentorships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mentor_id UUID REFERENCES users(id),
    mentee_id UUID REFERENCES users(id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    sessions_count INT DEFAULT 0,
    mentee_improvement NUMERIC,    -- delta in skill score since mentorship start
    notes TEXT
);

-- Area challenges
CREATE TABLE area_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenger_area TEXT NOT NULL,
    challenged_area TEXT NOT NULL,
    format TEXT DEFAULT '5_game_team',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    challenger_wins INT DEFAULT 0,
    challenged_wins INT DEFAULT 0,
    status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'in_progress', 'completed', 'declined'
    narrative TEXT,
    narrative_ta TEXT
);
```

---

## 14. Phased Roadmap

### Phase 0 — Foundation (Weeks 1–3)
Chess infrastructure must be stable before prestige layers can mean anything.

- [ ] Game recording: every game result stored with timestamp, players, result, duration
- [ ] Glicko-2 rating computation (background task after each game)
- [ ] Mentorship declaration: member can link to their mentor
- [ ] Area assignment: member declares their area/village on registration
- [ ] Basic legacy events: first_game, first_win, first_loss recorded automatically

**Definition of done**: every game played creates records that the prestige system can reason about.

---

### Phase 1 — Prestige Core (Weeks 4–6)
The identity layer.

- [ ] `prestige_engine.py`: score member eligibility for each title
- [ ] Community Council queue: surface candidates in admin panel for council review
- [ ] Title awarded: stored, displayed on game cards, profile, and all match announcements
- [ ] Title timeline in profile: "Rising Talent (Oct 2024) → Area Star (Mar 2025)"
- [ ] Reputation graph computation: six dimensions, updated weekly
- [ ] Reputation graph visualization: hexagonal radar on profile

**Definition of done**: every active member has a title and a visible reputation shape.

---

### Phase 2 — Rivalries (Weeks 7–9)
The emotional core.

- [ ] `rivalry_engine.py`: detect rivalry conditions from game history
- [ ] Auto-create Rivalry Card when threshold met
- [ ] Claude generates initial narrative text (Tamil + English)
- [ ] Rivalry Card page: full head-to-head history, narrative, biggest moment
- [ ] Narrative refresh: auto-update after each game between rivals
- [ ] Rivalry notifications: challenge, gap closing, streak, inactivity
- [ ] Rivalry Card shareable image (PNG export)

**Definition of done**: every pair of members with 20+ competitive games has a named rivalry with a story.

---

### Phase 3 — Recognition (Weeks 10–12)
The weekly rhythm of acknowledgment.

- [ ] `recognition_engine.py`: compute award nominations algorithmically
- [ ] Admin review interface: council confirms or overrides
- [ ] Award announcement generator: Claude writes the story
- [ ] Award published Friday evening via push notification + WhatsApp
- [ ] Award archived permanently in winner's legacy
- [ ] Daily Spotlight: `spotlight_engine.py` selects trigger, Claude writes card
- [ ] Spotlight shareable image (PNG generation)
- [ ] Push notification to spotlighted member

**Definition of done**: every week, 7 members are publicly recognized with named, story-based awards.

---

### Phase 4 — Digital Legacy (Weeks 13–15)
Making history tangible.

- [ ] `legacy_builder.py`: append-only event recorder for all major moments
- [ ] Legacy page UI: chapters, timeline, narrative arcs
- [ ] Legacy event types: all game milestones, titles, awards, spotlights, mentorships, witnessed games
- [ ] Era context: cohort data, club-level milestones during a member's tenure
- [ ] "Welcome back" legacy retrieval when returning after 30+ days
- [ ] Legacy shareable card: "My FYC Journey — 2 years, 847 games, Club Champion"

**Definition of done**: any member who has been active 6+ months has a meaningful, shareable legacy story.

---

### Phase 5 — Village Pride & Community Loops (Weeks 16–18)
The collective identity layer.

- [ ] Area dashboard: narrative update, prestige rank, hot players, active rivalries
- [ ] `area_narrative.py`: daily narrative generation per area
- [ ] Area vs. Area challenges: issue, accept, track, resolve, narrate
- [ ] Community Architect path: event hosting prestige credits
- [ ] Chronicler path: prediction system, commentary visibility
- [ ] Spectator-Supporter path: witness tracking on big games
- [ ] Mentorship chain visibility: "trained by → trained by →" lineage visible on profiles

**Definition of done**: areas feel like teams with identities; non-players have visible, named prestige paths.

---

### Phase 6 — AI Legends (Weeks 19–24)
The community becomes permanent.

- [ ] Legend eligibility threshold check
- [ ] Community Council immortalization vote
- [ ] Style profile capture from game history
- [ ] Legend Challenge interface: play against historical members
- [ ] Legend biography (Claude-generated from legacy data)
- [ ] Mentorship chain preservation: legends' training lineage visible forever
- [ ] Legend gallery: all legends displayed with their era, record, and biography

**Definition of done**: FYC members who left years ago are still present as challengeable legends with full biographies.

---

### Phase 7 — Tamil Identity Layer (Parallel to all phases)
Not a phase — a layer applied throughout.

- [ ] All generated text bilingual (Tamil primary, English available)
- [ ] Tamil expressions trigger on appropriate game moments
- [ ] Push notifications in Tamil by default
- [ ] Area names and tournament names use local Tamil geography
- [ ] Celebration animations and sounds reflect local sensibility
- [ ] Tamil calendar awareness for event timing

---

## 15. Design Principles & Anti-Patterns

### Principles

**1. Recognition is the product, not the feature.**
Every mechanic exists to make members feel seen. If a feature doesn't contribute to someone feeling recognized, deprioritize it.

**2. Stories over scores.**
A score is dead data. A story creates identity, motivates others, and spreads organically.

**3. Human + AI, not AI instead of humans.**
The algorithm nominates; the community confirms. This keeps legitimacy. An AI-only system can be gamed; a human-only system can't scale. Use both.

**4. Permanence creates dignity.**
Legacy data is append-only. History matters. What a member built here is not temporary.

**5. Multiple paths to status.**
The best chess player cannot be the only recognized person. Mentors, organizers, chroniclers, supporters — all have named paths to community prestige.

**6. Tamil first.**
This is a Kanyakumari community. The local energy, language, and identity are the source of its power, not an accessibility feature.

### Anti-patterns to avoid

**Never do this:**
- [ ] Daily streaks that punish absence ("You lost your 30-day streak!")
- [ ] Global leaderboards without narrative context (just numbers in rank order)
- [ ] Removing past achievements or resetting history
- [ ] Prestige paths only accessible to skilled players
- [ ] Corporate, sanitized celebration language ("Achievement unlocked!")
- [ ] Numbers-first reputation display (show shape, not digits)
- [ ] Notifications that report metrics ("You're in the top 40%")
- [ ] Comparing members directly without context ("Varun is better than Arjun")
- [ ] Making AI the final authority on community recognition (humans must confirm)
- [ ] Content in English only

---

*This document is a living plan. Update it as the community's needs evolve.*
*Last updated: June 2026*
*Next review: After Phase 2 launch — adjust based on what rivalries actually emerge.*
