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
- Members open the tournament and tap **Register to Play**. They land in
  **"Waiting for approval"** — registering does not yet put them in the bracket.
- Registration is blocked automatically once the **deadline passes**, once the
  organizer **closes registration**, or once the tournament has started.
  Registering twice is safe (idempotent — no duplicates).
- Announce the tournament so members know to register (see §5).

**C. Approve players** *(organizer)*
- Each pending registration appears in the **Pending approvals** panel with
  **Approve** / **Reject** buttons. Only **approved** players enter the bracket;
  the approved / pending counts are shown at the top of the card.
- Approving or rejecting notifies that player.

**D. Close registration, then start** *(organizer)*
1. Tap **Close Registration** when you're done accepting players (independent of
   any deadline). You can **Reopen** if you closed too early.
2. Tap **Start Tournament & Draw Bracket**. You need **at least 2 approved
   players**. The app then automatically:
   - shuffles the approved players,
   - builds a single-elimination bracket sized to the next power of two,
   - gives **byes** where the count isn't a power of two (a bye auto-advances
     that player to round 2) — byes are assigned by the random draw, **not** by
     who registered or got ready first, so it's fair,
   - creates every round's matches, seeds round 1 and **activates round 1**.
3. Status moves to **In Progress** and every approved player is **notified the
   tournament has started**.

**E. Play the matches** *(players)*
- A match only becomes playable once its **round is started** (round 1 starts
  automatically; later rounds are started manually — see F).
- Each player taps **I'm Ready**; once **both** players are ready the **Play
  Your Match** button opens the online game. This "ready" gate stops one player
  opening a board the other isn't at.
- After a game finishes, the result is recorded for that match (see note).

> **Semi-final & final — App or In Person (organizer choice).** On the last two
> rounds (semi-final and final), the organizer sees a **Conduct: In App / In
> Person** toggle on each match:
> - **In App** — the two players play the online Arena game as usual.
> - **In Person** — the match is played physically (at a venue, on a real
>   board); there is **no Play button** for players, and the **organizer records
>   the winner** on the match. Use this for a final held on stage / at an event.

> **In-person logistics.** When you switch a match to **In Person** you can
> attach a **venue** (e.g. "FYC Club Hall"); both players are notified where to
> report and that the match is being played physically.

> **Note — auto-scoring:** for **In App** matches, when the online game ends
> with a decisive result the winner is **recorded automatically** and the
> **organizer is notified** — no manual report needed. The organizer's "Win:
> Player A / Win: Player B" buttons remain as an **override** and are the way to
> record **In Person** results and to break a **draw** (a knockout can't advance
> on a draw).

**F. Start each round & crown the champion** *(organizer)*
- Recording a winner fills the next-round slot but **does not** start the next
  round — you control the pace. When every match in the current round is decided,
  the **Start [Next Round]** button activates and notifies the next round's
  players. (Rounds not yet started show a **Not started** badge.)
- When the final match is decided, the tournament moves to **Completed**, the
  winner is crowned **champion**, and both the champion and organizer are notified.

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
| **Registration Open** | Accepting players/teams | Members register (chess: land in *pending*); organizer approves/rejects |
| **Registration Closed** *(chess)* | Locked list, no new sign-ups | Organizer approves remaining, then starts (or reopens) |
| *(deadline passes)* | No new registrations | — |
| **In Progress** | Bracket live; organizer starts each round | Players ready + play, organizer reports & starts rounds |
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
4. **Approve, then close, then start** — approve the players you want, tap
   **Close Registration** so no one else joins, then **Start**. Don't start while
   people still expect to join.
5. **Drive the rounds** — winners are recorded automatically, but the next round
   only begins when you tap **Start [Next Round]**. Kick it off once the current
   round is fully decided so players aren't left waiting.
6. **One organizer owns it** — avoid two officials starting/reporting the same
   tournament simultaneously.

---

## 6. Current capabilities & honest limitations

**Works today:** create → deadline **or** manual-close registration →
**approve/reject** each player → draw bracket (byes handled fairly by the random
draw) → **round-by-round** advancement the organizer controls → per-player
**Ready** gate → auto-scored in-app games with organizer notifications →
**In App / In Person** conduct for SF/final (with venue) → champion. Push
notifications fire at start, on approval, when a round opens, and when a match or
the tournament is decided. Sports adds team registration + live scoring +
standings.

**Known limitations (and the plan):**
- **Chess is knockout-only.** No round-robin or Swiss yet. Fine for a single
  champion; add formats when league-style play is needed.
- **Draws & in-person still need a manual report.** In-app games auto-score
  (decisive results advance the bracket automatically); draws and physical
  matches are recorded by the organizer.
- **No seeding by rating.** Pairings are random (which is what keeps byes fair).
  Plan: optional seed by Glicko/rating once ratings are live so strong players
  don't meet in round 1.
- **No capacity cap.** Registration is bounded by the deadline and manual close,
  but there's no max-players cap yet. Plan: add an optional max-players cap.
- **Discoverability.** Tournaments should be first-class in the Play tab, not
  buried under Chess Arena. (Being addressed.)

---

*Owner: this runbook is kept in sync with the tournament flow. If the flow
changes, update this file in the same PR.*
