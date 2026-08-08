import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/work_entities.dart';
import '../../domain/repositories/work_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class WorkEvent extends Equatable {
  const WorkEvent();
  @override
  List<Object?> get props => [];
}

/// Open the index. Loads the categories somebody is actually in.
class WorkOpened extends WorkEvent {
  const WorkOpened();
}

class WorkSearched extends WorkEvent {
  const WorkSearched({this.q, this.category, this.area});
  final String? q;
  final String? category;
  final String? area;
  @override
  List<Object?> get props => [q, category, area];
}

class ListingViewed extends WorkEvent {
  const ListingViewed(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ListingReported extends WorkEvent {
  const ListingReported(this.id, {required this.reason, this.note});
  final String id;
  final ReportReason reason;
  final String? note;
  @override
  List<Object?> get props => [id, reason, note];
}

class MyListingsRequested extends WorkEvent {
  const MyListingsRequested();
}

// ── State ────────────────────────────────────────────────────────────────────

class WorkState extends Equatable {
  const WorkState({
    this.loading = false,
    this.searching = false,
    this.categories = const [],
    this.results = const [],
    this.mine = const [],
    this.query,
    this.activeCategory,
    this.failure,
    this.reported = false,
    this.hasSearched = false,
  });

  final bool loading;

  /// Separate from [loading] so the categories stay on screen while a search
  /// runs. Replacing the whole page with a spinner on every keystroke is how a
  /// directory feels slow even when it is not.
  final bool searching;

  final List<WorkCategoryCount> categories;
  final List<WorkListing> results;
  final List<MyListing> mine;

  final String? query;
  final String? activeCategory;
  final String? failure;
  final bool reported;

  /// Whether a search has actually run. Without this, "nothing found" and
  /// "you have not looked yet" render identically — and the first tells a
  /// member the app is empty when it is not.
  final bool hasSearched;

  WorkState copyWith({
    bool? loading,
    bool? searching,
    List<WorkCategoryCount>? categories,
    List<WorkListing>? results,
    List<MyListing>? mine,
    String? query,
    String? activeCategory,
    String? failure,
    bool? reported,
    bool? hasSearched,
    bool clearFailure = false,
    bool clearCategory = false,
  }) =>
      WorkState(
        loading: loading ?? this.loading,
        searching: searching ?? this.searching,
        categories: categories ?? this.categories,
        results: results ?? this.results,
        mine: mine ?? this.mine,
        query: query ?? this.query,
        activeCategory: clearCategory ? null : (activeCategory ?? this.activeCategory),
        failure: clearFailure ? null : (failure ?? this.failure),
        reported: reported ?? false,
        hasSearched: hasSearched ?? this.hasSearched,
      );

  @override
  List<Object?> get props => [
        loading, searching, categories, results, mine, query, activeCategory,
        failure, reported, hasSearched,
      ];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

class WorkBloc extends Bloc<WorkEvent, WorkState> {
  WorkBloc(this._repo) : super(const WorkState()) {
    on<WorkOpened>(_onOpened);
    on<WorkSearched>(_onSearched);
    on<ListingViewed>(_onViewed);
    on<ListingReported>(_onReported);
    on<MyListingsRequested>(_onMine);
  }

  final WorkRepository _repo;

  Future<void> _onOpened(WorkOpened ev, Emitter<WorkState> emit) async {
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      emit(state.copyWith(loading: false, categories: await _repo.categories()));
    } catch (err) {
      emit(state.copyWith(loading: false, failure: err.toString()));
    }
  }

  Future<void> _onSearched(WorkSearched ev, Emitter<WorkState> emit) async {
    emit(state.copyWith(
      searching: true,
      clearFailure: true,
      query: ev.q,
      activeCategory: ev.category,
      clearCategory: ev.category == null,
    ));
    try {
      final rows = await _repo.search(
          q: ev.q, category: ev.category, area: ev.area);
      emit(state.copyWith(
          searching: false, results: rows, hasSearched: true));
    } catch (err) {
      emit(state.copyWith(searching: false, failure: err.toString()));
    }
  }

  Future<void> _onViewed(ListingViewed ev, Emitter<WorkState> emit) async {
    // Best effort. A failed view count must never interrupt somebody trying to
    // read a phone number.
    try {
      await _repo.recordView(ev.id);
    } catch (_) {}
  }

  Future<void> _onReported(ListingReported ev, Emitter<WorkState> emit) async {
    try {
      await _repo.report(ev.id, reason: ev.reason, note: ev.note);
      emit(state.copyWith(reported: true));
    } catch (err) {
      emit(state.copyWith(failure: err.toString()));
    }
  }

  Future<void> _onMine(MyListingsRequested ev, Emitter<WorkState> emit) async {
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      emit(state.copyWith(loading: false, mine: await _repo.mine()));
    } catch (err) {
      emit(state.copyWith(loading: false, failure: err.toString()));
    }
  }
}
