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
  const LoadComplaint(this.id, {this.category, this.latitude, this.longitude});
  final String id;
  final String? category;

  /// Where the problem is. Without these the server cannot tell whether the
  /// report is inside the district the club's directory covers, and used to
  /// assume it was — routing a Bengaluru pothole to Nagercoil.
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [id, category, latitude, longitude];
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

/// The letter sheet closed. Throws the draft away.
///
/// Without this the draft stayed in state after the sheet was dismissed, so
/// asking for a second one left the screen unable to tell a fresh draft from
/// the one already sitting there — and the sheet never reopened.
class DraftDismissed extends ComplaintBlocEvent {
  const DraftDismissed();
}

class ContactSuggested extends ComplaintBlocEvent {
  const ContactSuggested({
    required this.authorityId,
    this.phone,
    this.email,
    this.howTheyKnow,
  });
  final String authorityId;
  final String? phone;
  final String? email;
  final String? howTheyKnow;
  @override
  List<Object?> get props => [authorityId, phone, email];
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
    this.contactSuggested = false,
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

  /// A suggestion just went to the club. Drives one acknowledgement, then
  /// cleared — the ladder itself must not change until somebody approves it.
  final bool contactSuggested;

  ComplaintViewState copyWith({
    bool? loading,
    e.ComplaintState? complaint,
    e.CallLadder? ladder,
    e.ComplaintDraft? draft,
    String? failure,
    bool? busy,
    bool? ladderFailed,
    bool? contactSuggested,
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
        contactSuggested: contactSuggested ?? false,
      );

  @override
  List<Object?> get props =>
      [loading, complaint, ladder, draft, failure, busy, ladderFailed,
        contactSuggested];
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
    on<ContactSuggested>(_onSuggestContact);
    on<DraftDismissed>((_, emit) => emit(state.copyWith(clearDraft: true)));
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
          ladder = await _repo.ladder(
            category: ev.category!,
            latitude: ev.latitude,
            longitude: ev.longitude,
          );
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

  Future<void> _onSuggestContact(
      ContactSuggested ev, Emitter<ComplaintViewState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      await _repo.suggestContact(ev.authorityId,
          phone: ev.phone, email: ev.email, howTheyKnow: ev.howTheyKnow);
      // The ladder is deliberately not refetched. Nothing has changed on it
      // yet and nothing should appear to — the suggestion is waiting for an
      // organiser, and showing the number as though it were live would be the
      // app claiming something nobody has approved.
      emit(state.copyWith(busy: false, contactSuggested: true));
    } catch (err) {
      emit(state.copyWith(failure: err.toString(), busy: false));
    }
  }
}
