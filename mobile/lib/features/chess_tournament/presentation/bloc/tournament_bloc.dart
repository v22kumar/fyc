import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/tournament_entities.dart' as e;
import '../../domain/repositories/tournament_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class TournamentEvent extends Equatable {
  const TournamentEvent();
  @override
  List<Object?> get props => [];
}

class TournamentRequested extends TournamentEvent {
  const TournamentRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Pull-to-refresh, or coming back from the board: same fetch, but the screen
/// keeps showing what it has instead of collapsing to a spinner.
class TournamentRefreshed extends TournamentEvent {
  const TournamentRefreshed();
}

class RegisterPressed extends TournamentEvent {
  const RegisterPressed();
}

class RegistrationDecided extends TournamentEvent {
  const RegistrationDecided(this.userId, {required this.approve});
  final String userId;
  final bool approve;
  @override
  List<Object?> get props => [userId, approve];
}

class CloseRegistrationPressed extends TournamentEvent {
  const CloseRegistrationPressed();
}

class ReopenRegistrationPressed extends TournamentEvent {
  const ReopenRegistrationPressed();
}

class TimeControlChanged extends TournamentEvent {
  const TimeControlChanged(this.timeControl);
  final String timeControl;
  @override
  List<Object?> get props => [timeControl];
}

class StartTournamentPressed extends TournamentEvent {
  const StartTournamentPressed();
}

class NextRoundPressed extends TournamentEvent {
  const NextRoundPressed();
}

class ReadyPressed extends TournamentEvent {
  const ReadyPressed(this.matchId);
  final String matchId;
  @override
  List<Object?> get props => [matchId];
}

class PlayPressed extends TournamentEvent {
  const PlayPressed(this.matchId, {required this.uid});
  final String matchId;

  /// Who is opening the board — the bloc derives their colour from the match
  /// so the screen doesn't have to know that seat A plays white.
  final String uid;
  @override
  List<Object?> get props => [matchId, uid];
}

class WalkoverClaimed extends TournamentEvent {
  const WalkoverClaimed(this.matchId);
  final String matchId;
  @override
  List<Object?> get props => [matchId];
}

class ResultReported extends TournamentEvent {
  const ResultReported(this.matchId, {required this.winnerId});
  final String matchId;
  final String winnerId;
  @override
  List<Object?> get props => [matchId, winnerId];
}

class ConductChanged extends TournamentEvent {
  const ConductChanged(this.matchId,
      {required this.mode, this.venue, this.reportingTime});
  final String matchId;
  final String mode;
  final String? venue;
  final DateTime? reportingTime;
  @override
  List<Object?> get props => [matchId, mode, venue, reportingTime];
}

// ── State ────────────────────────────────────────────────────────────────────

/// Everything the screen needs to open the board, produced whole by the bloc
/// so the widget does no lookups of its own on the way to the router.
class BoardTicket extends Equatable {
  const BoardTicket(
      {required this.gameId, required this.token, required this.color});

  final String gameId;
  final String token;
  final String color;

  @override
  List<Object?> get props => [gameId, token, color];
}

class TournamentState extends Equatable {
  const TournamentState({
    this.loading = false,
    this.detail,
    this.busy = false,
    this.failure,
    this.openGame,
  });

  final bool loading;
  final e.TournamentDetail? detail;

  /// An action is in flight. Separate from [loading] so the screen stays put
  /// while a tap round-trips.
  final bool busy;

  final String? failure;

  /// Set when Play produced a game — the screen navigates to the board, once,
  /// and the bloc clears it immediately by re-emitting without it.
  final BoardTicket? openGame;

  TournamentState copyWith({
    bool? loading,
    e.TournamentDetail? detail,
    bool? busy,
    String? failure,
    BoardTicket? openGame,
    bool clearFailure = false,
    bool clearOpenGame = false,
  }) =>
      TournamentState(
        loading: loading ?? this.loading,
        detail: detail ?? this.detail,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
        openGame: clearOpenGame ? null : (openGame ?? this.openGame),
      );

  @override
  List<Object?> get props => [loading, detail, busy, failure, openGame];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

/// Drives one tournament for all three kinds of person looking at it.
///
/// Every mutation replaces the whole [e.TournamentDetail] with the server's
/// answer — the bloc never patches its own copy, so the player card, the
/// organiser worklist and the bracket can never disagree with each other or
/// with the server.
class TournamentBloc extends Bloc<TournamentEvent, TournamentState> {
  TournamentBloc(this._repo, {Future<String?> Function()? authToken})
      : _authToken = (authToken ?? (() async => null)),
        super(const TournamentState()) {
    on<TournamentRequested>(_onRequested);
    on<TournamentRefreshed>(_onRefreshed);
    // Every mutation is droppable: the second tap of a double-tap arrives
    // while the first is in flight, and must vanish rather than queue.
    on<RegisterPressed>(_onRegister);
    on<RegistrationDecided>(
        (ev, emit) => _mutate(emit, () => _repo.decideRegistration(
            _id!, ev.userId,
            approve: ev.approve)));
    on<CloseRegistrationPressed>(
        (ev, emit) => _mutate(emit, () => _repo.closeRegistration(_id!)));
    on<ReopenRegistrationPressed>(
        (ev, emit) => _mutate(emit, () => _repo.reopenRegistration(_id!)));
    on<TimeControlChanged>(
        (ev, emit) =>
            _mutate(emit, () => _repo.setTimeControl(_id!, ev.timeControl)));
    on<StartTournamentPressed>(
        (ev, emit) => _mutate(emit, () => _repo.start(_id!)));
    on<NextRoundPressed>(
        (ev, emit) => _mutate(emit, () => _repo.startNextRound(_id!)));
    on<ReadyPressed>(
        (ev, emit) => _mutate(emit, () => _repo.markReady(_id!, ev.matchId)));
    on<PlayPressed>(_onPlay);
    on<WalkoverClaimed>(
        (ev, emit) => _mutate(emit, () => _repo.claimWalkover(_id!, ev.matchId)));
    on<ResultReported>(
        (ev, emit) => _mutate(emit,
            () => _repo.reportResult(_id!, ev.matchId, winnerId: ev.winnerId)));
    on<ConductChanged>(
        (ev, emit) => _mutate(
            emit,
            () => _repo.setConduct(_id!, ev.matchId,
                mode: ev.mode,
                venue: ev.venue,
                reportingTime: ev.reportingTime)));
  }

