# A chess tournament, stage by stage

Every screen a tournament passes through, photographed from the real widget
tree (`test/features/chess_tournament/tournament_render_harness.dart`, shots
`40`–`48` in `build/ui_shots/`), with the backend read alongside it.

Fixtures are written against `app/schemas/chess_tournament.py` rather than
invented, so what these pictures show is the shape the server actually sends.

Eight players, three rounds — quarter-finals, semi-finals, final.

---

## The stages, and what each one shows

| # | Stage | Screen | Verdict |
|---|---|---|---|
| 40 | The tournament list | `ChessTournamentListScreen` | works |
| 41 | Created, nobody joined | detail | works |
| 42 | Joining · approvals | detail + approvals card | works, thin |
| 43 | A player waiting to be let in | detail | works |
| 44 | Closed, ready to start | detail | works |
| 45 | Round 1 in play | bracket | **broken in three ways** |
| 46 | Between rounds | bracket + Start Semi-finals | works, same bracket faults |
| 47 | Semi-finals, one played in person | bracket | **shows the quarter-finals** |
| 48 | Champion | champion banner + bracket | works |

---

## 1 · Create and list  ✅

`POST /chess/tournaments` takes a name, description, deadline and a time
control that applies to **every** match in the event. The list marks each one
Live / Registration Open / Completed with a player count. Nothing wrong here.

## 2 · Registration and approval  ⚠️

`POST /{id}/register` puts a player in as `PENDING`; the manager approves or
rejects. Only `APPROVED` players enter the bracket, and the card says so.

**What is missing:**

- **The deadline is never shown.** `registration_deadline` is set at creation,
  returned by the API, parsed into `ChessTournament.registrationDeadline` — and
  rendered nowhere in either screen. The one fact a member needs while
  registration is open ("how long have I got?") is carried all the way to the
  device and dropped.
- **Approvals are a name and two buttons.** No photo, no rating, no "member
  since". An organiser approving eight strangers has nothing to go on.
- **Nothing says how many players make a clean draw.** 5, 6 or 7 approvals all
  produce byes; the screen never mentions it, so the organiser finds out when
  the bracket appears.

## 3 · Start  ⚠️ and one trap

Shot `44`: **8 approved · Registration closed**, with **Start Tournament & Draw
Bracket** and **Reopen Registration**. The controls are right and the wording
is plain.

**What is missing:** the roster. `_approvalsCard` only renders when there are
*pending* entries, so at the moment the organiser presses the irreversible
"draw the bracket" button, the eight people about to be drawn are nowhere on
the screen. `entries` is in the payload — an approved list is a few lines away
and would let somebody check the draw is the draw they meant.


`POST /{id}/start` shuffles, rounds up to the next power of two, creates every
match for every round, and seeds round 1 **front-against-back so byes face real
players** — correct. Byes auto-advance. Round 1 activates; everyone is pushed a
notification.

**The trap:** the endpoint takes an optimistic lock by writing
`status = "STARTING_LOCK"`. If anything after that raises before the commit,
the tournament is stranded in a status that is in no enum, that the app's
`isOpen / isClosed / inProgress / isCompleted` all answer false to — so the
screen renders a title, a description and nothing else — and that no endpoint
can clear. There is no recovery path.

## 4 · Rounds and results  ❌ this is where it falls down

### 4a. The screen shows the past and hides the present

The bracket is a horizontal `Row` of rounds — 280 px per column plus 60 px of
gap — inside a **fixed 600 px-tall box** with an `InteractiveViewer`. It always
starts at round 1, on the left.

On a 390 px phone that means one column is visible. As the tournament
progresses the live round moves *further off-screen to the right*, while the
finished first round stays permanently in view.

Shot `47` is the proof: the semi-finals are live, one of them is being played
in person at the club hall — and the screen shows the **quarter-finals**,
pixel-identical to shot `46`. At the final it will still be showing the
quarter-finals.

The code knows:

> `// We could use a TransformationController to auto-focus on t.currentRound here`

### 4b. A player's own match is buried in a pannable canvas

`_matchCard` — which carries **Ready**, **Play**, the walkover claim, the venue
and the reporting time for a physical match — is rendered *inside* the bracket
graph. To mark ready for your own game you must pan a diagram until you find
your name.

There is no "your match" surface anywhere. It is the single most important
action in the feature and it has no home.

### 4c. A live game looks like every other card

In shot `45` one match is `LIVE` with a linked Arena game. It is
indistinguishable from the two `READY` ones beside it: no live dot, no clock,
no "watch" affordance. The most interesting thing in the tournament — a game
happening right now — is invisible.

Also in that shot: cells are 180 px tall for ~60 px of content, so every card
floats in a large empty box; and the winner's crown renders as a tofu box
because it is the literal `'👑'` (same class of bug as the SOS `🆘`, and the
champion banner's `'🏆'` will do it too).

### 4d. A draw parks the match forever

`_auto_resolve` advances on `white_wins` and `black_wins`. A draw is skipped:

> `# draws are left LIVE — a replay/decider is needed (admin can report).`

There is no replay endpoint, no tiebreak, no armageddon, and the organiser's
only controls are **Win: A** and **Win: B**. In a knockout, a drawn game leaves
the match `LIVE` indefinitely and the round can never finish — `next-round`
refuses while anything is undecided. Draws are common in chess. This will
happen.

## 5 · One round to the next  ✅

`POST /{id}/next-round` refuses until every match in the current round is
decided, then activates the next and pushes each newly-paired player *"Your
next match is ready"*. The button reads **Start Semi-finals** / **Start Final**
by name, and greys to *"Waiting for round to finish"* until it is allowed —
that part is genuinely good (shots `45`, `46`).

## 6 · No-shows  ✅

A present, ready player can claim a walkover once the opponent has failed to
mark ready within `CHESS_READY_TIMEOUT_MINUTES` of the round being activated.
It is audited, and the absent player is told why they forfeited. Good design,
and it is the thing that stops one no-show stalling a whole afternoon — but it
lives inside the same buried match card.

## 7 · Conclusion  ✅

`_advance` with no next round sets the champion and `COMPLETED`, congratulates
the winner and tells the organiser. The detail screen leads with a gold
champion banner.

**Missing:** a runner-up, a final scoreline, a "played on" date, and any way to
share the result. `short_code` exists on the model for a telecast link
(`…/t/K7P2`) and is returned by the API — and is never shown in the app, so
nobody can share a tournament with anybody.

---

## What to fix, in order

1. **Open the bracket on the live round.** A `TransformationController` scrolled
   to `currentRound`. One screen, biggest single win.
2. **Give a player their own match.** A card above the bracket: your opponent,
   the round, Ready / Play / claim-walkover, and for a physical match the venue
   and the time. The bracket becomes the overview it should be.
3. **Handle draws.** Either a replay match or an organiser "Draw → replay /
   decide on tiebreak" control. Until then a single drawn game can stall an
   event.
4. **Mark the live match.** A dot and a "watch" link; the telecast already
   exists.
5. **Show the deadline**, on the list and the detail card.
6. **Clear `STARTING_LOCK`.** Either a recovery endpoint or a `try/except` that
   restores the previous status.
7. **Draw the crown and the trophy** instead of relying on emoji.
8. **Surface `short_code`** so a tournament can be shared.
