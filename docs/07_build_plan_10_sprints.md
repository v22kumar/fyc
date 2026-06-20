# FYC Chess + Prestige Network — 10-Sprint Build Plan

> **Stack decision (recorded):** Flutter + `squares`/`bishop` + WebSocket + Stockfish.
> NOT Flame Engine. Chess is turn-based; Flame is a real-time action engine.
> Flame adds 4MB and solves 0% of our hardest problem (real-time multiplayer sync).
> See `06_community_prestige_network.md` for the prestige OS design.
>
> **Platform:** Android only.
> **Two-week sprints, ~20 weeks total.**
>
> Rule for every sprint: **ship something a member can feel.**
> No sprint ends "backend only, nothing visible."

---

## Sprint Map

| # | % | Theme | Ships |
|---|---|-------|-------|
| 1 | 0→15 | Chess Core — Local Game | Working board, legal moves, local 2-player |
| 2 | 15→25 | Backend Game Model | Games persisted, history, stats |
| 3 | 25→40 | Real-Time Multiplayer | Two phones, live game |
| 4 | 40→50 | Clocks + Match Management | Time controls, lobby, resign/draw/flag |
| 5 | 50→60 | Spectator Mode | Watch live games, witness count |
| 6 | 60→70 | AI Opponent (Stockfish) | Practice vs computer, difficulty levels |
| 7 | 70→78 | Replay & PGN | Replay any game move by move, share PGN |
| 8 | 78→88 | Prestige Integration | Glicko-2, titles on cards, rivalry detection |
| 9 | 88→95 | Recognition & Legacy | Weekly awards, spotlights, digital legacy |
| 10 | 95→100 | AI Legends + Polish | Historical player bots, Tamil voice, APK hardening |

---

## Sprint 1 — Chess Core: Local Game (0 → 15%)

**Goal:** A fully working chess game on one device. No multiplayer, no server.
The board must feel polished. This is the foundation everything else runs on.

**Stack:**
- `squares: ^5.0.0` — board widget, drag/drop, animations, piece images
- `bishop: ^5.0.0` — full chess rules (moves, castling, en-passant, promotion, check/mate)
- BLoC for game state

**Work items**
- [ ] Add `squares`, `bishop` to `pubspec.yaml`
- [ ] `features/chess/` clean-arch structure (domain / data / presentation)
- [ ] `GameBloc` with events: StartGame, MakeMove, OfferDraw, Resign, NewGame
- [ ] `GameState`: position (FEN), turn, moveHistory, capturedPieces, status
- [ ] `ChessHomePage` — mode selector: Local Game / vs AI / Online (online greyed-out for now)
- [ ] `LocalGamePage` — full game UI:
  - `BoardWidget` (squares) with Merida piece set
  - Legal-move-only drag/drop (bishop validates)
  - Move highlighting (last move, legal destinations)
  - `PlayerInfoBar` (top + bottom: name, captured pieces)
  - `MoveHistoryPanel` (scrollable algebraic notation)
  - Check indicator, checkmate/stalemate dialog
  - New Game / Resign buttons
- [ ] Wire chess entry point into app router (`/chess`)
- [ ] Add Chess entry card to Home or Sports screen

**Exit demo:** Two people play a full game on one phone — legal moves only, check
highlighted, checkmate detected with result dialog.

**Definition of done:** Any FYC member can play a complete chess game locally.

---

## Sprint 2 — Backend Game Model (15 → 25%)

**Goal:** Every game is recorded on the server. History, stats, and prestige all
downstream from this. Nothing upstream.

**Backend work:**
- [ ] `games` table: id, white_id, black_id, org_id, result, pgn, started_at, ended_at, time_control, area_snapshot
- [ ] `game_moves` table: game_id, ply, uci, san, fen_after, clock_remaining, timestamp
- [ ] `GET /api/v1/chess/games` — list games (filter by player, org, date)
- [ ] `POST /api/v1/chess/games` — create game record
- [ ] `PATCH /api/v1/chess/games/{id}` — update result + PGN on completion
- [ ] `GET /api/v1/chess/games/{id}` — single game with moves
- [ ] `GET /api/v1/chess/players/{id}/stats` — games played, W/L/D, Glicko-2 (seed at 1500/350)

**Mobile work:**
- [ ] `ChessRemoteDataSource` — wraps all game endpoints
- [ ] Auto-submit completed local game to backend (fire-and-forget, no UX block)
- [ ] Game history screen: list of past games with result, opponent, date
- [ ] Player stats card on profile (games played, win rate)

**Exit demo:** Play a game locally → navigate to game history → the game appears with
correct result and move count.

**Definition of done:** Every completed game has a server record the prestige system can query.

---

## Sprint 3 — Real-Time Multiplayer (25 → 40%) ⭐ hardest sprint

**Goal:** Two phones, same game, live. Server-authoritative: clients send intended
moves; server validates and broadcasts.