  final TournamentRepository _repo;

  /// Injected by the composition root; the widget layer never touches the
  /// locator or the storage for it.
  final Future<String?> Function() _authToken;

  String? _id;

  /// True from the moment a mutating tap is accepted until its handler ends.
  ///
  /// The drop happens in [add] — synchronously with the tap — because a bloc
  /// queues events and runs them one at a time: by the time a double-tap's
  /// second event is handled, the first has finished and `state.busy` is false
  /// again, so any guard inside the handler passes. The server would refuse
  /// the duplicate anyway ("No further rounds"), but the member would get a
  /// red toast for a mistake the app invited.
  bool _mutationInFlight = false;

  @override
  void add(TournamentEvent event) {
    final isMutation =
        event is! TournamentRequested && event is! TournamentRefreshed;
    if (isMutation) {
      if (_mutationInFlight) return; // the drop
      _mutationInFlight = true;
    }
    super.add(event);
  }

  String _reason(Object err) =>
      err is Failure ? err.message : 'Something went wrong. Please try again.';

  Future<void> _onRequested(
      TournamentRequested ev, Emitter<TournamentState> emit) async {
    _id = ev.id;
    emit(state.copyWith(loading: state.detail == null, clearFailure: true));
    try {
      emit(state.copyWith(loading: false, detail: await _repo.detail(ev.id)));
    } catch (err) {
      emit(state.copyWith(loading: false, failure: _reason(err)));
    }
  }

  Future<void> _onRefreshed(
      TournamentRefreshed ev, Emitter<TournamentState> emit) async {
    final id = _id;
    if (id == null) return;
    try {
      emit(state.copyWith(detail: await _repo.detail(id), clearFailure: true));
    } catch (_) {
      // A failed refresh keeps the last known state on screen; the next pull
      // tries again. A red toast for a background refresh helps nobody.
    }
  }

  Future<void> _mutate(Emitter<TournamentState> emit,
      Future<e.TournamentDetail> Function() action) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      emit(state.copyWith(busy: false, detail: await action()));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    } finally {
      _mutationInFlight = false;
    }
  }

  Future<void> _onRegister(
      RegisterPressed ev, Emitter<TournamentState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      await _repo.register(_id!);
      emit(state.copyWith(busy: false, detail: await _repo.detail(_id!)));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    } finally {
      _mutationInFlight = false;
    }
  }

  Future<void> _onPlay(PlayPressed ev, Emitter<TournamentState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      e.BracketMatch? match;
      for (final m in state.detail?.matches ?? const <e.BracketMatch>[]) {
        if (m.id == ev.matchId) match = m;
      }
      final gameId = await _repo.play(_id!, ev.matchId);
      final token = await _authToken() ?? '';
      final fresh = await _repo.detail(_id!);
      emit(state.copyWith(
        busy: false,
        detail: fresh,
        openGame: BoardTicket(
            gameId: gameId,
            token: token,
            color: match?.colorFor(ev.uid) ?? 'white'),
      ));
      // One navigation per game: cleared immediately so a later rebuild cannot
      // re-open the board.
      emit(state.copyWith(clearOpenGame: true));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    } finally {
      _mutationInFlight = false;
    }
  }
}

// ── The list ─────────────────────────────────────────────────────────────────

class TournamentListState extends Equatable {
  const TournamentListState(
      {this.loading = false, this.items = const [], this.failure});

  final bool loading;
  final List<e.Tournament> items;
  final String? failure;

  @override
  List<Object?> get props => [loading, items, failure];
}

class TournamentListBloc extends Cubit<TournamentListState> {
  TournamentListBloc(this._repo) : super(const TournamentListState());

  final TournamentRepository _repo;

  Future<void> load() async {
    emit(TournamentListState(loading: state.items.isEmpty, items: state.items));
    try {
      emit(TournamentListState(items: await _repo.list()));
    } catch (err) {
      emit(TournamentListState(
        items: state.items,
        failure: err is Failure
            ? err.message
            : 'Something went wrong. Please try again.',
      ));
    }
  }
}
