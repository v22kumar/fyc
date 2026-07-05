# How to Conduct a Tournament (Organizer Runbook)

This is the operational guide for running a tournament in FYC Connect, end to
end. It covers the two tournament types the app supports today, who does what,
and the exact steps — plus current limits and best practices.

> **Who can organize:** a Club Official / Admin (exec role). Regular members can
> only **register and play**, not create or start tournaments.

---

## 1. The two tournament types

| | **Chess Tournament** | **Sports Tournament** (cricket, etc.) |
|---|---|---|
| Participants | Individual members | Teams |
| Format | Single-elimination **knockout bracket** (auto-generated) | Fixtures / matches with standings |
| Registration | Member taps **Register to Play** | A member registers a **team** |
| Scoring | Winner reported per match → bracket advances | Live ball-by-ball / score entry → standings |
| Where | Play → Chess Arena → **Tournaments** | Play (Sports) tab → tournament |

Both share the same lifecycle:

```
DRAFT/OPEN → REGISTRATION_OPEN → (deadline) → IN_PROGRESS → COMPLETED
```

---

## 2. Chess tournament — step by step

**A. Create it** *(organizer)*
1. Play tab → **Chess Arena** → **Tournaments** → **+ Create**.
2. Enter a **name**, an optional description, and a **registration deadline**.
3. On save the tournament opens in **Registration Open**.

**B. Registration window** *(members)*
- Members open the tournament and tap **Register to Play**.
- Registration is blocked automatically once the **deadline passes** (or if the
  tournament has already started). Members see **"You're registered"** after
  joining. Registering twice is safe (idempotent — no duplicates).
- Announce the tournament so members know to register (see §5).

**C. Start it — this generates the bracket** *(organizer)*
1. After the deadline, open the tournament. You need **at least 2 registered
   players**.
2. Tap **Start Tournament**. The app then automatically:
   - shuffles the registered players,
   - builds a single-elimination bracket sized to the next power of two,
   - gives **byes** to the top seeds when the count isn't a power of two (a bye
     auto-advances that player to round 2),
   - creates every round's matches and seeds round 1.
3. Status moves to **In Progress**. **No more registrations** are accepted.

**D. Play the matches** *(players)*
- Each round-1 match shows the two players and a **Play** button, which opens an
  online chess game between them.
- After a game finishes, the result is recorded for that match (see D-note).

> **Semi-final & final — App or In Person (organizer choice).** On the last two
> rounds (semi-final and final), the organizer sees a **Conduct: In App / In
> Person** toggle on each match:
> - **In App** — the two players play the online Arena game as usual.
> - **In Person** — the match is played physically (at a venue, on a real
>   board); there is **no Play button** for players, and the **organizer records
>   the winner** on the match. Use this for a final held on stage / at an event.

> **D-note (current limitation):** the match result is **reported** on the
> tournament screen ("Player A won" / "Player B won"), not yet auto-pulled from
> the played game. Keep this honest and simple: the organizer (or the players by
> agreement) reports the winner. Auto-scoring from the live game is a planned
> improvement.

**E. Advancing & the champion** *(automatic)*
- Reporting a winner advances them to the next round automatically.
- When the final match is decided, the tournament moves to **Completed** and the
  winner is the champion.

---

## 3. Sports tournament — step by step

**A. Create it** *(organizer)* — Play (Sports) tab → **Create Tournament**: name,
sport, and the **registration close** date.

**B. Team registration** *(members)* — members register a **team** (name +
players) while registration is open.

**C. Close registration & generate fixtures** *(organizer)* — fixtures/matches
can only be created **after registration closes** (this is enforced — you cannot
schedule matches while teams can still join, which would corrupt the draw).

**D. Run the matches** *(organizer / scorer)* — enter scores live (ball-by-ball
for cricket); results update **team standings** (wins, points) automatically and
notify members that a match concluded.

**E. Standings & completion** — the tournament page shows live standings; mark it
complete when the final is played.

---

## 4. The lifecycle at a glance

| State | What it means | Who can act |
|---|---|---|
| **Registration Open** | Accepting players/teams | Members register |
| *(deadline passes)* | No new registrations | — |
| **In Progress** | Bracket/fixtures live, being played | Players play, organizer reports |
| **Completed** | Champion decided | Read-only record |

---

## 5. Best practices for a clean tournament

1. **Set a realistic deadline** — give members enough days to register; don't
   start the same day you announce.
2. **Announce it** — post an Announcement and let the notification reach members
   ("Registration open until …"). A tournament nobody knows about gets 2 entries.
3. **Confirm the field before starting** — check the registered count; for chess
   you need ≥2, but a real event wants 4, 8, or 16 for a clean bracket (fewer
   byes = fairer).
4. **Start only after the deadline** — starting locks registration; don't start
   while people still expect to join.
5. **Report results promptly** — the bracket only advances when winners are
   reported, so a stalled report stalls the whole round.
6. **One organizer owns it** — avoid two officials starting/reporting the same
   tournament simultaneously.

---

## 6. Current capabilities & honest limitations

**Works today:** create, deadline-gated registration, auto-bracket generation
with byes, round-by-round advancement, champion, and (for sports) team
registration + live scoring + standings.

**Known limitations (and the plan):**
- **Chess is knockout-only.** No round-robin or Swiss yet. Fine for a single
  champion; add formats when league-style play is needed.
- **Results are reported, not auto-scored** from the played game. Plan: derive
  the match result from the online game so no manual reporting is needed.
- **No seeding by rating.** Pairings are random. Plan: seed by Glicko/rating once
  ratings are live so strong players don't meet in round 1.
- **No capacity cap / explicit "close registration" button.** Registration is
  bounded only by the deadline. Plan: add an optional max-players cap and a
  one-tap "Close registration now" for organizers.
- **Discoverability.** Tournaments should be first-class in the Play tab, not
  buried under Chess Arena. (Being addressed.)

---

*Owner: this runbook is kept in sync with the tournament flow. If the flow
changes, update this file in the same PR.*
