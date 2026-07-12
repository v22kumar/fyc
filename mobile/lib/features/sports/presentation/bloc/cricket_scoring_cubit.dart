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

  const CricketScoringLoaded(
    this.matchState, {
    this.players,
    this.needsNewBowler = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [matchState, players, needsNewBowler, errorMessage];
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

  CricketScoringCubit(this._repository, this.fixtureId) : super(CricketScoringInitial());

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

  /// An existing player was chosen to bowl the new over.
  void chooseBowler(String id, String name) {
    final s = state;
    if (s is CricketScoringLoaded && s.players != null) {
      emit(CricketScoringLoaded(
        s.matchState,
        players: s.players!.copyWith(bowlerId: id, bowlerName: name),
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
    if (s is! CricketScoringLoaded || s.players == null) return;
    final players = s.players!;
    final prev = s.matchState;

    emit(CricketScoringLoading());
    final result = await _repository.scoreCricketBall(fixtureId, {
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
      if (newBowlerName != null && newBowlerName.trim().isNotEmpty)
        'new_bowler_name': newBowlerName.trim(),
    });

    result.fold(
      (failure) {
        // Restore the pre-ball state so the scorer can retry.
        emit(CricketScoringLoaded(s.matchState,
            players: s.players,
            needsNewBowler: s.needsNewBowler,
            errorMessage: failure.message));
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
        if (newBowlerName != null && newBowlerName.trim().isNotEmpty) {
          final b = _findBowlerByName(newState, newBowlerName.trim());
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