**Backend work:**
- [ ] WebSocket endpoint: `WS /api/v1/chess/games/{id}/ws`
- [ ] Server-side move validation (use python-chess) before broadcast
- [ ] Game state machine: WAITING → IN_PROGRESS → ENDED
- [ ] `POST /api/v1/chess/challenge` — send challenge to another member (returns game_id)
- [ ] `POST /api/v1/chess/challenge/{id}/accept` / `/decline`
- [ ] Reconnection: client sends last known ply on reconnect, server sends diff

**Mobile work:**
- [ ] `ChessWebSocketClient` — connects/disconnects, parses messages, handles reconnect
- [ ] `OnlineGameBloc` — extends GameBloc with WebSocket stream
- [ ] Online game page: same UI as local but moves come from WS stream
- [ ] Challenge flow: search member → send challenge → push notification → accept screen
- [ ] Disconnect/reconnect handling with "Reconnecting…" overlay
- [ ] Result is sent to backend automatically on game end

**Exit demo:** Player A challenges Player B from two separate phones. They play a full
game live. An illegal move attempt is rejected by the server. Result auto-recorded.

**Definition of done:** Two members can play a real game on two real Android devices.

---

## Sprint 4 — Clocks + Match Management (40 → 50%)

**Goal:** Time controls, formal match lobby, full endgame handling.

**Work items:**
- [ ] Server-side clock: track remaining time per player, flag on expiry
- [ ] Clock variants: Bullet (1+0), Blitz (5+0, 3+2), Rapid (10+0), Classical (30+0)
- [ ] `ClockWidget` — animated countdown, red below 10s
- [ ] Lobby screen: active challenges, quick-match (same org, same time control)
- [ ] Resign flow with confirmation
- [ ] Draw offer → accept/decline with notification
- [ ] Flagging: if clock hits 0, server ends game, winner notified
- [ ] Rematch button on result screen
- [ ] Match history filterable by time control

**Exit demo:** Play a 3+2 blitz game. One player flags on time. Result correctly recorded
as "White wins on time." Rematch button works.

**Definition of done:** Full match lifecycle — from lobby to flag/resign/checkmate — works correctly.

---

## Sprint 5 — Spectator Mode (50 → 60%)

**Goal:** Community members can watch live games. Witnesses are named and remembered.

**Work items:**
- [ ] `WS /api/v1/chess/games/{id}/spectate` — read-only stream, same state as players
- [ ] Spectator board: same board widget, no move interaction, both clocks live
- [ ] Active games list: "X games happening right now" → tap to watch
- [ ] Spectator count badge on game screen (players see it too: "5 watching")
- [ ] Witness list stored in `games.spectator_ids` (appended as people join)
- [ ] "Game started" push to org members for high-prestige matchups (both players Area Star+)
- [ ] Spectator count + names written to legacy_events on game completion

**Exit demo:** A third phone joins an active game as spectator. Both players see "1 watching."
After game ends, the spectator's name appears in that game's record.

**Definition of done:** Community members can watch live; witnesses are permanently named.

---

## Sprint 6 — AI Opponent: Stockfish (60 → 70%)

**Goal:** Practice alone against a strong AI. Multiple difficulty levels.

**Work items:**
- [ ] Add `stockfish_chess_engine` to pubspec.yaml (native Stockfish via platform channel)
- [ ] `StockfishService` — init engine, send FEN+depth, parse best move
- [ ] Difficulty → depth mapping: Beginner (d3), Casual (d8), Club (d14), Strong (d20)
- [ ] `AIGameBloc` — after player move, call Stockfish, apply AI move with 400ms delay (feels natural)
- [ ] AI game page: same board UI + "Thinking…" indicator
- [ ] Undo move (vs AI only — not allowed in multiplayer)
- [ ] "Hint" button: Stockfish best move shown as arrow on board
- [ ] AI games recorded to backend as "vs_computer" type (excluded from Glicko-2 rating)

**Exit demo:** Start a game vs AI at "Club" difficulty. AI responds in under 1 second.
Hint button shows a move arrow. Undo works.

**Definition of done:** Members can practice against a strong AI at any difficulty.

---

## Sprint 7 — Replay & PGN (70 → 78%)

**Goal:** Any game, any time, move by move. The game becomes a record worth keeping.

**Work items:**
- [ ] PGN stored per game in backend (already in games table from S2)
- [ ] `ReplayBloc` — loads moves from backend, step forward/back/jump, controls speed
- [ ] Replay page: board + navigation controls (⏮ ⏴ ⏵ ⏭, play through auto)
- [ ] Move list highlights current position
- [ ] Clock time at each move shown
- [ ] Share PGN: copy to clipboard, share via WhatsApp
- [ ] "Key moment" markers: auto-flagged by engine (blunders, brilliant moves, turning points)
- [ ] Game links: deep link `fyc://chess/game/{id}` opens replay or live game

**Exit demo:** Open any past game from history → navigate move by move. Share the PGN
to WhatsApp. Deep link opens the game.

**Definition of done:** Every game is permanently replayable and shareable.

---

## Sprint 8 — Prestige Integration (78 → 88%)

**Goal:** Chess results feed the prestige OS. The game becomes meaningful beyond the result.

