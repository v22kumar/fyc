import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/cricket_match_state_entity.dart';
import '../../domain/repositories/sports_repository.dart';

abstract class CricketScoringState extends Equatable {
  const CricketScoringState();
  @override
  List<Object?> get props => [];
}

class CricketScoringInitial extends CricketScoringState {}

class CricketScoringLoading extends CricketScoringState {}

/// No CricketMatch exists for this fixture yet — show the toss/openers form.
class CricketScoringNotInitialized extends CricketScoringState {}

class CricketScoringLoaded extends CricketScoringState {
  final CricketMatchStateEntity matchState;

  /// The players for the NEXT ball. Null when unknown (e.g. the scorer
  /// re-opened the app mid-match) — the UI then asks to confirm players.
  final CricketPlayersEntity? players;

  /// Set right after an over completes: the next delivery needs a bowler
  /// choice before it can be scored.
  final bool needsNewBowler;

  /// Non-null when the last action failed but play can continue (shown as
  /// a snackbar; the scoreboard itself is still valid).
  final String? errorMessage;

  /// True while a ball is being posted. The scoreboard stays on screen (no
  /// full-screen spinner reload) and the pad shows a subtle saving hint —
  /// this is what makes ball entry feel instant.
  final bool submitting;

  /// A brand-new bowler the scorer picked at the over break (proactively,
  /// before the first ball of the next over). Carried on the next delivery so
  /// the backend creates/attributes them.
  final String? pendingNewBowlerName;

  /// Number of balls entered while offline that are queued for sync. >0 shows
  /// a "pending sync" banner; drains to 0 once connectivity returns.
  final int pendingSync;

  const CricketScoringLoaded(
    this.matchState, {
    this.players,
    this.needsNewBowler = false,
    this.errorMessage,
    this.submitting = false,
    this.pendingNewBowlerName,
    this.pendingSync = 0,
  });

  CricketScoringLoaded copyWith({
    CricketMatchStateEntity? matchState,
    CricketPlayersEntity? players,
    bool? needsNewBowler,
    String? errorMessage,
    bool? submitting,
    String? pendingNewBowlerName,
    int? pendingSync,
    bool clearError = false,
    bool clearPendingBowler = false,
  }) {
    return CricketScoringLoaded(
      matchState ?? this.matchState,
      players: players ?? this.players,
      needsNewBowler: needsNewBowler ?? this.needsNewBowler,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitting: submitting ?? this.submitting,
      pendingNewBowlerName:
          clearPendingBowler ? null : (pendingNewBowlerName ?? this.pendingNewBowlerName),
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  List<Object?> get props =>
      [matchState, players, needsNewBowler, errorMessage, submitting, pendingNewBowlerName, pendingSync];
}

class CricketScoringFailure extends CricketScoringState {
  final String message;
  const CricketScoringFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class CricketScoringCubit extends Cubit<CricketScoringState> {
  final SportsRepository _repository;
  final String fixtureId;

  /// In-memory outbox of balls entered while offline, replayed in order once
  /// connectivity returns. In-memory (not persisted) by design — it covers the
  /// real case of a brief signal drop while the scorer is actively on this
  /// screen; a queued ball survives navigation within the app but not a full
  /// app kill mid-outage (the scoreboard then reverts to server truth on
  /// reload and the scorer re-enters).
  final List<Map<String, dynamic>> _outbox = [];
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _flushing = false;

  CricketScoringCubit(this._repository, this.fixtureId) : super(CricketScoringInitial()) {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && _outbox.isNotEmpty) _flushOutbox();
    });
  }

  @override
  Future<void> close() {
    _connSub?.cancel();
    return super.close();
  }

