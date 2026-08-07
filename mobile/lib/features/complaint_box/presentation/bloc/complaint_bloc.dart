import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/complaint_entities.dart' as e;
import '../../domain/repositories/complaint_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ComplaintBlocEvent extends Equatable {
  const ComplaintBlocEvent();
  @override
  List<Object?> get props => [];
}

class LoadComplaint extends ComplaintBlocEvent {
  const LoadComplaint(this.id, {this.category});
  final String id;
  final String? category;
  @override
  List<Object?> get props => [id, category];
}

class CallLogged extends ComplaintBlocEvent {
  const CallLogged({required this.outcome, this.authorityId, this.authorityLabel});
  final e.CallOutcome outcome;
  final String? authorityId;
  final String? authorityLabel;
  @override
  List<Object?> get props => [outcome, authorityId];
}

class DraftRequested extends ComplaintBlocEvent {
  const DraftRequested({this.authorityId, this.bccClub = true});
  final String? authorityId;
  final bool bccClub;
  @override
  List<Object?> get props => [authorityId, bccClub];
}

class SendConfirmed extends ComplaintBlocEvent {
  const SendConfirmed({this.authorityLabel});
  final String? authorityLabel;
  @override
  List<Object?> get props => [authorityLabel];
}

class ReplyRecorded extends ComplaintBlocEvent {
  const ReplyRecorded({this.note});
  final String? note;
  @override
  List<Object?> get props => [note];
}

class Closed extends ComplaintBlocEvent {
  const Closed({required this.resolved, this.reason});
  final bool resolved;
  final String? reason;
  @override
  List<Object?> get props => [resolved, reason];
}

class Reopened extends ComplaintBlocEvent {
  const Reopened();
}

class HandedToClub extends ComplaintBlocEvent {
  const HandedToClub();
}

// ── State ────────────────────────────────────────────────────────────────────

class ComplaintViewState extends Equatable {
  const ComplaintViewState({
    this.loading = false,
    this.complaint,
    this.ladder,
    this.draft,
    this.failure,
    this.busy = false,
    this.ladderFailed = false,
  });

  final bool loading;
  final e.ComplaintState? complaint;
  final e.CallLadder? ladder;

  /// Set once a draft exists, so the screen can hand it to the member's mail
  /// app. Cleared after use — a stale draft on screen is worse than none.
  final e.ComplaintDraft? draft;

  final String? failure;

  /// An action is in flight. Separate from [loading] so the timeline stays on
  /// screen while a call is being logged.
  final bool busy;

  /// The ladder request failed, as opposed to coming back empty. "We have no
  /// offices for this" and "your connection dropped" need different words and
  /// different buttons.
  final bool ladderFailed;

  ComplaintViewState copyWith({
    bool? loading,
    e.ComplaintState? complaint,
    e.CallLadder? ladder,
    e.ComplaintDraft? draft,
    String? failure,
    bool? busy,
    bool? ladderFailed,
    bool clearDraft = false,
    bool clearFailure = false,
  }) =>
      ComplaintViewState(
        loading: loading ?? this.loading,
        complaint: complaint ?? this.complaint,
        ladder: ladder ?? this.ladder,
        draft: clearDraft ? null : (draft ?? this.draft),
        failure: clearFailure ? null : (failure ?? this.failure),
        busy: busy ?? this.busy,
        ladderFailed: ladderFailed ?? this.ladderFailed,
      );

  @override
  List<Object?> get props =>
      [loading, complaint, ladder, draft, failure, busy, ladderFailed];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

/// Drives one complaint.
///
/// Every event here is somebody *stating* something — the member rang, the
/// member sent it, somebody replied. None is the app deciding. In the direct
/// lane the app cannot see what happened after it handed the draft to a mail
/// application, and a status it invented would be wrong on screen in front of
/// somebody standing at a government counter.
class ComplaintBloc extends Bloc<ComplaintBlocEvent, ComplaintViewState> {
  ComplaintBloc(this._repo) : super(const ComplaintViewState()) {
    on<LoadComplaint>(_onLoad);
    on<CallLogged>(_onCall);
    on<DraftRequested>(_onDraft);
    on<SendConfirmed>(_onSent);
    on<ReplyRecorded>(_onReply);
    on<Closed>(_onClose);
    on<Reopened>(_onReopen);
    on<HandedToClub>(_onHandover);
  }

  final ComplaintRepository _repo;
  String? _id;

  Future<void> _guard(
    Emitter<ComplaintViewState> emit,
    Future<e.ComplaintState> Function() action,
  ) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      emit(state.copyWith(complaint: await action(), busy: false));
    } catch (err) {
      emit(state.copyWith(failure: err.toString(), busy: false));
    }
  }

  Future<void> _onLoad(LoadComplaint ev, Emitter<ComplaintViewState> emit) async {
    _id = ev.id;
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      final complaint = await _repo.load(ev.id);
      // Fetched alongside, because the first question on the screen is "who do
      // I call" and it should not need a second wait.
      e.CallLadder? ladder;
      var ladderFailed = false;
      if (ev.category != null) {
        try {
          ladder = await _repo.ladder(category: ev.category!);
        } catch (_) {
          // A missing ladder is a directory gap, not a reason to fail the
          // screen — the member can still write, or hand it to the club.
          //
          // But a *failed request* is not a directory gap, and the two used to
          // render identically: "no office listed for this yet" was shown to
          // somebody whose train had gone into a tunnel. They are now
          // distinguishable, so the screen can offer a retry instead of a
          // shrug.
          ladderFailed = true;
        }
      }
      emit(state.copyWith(
          loading: false,
          complaint: complaint,
          ladder: ladder,
          ladderFailed: ladderFailed));
    } catch (err) {
      emit(state.copyWith(loading: false, failure: err.toString()));
    }
  }

  Future<void> _onCall(CallLogged ev, Emitter<ComplaintViewState> emit) =>
      _guard(
          emit,
          () => _repo.logCall(_id!,
              outcome: ev.outcome,
              authorityId: ev.authorityId,
              authorityLabel: ev.authorityLabel));

  Future<void> _onDraft(DraftRequested ev, Emitter<ComplaintViewState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true, clearDraft: true));
    try {
      final draft = await _repo.draft(_id!,
          authorityId: ev.authorityId, bccClub: ev.bccClub);
      final refreshed = await _repo.load(_id!);
      emit(state.copyWith(draft: draft, complaint: refreshed, busy: false));
    } catch (err) {
      emit(state.copyWith(failure: err.toString(), busy: false));
    }
  }

  Future<void> _onSent(SendConfirmed ev, Emitter<ComplaintViewState> emit) =>
      _guard(emit, () => _repo.markSent(_id!, authorityLabel: ev.authorityLabel));

  Future<void> _onReply(ReplyRecorded ev, Emitter<ComplaintViewState> emit) =>
      _guard(emit, () => _repo.markReplied(_id!, note: ev.note));

  Future<void> _onClose(Closed ev, Emitter<ComplaintViewState> emit) => _guard(
      emit, () => _repo.close(_id!, resolved: ev.resolved, reason: ev.reason));

  Future<void> _onReopen(Reopened ev, Emitter<ComplaintViewState> emit) =>
      _guard(emit, () => _repo.reopen(_id!));

  Future<void> _onHandover(HandedToClub ev, Emitter<ComplaintViewState> emit) =>
      _guard(emit, () => _repo.handToClub(_id!));
}
