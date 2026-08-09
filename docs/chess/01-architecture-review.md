# Is the tournament feature built properly?

Short answer: **the backend is. The mobile feature is the only one in the app
that skipped the architecture, and the screen is built on the wrong analogy.**

Those are two separate faults and they need separate fixes.

---

## 1 · The mobile feature is the odd one out

Every feature in this app is `data/ domain/ presentation/` with a repository
and a bloc. Except one.

```
blood_donation     data domain presentation
complaint_box      data domain presentation
safety             data domain presentation
work               data domain presentation
issues             data domain presentation
events             data domain presentation
chess_tournament   chess_tournament_api.dart
                   chess_tournament_detail_screen.dart
                   chess_tournament_list_screen.dart
                   chess_tournament_models.dart
```

Four flat files. No domain layer, no repository, no bloc. `ChessTournamentApi`
is a class of `static` methods reaching into the service locator for a Dio, and
the screen is a 705-line `State` driving itself with `setState`.

The consequence is not aesthetic. It is that **there was no seam to test
against**, so there were no tests — and today, to photograph the screens at
all, the two widgets needed a `preload` parameter added before a test could
hand them data. Every defect found this week was in this layer.

## 2 · The backend is fine, and the tests prove it

The opposite is true on the server:

```
backend/tests/  test_chess_tournaments.py
                test_tournament_full_flow.py
                test_tournament_fixes.py
                test_chess_tournament_time_control.py
                test_seed_tournament_results.py
```

The state machine is sound. Byes are seeded front-against-back so they face
real players. `next-round` refuses while anything is undecided. The walkover
has a timeout anchor and an audit row. Every transition notifies the people it
affects. This is careful work.

It has one shape problem: `routers/chess_tournaments.py` is **1083 lines**, the
largest router in the codebase, with `_advance`, `_auto_resolve`, `_serialize`,
`_notify` and `_audit` living inside it. Compare the two features built since:

| feature | router | domain services |
|---|---|---|
| Complaint Box | 516 | `complaint_routing`, `complaint_workflow`, `complaint_letter` |
| SOS | 902 | `sos_dispatch`, `sos_escalation` |
| Tournament | **1083** | *(none — `chess_reaper` and `chess_ws_manager` serve the game, not the event)* |

That is worth fixing, but it is **not** why the app feels wrong. The logic is
correct; it is just in the wrong file.

## 3 · The real fault: the bracket is being used as the control panel

This is the part that no amount of layering would fix, and it is the answer to
"is the analogy right".

**A bracket is a scoreboard.** It is for spectators, and for the wall afterwards.
It is not how anybody *runs* a tournament — and this app made it the only
surface, then hid every control inside it.

A tournament is not a diagram. Structurally it is a **round-based queue with a
blocking join**: everyone in the event is waiting on the slowest match in the
current round. That shape implies three different jobs, and therefore three
different surfaces:

| who | their question | what they need |
|---|---|---|
| **Player** | *what do I do next?* | one card: my opponent, my clock, Ready / Play — or, for a physical match, where and when to turn up |
| **Organiser** | *what is blocking this round?* | a worklist of undecided matches, each with the one action that unblocks it |
| **Everyone else** | *how is it going?* | the bracket, read-only |

Every serious tournament system splits exactly this way — Lichess puts your
next game at the top and the standings below; Challonge gives the organiser a
list of open matches with result entry and keeps the bracket as a view;
chess-results separates this round's pairings from the crosstable.

FYC built only the third surface and pushed the other two inside it. That is
why:

- the screen shows the quarter-finals while the semi-finals are being played —
  a scoreboard has no opinion about which round matters *now*;
- a player pans a diagram to find their own name before they can press Ready;
- the organiser's result buttons are 340 px off the right edge by round two;
- and a completed tournament does not show you the final.

None of those are bugs in the ordinary sense. They are the same modelling
mistake, seen from four angles.

## 4 · What to build

Not a port of the Complaint Box. The correct shape here is its own:

1. **`TournamentBloc` over a `TournamentRepository`** — same discipline as the
   rest of the app, so the thing becomes testable. No new pattern, just the
   one this codebase already uses everywhere else.
2. **Three surfaces instead of one**, chosen by role and by tournament state:
   - `MyMatchCard` — the player's next action, at the top, always.
   - `RoundBoard` — the organiser's worklist for the current round: who is
     undecided and the button that decides them.
   - `BracketView` — the diagram, read-only, opened deliberately, and scrolled
     to the live round when it is.
3. **Move the event logic into `services/tournament_flow.py`** — `_advance`,
   `_auto_resolve`, seeding, round gating — so the router does HTTP and the
   service does chess.
4. **Then** the specific gaps from the walkthrough: draws, the deadline, the
   share code, `STARTING_LOCK`, the approved roster before the draw.

Steps 1 and 2 are what make it stop feeling wrong. Step 3 is hygiene. Step 4 is
the list.