  Future<void> load() async {
    emit(CricketScoringLoading());
    final result = await _repository.fetchCricketMatchState(fixtureId);
    result.fold(
      (failure) {
        if (failure is NotFoundFailure) {
          emit(CricketScoringNotInitialized());
        } else {
          emit(CricketScoringFailure(failure.message));
        }
      },
      // Players are unknown after a plain fetch — live UI will ask to
      // confirm the current batters/bowler before scoring resumes.
      (matchState) => emit(CricketScoringLoaded(matchState)),
    );
  }

  Future<void> initMatch({
    required String tossWinnerId,
    required String tossDecision, // BAT | BOWL
    required int overs,
    required String strikerName,
    required String nonStrikerName,
    required String bowlerName,
    bool villageWides = false,
  }) async {
    emit(CricketScoringLoading());
    final result = await _repository.initCricketMatch(fixtureId, {
      'toss_winner_id': tossWinnerId,
      'toss_decision': tossDecision,
      'overs': overs,
      'village_wides': villageWides,
      'striker_name': strikerName.trim(),
      'non_striker_name': nonStrikerName.trim(),
      'bowler_name': bowlerName.trim(),
    });
    result.fold(
      (failure) => emit(CricketScoringFailure(failure.message)),
      (r) => emit(CricketScoringLoaded(r.$1, players: r.$2)),
    );
  }

  /// The scorer confirmed/selected who is currently at the crease and
  /// bowling (used when resuming a match or after an ambiguous undo).
  void setPlayers(CricketPlayersEntity players) {
    final s = state;
    if (s is CricketScoringLoaded) {
      emit(CricketScoringLoaded(s.matchState, players: players));
    }
  }

  /// An existing player was chosen to bowl the new over (clears the
  /// over-break prompt so the next ball scores without asking again).
  void chooseBowler(String id, String name) {
    final s = state;
    if (s is CricketScoringLoaded && s.players != null) {
      emit(s.copyWith(
        players: s.players!.copyWith(bowlerId: id, bowlerName: name),
        needsNewBowler: false,
        clearPendingBowler: true,
      ));
    }
  }

  /// A brand-new bowler was picked at the over break. Show them at the crease
  /// immediately (blank id → the pad falls back to this name with 0-0-0); the
  /// name rides along on the next delivery so the backend creates them.
  void chooseNewBowler(String name) {
    final s = state;
    if (s is CricketScoringLoaded && s.players != null) {
      emit(s.copyWith(
        players: s.players!.copyWith(bowlerId: '', bowlerName: name.trim()),
        needsNewBowler: false,
        pendingNewBowlerName: name.trim(),
      ));
    }
  }

  void swapStrike() {
    final s = state;
    if (s is CricketScoringLoaded && s.players != null) {
      emit(CricketScoringLoaded(
        s.matchState,
        players: s.players!.swapped(),
        needsNewBowler: s.needsNewBowler,
      ));
    }
  }

