import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/complaint_entities.dart' as e;
import '../../domain/repositories/complaint_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ComplaintListEvent extends Equatable {
  const ComplaintListEvent();
  @override
  List<Object?> get props => [];
}

class ComplaintsRequested extends ComplaintListEvent {
  const ComplaintsRequested({this.includeClosed = true});
  final bool includeClosed;
  @override
  List<Object?> get props => [includeClosed];
}

/// The member switched between the open ones and the finished ones.
///
/// Filtered here rather than refetched. The list is small, the server already
/// sent both, and a spinner between two tabs of the same data is a wait the
/// member is paying for nothing.
class ComplaintFilterChanged extends ComplaintListEvent {
  const ComplaintFilterChanged(this.showClosed);
  final bool showClosed;
  @override
  List<Object?> get props => [showClosed];
}

// ── State ────────────────────────────────────────────────────────────────────

class ComplaintListState extends Equatable {
  const ComplaintListState({
    this.loading = false,
    this.all = const [],
    this.showClosed = false,
    this.failure,
  });

  final bool loading;

  /// Everything, in the order the server sent it: open before closed, and
  /// among the open ones the longest-ignored first.
  final List<e.ComplaintSummary> all;

  final bool showClosed;
  final String? failure;

  List<e.ComplaintSummary> get open =>
      all.where((c) => !c.isClosed).toList(growable: false);

  List<e.ComplaintSummary> get closed =>
      all.where((c) => c.isClosed).toList(growable: false);

  List<e.ComplaintSummary> get visible => showClosed ? closed : open;

  /// Nothing at all has ever been reported — which is a different screen from
  /// "you have nothing open right now".
  bool get isEmpty => all.isEmpty;

  ComplaintListState copyWith({
    bool? loading,
    List<e.ComplaintSummary>? all,
    bool? showClosed,
    String? failure,
    bool clearFailure = false,
  }) =>
      ComplaintListState(
        loading: loading ?? this.loading,
        all: all ?? this.all,
        showClosed: showClosed ?? this.showClosed,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [loading, all, showClosed, failure];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

/// Every complaint this member has, and where each one stands.
///
/// The old screen listed issues by a status column the server maintained by
/// guessing. This lists them by what somebody actually said — and puts the one
/// nobody has answered in three weeks at the top, because that is the one
/// worth doing something about today.
class ComplaintListBloc extends Bloc<ComplaintListEvent, ComplaintListState> {
  ComplaintListBloc(this._repo) : super(const ComplaintListState()) {
    on<ComplaintsRequested>(_onRequested);
    on<ComplaintFilterChanged>(
        (ev, emit) => emit(state.copyWith(showClosed: ev.showClosed)));
  }

  final ComplaintRepository _repo;

  Future<void> _onRequested(
      ComplaintsRequested ev, Emitter<ComplaintListState> emit) async {
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      final all = await _repo.mine(includeClosed: ev.includeClosed);
      emit(state.copyWith(loading: false, all: all));
    } catch (err) {
      emit(state.copyWith(
        loading: false,
        failure: err is Failure
            ? err.message
            : 'Something went wrong. Please try again.',
      ));
    }
  }
}