**Backend work:**
- [ ] Glicko-2 rating job: runs after every rated game, updates reputation_events (Skill dimension)
- [ ] Rivalry detection: `rivalry_engine.py` checks after each game — creates/updates rivalry cards
- [ ] Upset detection: lower-prestige player beats higher → rivalry_moment + reputation event
- [ ] Comeback detection: server stores material balance at each move → flags if losing side won
- [ ] Prestige title eligibility re-check: queue member for Community Council after rating milestones

**Mobile work:**
- [ ] Title badge on game result screen: "Club Champion VARUN beat Area Star ARJUN"
- [ ] Rivalry notification after game: "Your rivalry with Arjun now stands at 25–22"
- [ ] Rivalry card link on game result screen
- [ ] Rating delta shown post-game (+14 / -8)
- [ ] First game against a rival shows "Start of a rivalry?" if patterns match

**Exit demo:** Play a game where the lower-rated player wins. Rivalry card updates. Upset
moment is flagged. Both players see the rating delta.

**Definition of done:** Every game result flows into the prestige graph + rivalry engine.

---

## Sprint 9 — Recognition & Legacy (88 → 95%)

**Goal:** The Friday ritual + permanent history. The community celebrates and remembers.

**Work items:**
- [ ] Wire weekly recognition engine to chess game data (Most Improved, Biggest Comeback, Silent Assassin)
- [ ] Claude generates award announcement (Tamil + English) from game signals
- [ ] Friday push notification: award to winner + announcement to all org members
- [ ] Award screen + share button (PNG export)
- [ ] Legacy event writer wired to chess: first_game, first_win, first_rivalry, 100th_game, title_earned, award_won, spotlight
- [ ] Legacy page: Chapter 1 (Beginning) + Chapter 2 (Growth) + Chapter 3 (Rivalries) — chess data fills these
- [ ] Daily Spotlight triggered by game moments (comeback, upset, streak milestone)
- [ ] Spotlight push to member + shareable PNG

**Exit demo:** Run weekly recognition job on real game data → 3 chess-based awards fire
(Most Improved, Biggest Comeback, Silent Assassin). Winner gets push. Open the Legacy page
for a 2-month member — Chapter 1 and 2 are populated with real moments.

**Definition of done:** Chess results produce weekly recognition and permanent legacy chapters.

---

## Sprint 10 — AI Legends + Polish (95 → 100%)

**Goal:** The community becomes permanent. Then harden everything.

**Work items:**
- [ ] AI Legend eligibility check (200+ rated games, Area Star+, 6+ months, council vote)
- [ ] Style-profile capture from PGN history: opening repertoire, style fingerprint, pressure patterns
- [ ] Legend Challenge mode: play against a captured-style Stockfish configuration
- [ ] Legend biography generated by Claude from legacy data
- [ ] Legend gallery screen: all legends, their era, record, and biography
- [ ] Mentorship chain on legend page: "trained by → trained by →" visible forever
- [ ] **Polish pass:**
  - Tamil voice audit — every notification, celebration, result message in Tamil first
  - Performance: board renders at 60fps on mid-range Android (Redmi Note 11 class)
  - APK size: `flutter build apk --split-per-abi` → each ABI under 25MB
  - Accessibility: large-text mode, sufficient contrast on board squares
  - Offline graceful: no internet → can play vs AI, game syncs when back online
  - Anti-pattern audit: no punishing streak lost messages, no naked number leaderboards

**Exit demo:** Immortalize a seed veteran as a Legend. A new member opens Legend Gallery,
reads his biography, challenges "Legend Rajan," plays a game, sees the mentorship lineage.

**Definition of done:** The community prestige network passes the "if this member disappears
for 30 days, will people notice?" test on real data.

---

## Technical Decisions (locked)

| Decision | Choice | Rejected | Reason |
|----------|--------|----------|--------|
| Board UI | `squares` | Flame, CustomPainter | Fastest to ship; fully customizable; Flame is a real-time action engine, not a board game library |
| Chess rules | `bishop` | `chess` dart pkg | Same author as squares; seamless integration; full variant support |
| AI engine | `stockfish_chess_engine` | Leela, cloud API | Free, offline, runs on device, no cost per move |
| Move validation | Server (python-chess) | Client-only | Server-authoritative = anti-cheat; client validates for UX only |
| State management | BLoC | Riverpod, Provider | Already used everywhere in the app |
| Multiplayer | WebSocket (FastAPI) | Firebase RTDB, Supabase | Already on FastAPI; preserves verified-membership anti-cheat |
| Platform | Android only | Web | Simplifies build; APK already in CI |

## Cross-Cutting (every sprint)

- **Tamil first** — no screen ships English-only; audited every sprint, hardened in S10
- **Human-in-the-loop** — algorithm proposes; Community Council confirms titles/awards/legends
- **Server authoritative** — moves validated on server; client optimistic-updates for feel
- **AI off the hot path** — Claude calls batched/async/cached; never block a game move
- **Permanent records** — game data, legacy events, rivalry moments are append-only from creation
- **Shareability** — every recognition artifact exports a shareable PNG

---

*Living plan — update after each sprint exit demo. Never cut the exit demo; the member-facing
moment is the point.*
