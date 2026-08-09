# The rebuild — what was built, and why it holds

`00-tournament-walkthrough.md` photographed the feature broken;
`01-architecture-review.md` diagnosed why. This records what was built in
answer, so the next person changing the feature knows which walls are
load-bearing.

---

## Backend: the router does HTTP, the service does chess

`routers/chess_tournaments.py` went from 1083 lines to 936; the event logic
moved to `services/tournament_flow.py`:

- `draw_bracket` — shuffle, pad to the next power of two, pair byes
  front-against-back so free passes land on different seeds, activate round 1,
  auto-advance the byes.
- `advance` — winner into the next round's slot; champion when there is no
  next round.
- `auto_resolve` — a decisive Arena game advances the winner. A **drawn** game
  no longer stalls the event: the match is sent back to replay (game unlinked
  into the audit row, ready flags reset, both players notified). The
  organiser's result override remains the tiebreak of last resort.
- `undecided_in_round` — the single definition of "blocks the round", the same
  one the mobile domain mirrors.

`start_tournament` treats `STARTING_LOCK` itself as startable: if a start
crashes half-way, pressing Start again clears the half-made matches and
redraws, and a `try/except` restores the prior status. A stranded lock used
to brick the tournament permanently.

Pinned by `backend/tests/test_tournament_flow.py` (7 tests) on top of the
pre-existing five tournament test files (100 tests, all still green).

## Mobile: the FYC architecture, and a domain that answers questions

```
chess_tournament/
  data/         datasource → repository impl (wire parsing in models)
  domain/       entities + repository interface
  presentation/ bloc + 3 widgets + 2 screens
```

The rules live on the entities, not in widgets:

- `BracketMatch.actionFor(uid)` → ready / waitOpponent / play / resume /
  attendVenue / waitRound / none. "Which button do I show" **is** the
  rulebook, and it exists exactly once.
- `BracketMatch.colorFor(uid)` — seat A plays white, the server's rule.
- `TournamentDetail.myMatch / blocking / canStartNextRound / finalMatch /
  stillIn` — each surface asks; none computes.

`TournamentBloc` replaces the whole `TournamentDetail` with the server's
answer on every mutation — it never patches a local copy, so the three
surfaces cannot disagree with each other or with the server. Double-taps are
dropped synchronously in `add()` (a bloc queues events, so a busy-guard
inside a handler never sees the overlap). Failures carry the **server's
sentence** ("Please wait ~3 more minutes"), never "action failed". `Play`
emits a complete `BoardTicket` (game id + token + colour) once, then clears
it, so a rebuild cannot re-open the board. The token provider is injected by
the router — no widget touches the service locator.

## The three surfaces

| surface | question | shape |
|---|---|---|
| `MyMatchCard` | *what do I do next?* | first on screen, every `MatchAction` state has words; knocked-out says who beat you |
| `RoundBoard` | *what blocks this round?* | vertical worklist, `Win: {name}` buttons (explicit, never positional), Start-next-round when clear |
| `BracketView` | *how is it going?* | read-only, opens scrolled to the live round (the final, when completed), LIVE dot + winner trophy drawn, own name highlighted |

Which sections render is a function of domain state and role; the screen
computes no tournament rule.

## The tests are the walkthrough, replayed

`tournament_surfaces_test.dart` holds one named regression test per
photographed defect: Ready without the bracket, the worklist on screen, the
roster at the draw moment, the bracket scrolled to the semis, the completed
final with runner-up, LIVE visible, plus 1.3×-font pumps of every surface
(which caught a real 435 px overflow before any device did).
`tournament_bloc_test.dart` pins the replace-don't-patch contract, the
double-tap drop, the silent refresh failure, and the board ticket.
`tournament_domain_test.dart` pins the rulebook. The render harness
(`tournament_render_harness.dart`) re-photographs stages 50–58 from the same
wire fixtures through the real `detailFromJson`.

The seam that makes all of it possible is `FakeTournamentRepository` — the
old code needed `@visibleForTesting preload` parameters bolted onto
production widgets; the new code is tested through the same interface the
app runs on.
