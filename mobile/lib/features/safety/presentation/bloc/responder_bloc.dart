import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../../domain/repositories/safety_repository.dart';

abstract class ResponderEvent extends Equatable {
  const ResponderEvent();
  @override
  List<Object?> get props => [];
}

class AlertOpened extends ResponderEvent {
  const AlertOpened(this.incidentId);
  final String incidentId;
  @override
  List<Object?> get props => [incidentId];
}

class Accepted extends ResponderEvent {
  const Accepted();
}

class Declined extends ResponderEvent {
  const Declined();
}

class Arrived extends ResponderEvent {
  const Arrived();
}

class ResponderViewState extends Equatable {
  const ResponderViewState({
    this.loading = false,
    this.alert,
    this.busy = false,
    this.failure,
  });

  final bool loading;
  final e.ResponderAlert? alert;
  final bool busy;
  final String? failure;

  ResponderViewState copyWith({
    bool? loading,
    e.ResponderAlert? alert,
    bool? busy,
    String? failure,
    bool clearFailure = false,
  }) =>
      ResponderViewState(
        loading: loading ?? this.loading,
        alert: alert ?? this.alert,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [loading, alert, busy, failure];
}

/// Answering somebody else's SOS.
///
/// The two buttons are deliberately equal in weight. Published response rates
/// for volunteer responders run 17–47%, so most taps here will be *Can't* —
/// and a decline is worth having: once everybody in a wave has declined, the
/// ring widens immediately instead of waiting out the timer. A screen that
/// shames the "no" gets neither answer.
class ResponderBloc extends Bloc<ResponderEvent, ResponderViewState> {
  ResponderBloc(this._repo) : super(const ResponderViewState()) {
    on<AlertOpened>(_onOpen);
    on<Accepted>((_, emit) => _act(emit, (id) => _repo.acknowledge(id)));
    on<Declined>((_, emit) => _act(emit, (id) => _repo.decline(id)));
    on<Arrived>((_, emit) => _act(emit, (id) => _repo.arrived(id)));
  }

  final SafetyRepository _repo;
  String? _id;

  String _reason(Object err) => err is Failure
      ? err.message
      : 'Something went wrong. Please try again.';

  Future<void> _onOpen(AlertOpened ev, Emitter<ResponderViewState> emit) async {
    _id = ev.incidentId;
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      emit(state.copyWith(loading: false, alert: await _repo.alert(ev.incidentId)));
    } catch (err) {
      emit(state.copyWith(loading: false, failure: _reason(err)));
    }
  }

  Future<void> _act(Emitter<ResponderViewState> emit,
      Future<e.SosIncident> Function(String id) action) async {
    final id = _id;
    if (id == null) return;
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      await action(id);
      // Re-read rather than patch: the answer changes what this responder is
      // allowed to see — the raiser's phone number appears only once they have
      // said they are coming.
      emit(state.copyWith(busy: false, alert: await _repo.alert(id)));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    }
  }
}