  Future<void> scoreBall({
    int runsBatter = 0,
    String extrasType = 'NONE',
    int extrasRuns = 0,
    bool isWicket = false,
    String? wicketType,
    String? playerDismissedId,
    String? newBatterName,
    String? newBowlerName,
  }) async {
    final s = state;
    if (s is! CricketScoringLoaded || s.players == null || s.submitting) return;
    final players = s.players!;
    final prev = s.matchState;

    // Carry a proactively-chosen new bowler (over-break pick) onto this ball.
    final passedBowler = newBowlerName?.trim();
    final effectiveNewBowler = (passedBowler != null && passedBowler.isNotEmpty)
        ? passedBowler
        : s.pendingNewBowlerName;

    final payload = <String, dynamic>{
      'striker_id': players.strikerId,
      'non_striker_id': players.nonStrikerId,
      'bowler_id': players.bowlerId,
      'runs_batter': runsBatter,
      'extras_type': extrasType,
      'extras_runs': extrasRuns,
      'is_wicket': isWicket,
      if (wicketType != null) 'wicket_type': wicketType,
      if (playerDismissedId != null) 'player_dismissed_id': playerDismissedId,
      if (newBatterName != null && newBatterName.trim().isNotEmpty)
        'new_batter_name': newBatterName.trim(),
      if (effectiveNewBowler != null && effectiveNewBowler.isNotEmpty)
        'new_bowler_name': effectiveNewBowler,
    };

    // Optimistic UI: for a simple, non-wicket, non-over-ending delivery, show
    // the predicted score instantly so entry feels lightning-fast. The server
    // response below always overwrites this with the authoritative state, and
    // a failure rolls back to `s` — so the prediction is display-only and can
    // never corrupt the match. Anything it can't safely predict (wicket, the
    // 6th ball of an over, an unknown player) falls back to the saving hint.
    final predicted = isWicket
        ? null
        : _predictBall(prev, players, runsBatter: runsBatter, extrasType: extrasType, extrasRuns: extrasRuns);

    // A ball is safe to queue offline only when it keeps the same two batters
    // and bowler and doesn't complete the over — exactly what _predictBall is
    // willing to predict, with no new bowler coming on. Wickets, the 6th ball
    // of an over and bowler changes need server-assigned ids, so they require a
    // live connection.
    final offlineSafe =
        predicted != null && !isWicket && (effectiveNewBowler == null || effectiveNewBowler.isEmpty);

    // Ordering guarantee: once anything is queued offline, every later ball
    // goes through the queue too so it can never overtake an unsynced ball.
    if (_outbox.isNotEmpty) {
      if (offlineSafe) {
        _enqueueOffline(payload, predicted!, _nextAfterSimple(players, runsBatter, extrasType, extrasRuns));
        _flushOutbox();
      } else {
        emit(s.copyWith(errorMessage: _reconnectMessage(s.pendingSync)));
      }
      return;
    }

    if (predicted != null) {
      emit(CricketScoringLoaded(predicted,
          players: players,
          needsNewBowler: s.needsNewBowler,
          submitting: true,
          pendingNewBowlerName: s.pendingNewBowlerName));
    } else {
      emit(s.copyWith(submitting: true, clearError: true));
    }
    final result = await _repository.scoreCricketBall(fixtureId, payload);

    result.fold(
      (failure) {
        // A transport-layer drop on a safe ball → queue it and keep scoring;
        // it syncs in order when the connection returns. Anything else (or an
        // unsafe ball offline) rolls back so the scorer can retry.
        if (failure is NetworkFailure && offlineSafe) {
          _enqueueOffline(payload, predicted!, _nextAfterSimple(players, runsBatter, extrasType, extrasRuns));
        } else {
          emit(s.copyWith(
            submitting: false,
            errorMessage: failure is NetworkFailure ? _reconnectMessage(0) : failure.message,
          ));
        }
      },
      (newState) {
        var next = players;

        // A replacement batter takes the dismissed player's slot. The
        // backend created the player; find their UUID in the scorecard.
        if (isWicket && newBatterName != null && newBatterName.trim().isNotEmpty) {
          final replacement = _findBatterByName(newState, newBatterName.trim());
          if (replacement != null) {
            if (playerDismissedId == players.strikerId) {
              next = next.copyWith(strikerId: replacement.id, strikerName: replacement.name);
            } else if (playerDismissedId == players.nonStrikerId) {
              next = next.copyWith(nonStrikerId: replacement.id, nonStrikerName: replacement.name);
            }
          }
        }

        // The mid-over bowler change (or new-over bowler) was created
        // server-side; adopt their UUID for subsequent balls.
        if (effectiveNewBowler != null && effectiveNewBowler.isNotEmpty) {
          final b = _findBowlerByName(newState, effectiveNewBowler);
          if (b != null) next = next.copyWith(bowlerId: b.id, bowlerName: b.name);
        }

        // Strike rotation for odd completed runs (byes/leg-byes rotate on
        // the extras runs; wides don't change strike in this simple model).
        final ranRuns = (extrasType == 'BYE' || extrasType == 'LEG_BYE') ? extrasRuns : runsBatter;
        if (extrasType != 'WIDE' && ranRuns.isOdd) next = next.swapped();

        // Over completed → batters cross AND the next over needs a bowler.
        final overEnded = newState.isLive &&
            newState.innings == prev.innings &&
            newState.balls == 0 &&
            newState.overs > prev.overs;
        if (overEnded) next = next.swapped();

        emit(CricketScoringLoaded(newState, players: next, needsNewBowler: overEnded));
      },
    );
  }

  /// The player arrangement after a simple (offline-safe) delivery: strike
  /// crosses on an odd number of runs run; a wide never changes strike. No new
  /// players and no over-cross happen offline, so this fully captures it.
  CricketPlayersEntity _nextAfterSimple(
      CricketPlayersEntity players, int runsBatter, String extrasType, int extrasRuns) {
    final ranRuns = (extrasType == 'BYE' || extrasType == 'LEG_BYE') ? extrasRuns : runsBatter;
    if (extrasType != 'WIDE' && ranRuns.isOdd) return players.swapped();
    return players;
  }

  String _reconnectMessage(int pending) => pending > 0
      ? "You're offline — reconnect to record this ($pending ball${pending == 1 ? '' : 's'} waiting to sync)."
      : "You're offline — reconnect to record this ball.";

  /// Queue a ball entered offline and show its optimistic state with the
  /// pending-sync count. The queue replays in order once connectivity returns.
  void _enqueueOffline(
      Map<String, dynamic> payload, CricketMatchStateEntity predicted, CricketPlayersEntity next) {
    _outbox.add(payload);
    emit(CricketScoringLoaded(predicted,
        players: next, needsNewBowler: false, submitting: false, pendingSync: _outbox.length));
  }

  /// Replay queued offline balls in order. Stops on a transport-layer failure
  /// (still offline — retried on the next connectivity change); drops a ball
  /// the server rejects for a non-network reason so a single poison entry can't
  /// block the queue forever. Reconciles with authoritative state once drained.
  Future<void> _flushOutbox() async {
    if (_flushing || _outbox.isEmpty) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty) {
        final res = await _repository.scoreCricketBall(fixtureId, _outbox.first);
        if (isClosed) return;
        final failure = res.fold<Failure?>((f) => f, (_) => null);
        if (failure is NetworkFailure) break; // still offline — keep the queue
        _outbox.removeAt(0); // success, or a poison ball we drop and move past
      }
      if (_outbox.isEmpty) {
        final st = await _repository.fetchCricketMatchState(fixtureId);
        if (isClosed) return;
        st.fold((_) {}, (ms) {
          final cur = state;
          if (cur is CricketScoringLoaded) {
            emit(CricketScoringLoaded(ms,
                players: cur.players, needsNewBowler: cur.needsNewBowler, pendingSync: 0));
          }
        });
      } else {
        final cur = state;
        if (cur is CricketScoringLoaded) emit(cur.copyWith(pendingSync: _outbox.length));
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> editBall({
    required String ballId,
    int? runsBatter,
    String? extrasType,
    int? extrasRuns,
    bool? isWicket,
    String? wicketType,
    String? playerDismissedId,
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
    String? notes,
  }) async {
    final s = state;
    if (s is! CricketScoringLoaded) return;

    emit(CricketScoringLoading());
    final result = await _repository.editCricketBall(fixtureId, ballId, {
      if (runsBatter != null) 'runs_batter': runsBatter,
      if (extrasType != null) 'extras_type': extrasType,
      if (extrasRuns != null) 'extras_runs': extrasRuns,
      if (isWicket != null) 'is_wicket': isWicket,
      if (wicketType != null) 'wicket_type': wicketType,
      if (playerDismissedId != null) 'player_dismissed_id': playerDismissedId,
      if (strikerId != null) 'striker_id': strikerId,
      if (nonStrikerId != null) 'non_striker_id': nonStrikerId,
      if (bowlerId != null) 'bowler_id': bowlerId,
      if (notes != null) 'notes': notes,
    });

    result.fold(
      (failure) {
        emit(CricketScoringLoaded(s.matchState,
            players: s.players,
            needsNewBowler: s.needsNewBowler,
            errorMessage: failure.message));
      },
      (newState) {
        emit(CricketScoringLoaded(newState, players: s.players, needsNewBowler: s.needsNewBowler));
      },
    );
  }

  Future<void> undoEditBall(String ballId) async {
    final s = state;
    if (s is! CricketScoringLoaded) return;

    emit(CricketScoringLoading());
    final result = await _repository.undoEditBall(fixtureId, ballId);

    result.fold(
      (failure) {
        emit(CricketScoringLoaded(s.matchState,
            players: s.players,
            needsNewBowler: s.needsNewBowler,
            errorMessage: failure.message));
      },
      (newState) {
        emit(CricketScoringLoaded(newState, players: s.players, needsNewBowler: s.needsNewBowler));
      },
    );
  }

  Future<void> undoBall() async {
    final s = state;
    emit(CricketScoringLoading());
    final result = await _repository.undoCricketBall(fixtureId);
    result.fold(
      (failure) {
        if (s is CricketScoringLoaded) {
          emit(CricketScoringLoaded(s.matchState,
              players: s.players,
              needsNewBowler: s.needsNewBowler,
              errorMessage: failure.message));
        } else {
          emit(CricketScoringFailure(failure.message));
        }
      },
      (newState) {
        // After an undo the previously tracked players may no longer exist
        // (e.g. the undone ball introduced a new batter). Keep them only if
        // they are still valid not-out batters; otherwise ask to re-confirm.
        CricketPlayersEntity? players;
        if (s is CricketScoringLoaded && s.players != null) {
          final tracked = s.players!;
          players = tracked;
          if (newState.batters.isNotEmpty) {
            bool validBatter(String id) =>
                newState.batters.any((b) => b.id == id && !b.out);
            if (!validBatter(tracked.strikerId) || !validBatter(tracked.nonStrikerId)) {
              players = null;
            }
          }
        }
        emit(CricketScoringLoaded(newState, players: players));
      },
    );
  }

  Future<void> startSecondInnings({
    required String strikerName,
    required String nonStrikerName,
    required String bowlerName,
    required String anyTeamId, // schema requires a toss field; unused by backend here
  }) async {
    emit(CricketScoringLoading());
    final result = await _repository.startCricketSecondInnings(fixtureId, {
      'toss_winner_id': anyTeamId,
      'toss_decision': 'BAT',
      'overs': 20,
      'striker_name': strikerName.trim(),
      'non_striker_name': nonStrikerName.trim(),
      'bowler_name': bowlerName.trim(),
    });
    result.fold(
      (failure) => emit(CricketScoringFailure(failure.message)),
      (r) => emit(CricketScoringLoaded(r.$1, players: r.$2)),
    );
  }

  /// Predicts the scoreboard after a simple delivery, for instant optimistic
  /// display. Returns null (caller shows the saving hint instead) whenever the
  /// outcome is anything this lightweight model shouldn't guess: a delivery
  /// that completes the over (could also end the innings — the over limit isn't
  /// in match state), or a striker/bowler not yet on the scorecard. The values
  /// mirror recalculate_match_state exactly so the server response, when it
  /// lands, matches and there's no visible correction. Extras total and overs
  /// history are intentionally left for the authoritative refresh.
  CricketMatchStateEntity? _predictBall(
    CricketMatchStateEntity prev,
    CricketPlayersEntity players, {
    required int runsBatter,
    required String extrasType,
    required int extrasRuns,
  }) {
    final legal = extrasType != 'WIDE' && extrasType != 'NO_BALL';
    // The 6th legal ball ends the over (and maybe the innings) — let the server
    // own strike rotation, the bowler prompt and any innings break.
    if (legal && prev.balls + 1 >= 6) return null;
    // Need both current players already on the card to update their tallies.
    if (!prev.batters.any((b) => b.id == players.strikerId)) return null;
    if (!prev.bowlers.any((b) => b.id == players.bowlerId)) return null;

    final freeWide = extrasType == 'WIDE' && prev.nextWideIsFree;
    final creditsBatter = extrasType == 'NONE' || extrasType == 'NO_BALL';

    int scoreDelta;
    int bowlerRunsDelta;
    switch (extrasType) {
      case 'WIDE':
        scoreDelta = freeWide ? extrasRuns : 1 + extrasRuns;
        bowlerRunsDelta = scoreDelta;
        break;
      case 'NO_BALL':
        scoreDelta = 1 + extrasRuns;
        bowlerRunsDelta = 1 + runsBatter;
        break;
      case 'BYE':
      case 'LEG_BYE':
        scoreDelta = extrasRuns;
        bowlerRunsDelta = 0;
        break;
      default:
        scoreDelta = runsBatter;
        bowlerRunsDelta = runsBatter;
    }

    final String token;
    if (extrasType == 'WIDE') {
      token = freeWide ? (extrasRuns > 0 ? '${extrasRuns}wd' : 'wd') : '${1 + extrasRuns}wd';
    } else if (extrasType == 'NO_BALL') {
      token = '${1 + extrasRuns}nb';
    } else if (extrasType == 'BYE') {
      token = '${extrasRuns}b';
    } else if (extrasType == 'LEG_BYE') {
      token = '${extrasRuns}lb';
    } else {
      token = runsBatter > 0 ? '$runsBatter' : '•';
    }

    final strikerFaces = extrasType != 'WIDE'; // a wide isn't a ball faced
    final batters = prev.batters.map((b) {
      if (b.id != players.strikerId) return b;
      return CricketBatterEntity(
        id: b.id,
        name: b.name,
        runs: b.runs + (creditsBatter ? runsBatter : 0),
        balls: b.balls + (strikerFaces ? 1 : 0),
        fours: b.fours + (creditsBatter && runsBatter == 4 ? 1 : 0),
        sixes: b.sixes + (creditsBatter && runsBatter == 6 ? 1 : 0),
        out: b.out,
      );
    }).toList();

    final bowlers = prev.bowlers.map((b) {
      if (b.id != players.bowlerId) return b;
      return CricketBowlerEntity(
        id: b.id,
        name: b.name,
        legalBalls: b.legalBalls + (legal ? 1 : 0),
        runs: b.runs + bowlerRunsDelta,
        wickets: b.wickets,
      );
    }).toList();

    return CricketMatchStateEntity(
      innings: prev.innings,
      battingTeamId: prev.battingTeamId,
      bowlingTeamId: prev.bowlingTeamId,
      score: prev.score + scoreDelta,
      wickets: prev.wickets,
      overs: prev.overs,
      balls: legal ? prev.balls + 1 : prev.balls,
      target: prev.target,
      status: prev.status,
      batters: batters,
      bowlers: bowlers,
      extras: prev.extras,
      recentBalls: [...prev.recentBalls, token],
      oversHistory: prev.oversHistory,
      villageWides: prev.villageWides,
      widesThisOver: extrasType == 'WIDE' ? prev.widesThisOver + 1 : prev.widesThisOver,
    );
  }

  CricketBatterEntity? _findBatterByName(CricketMatchStateEntity st, String name) {
    for (final b in st.batters) {
      if (b.name == name && !b.out) return b;
    }
    return null;
  }

  CricketBowlerEntity? _findBowlerByName(CricketMatchStateEntity st, String name) {
    for (final b in st.bowlers) {
      if (b.name == name) return b;
    }
    return null;
  }
}
