import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/location_probe.dart';
import '../../../../core/services/sos_service.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../../domain/repositories/safety_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class SosBlocEvent extends Equatable {
  const SosBlocEvent();
  @override
  List<Object?> get props => [];
}

/// The trigger screen opened. Work out what we can actually promise.
class ReadinessRequested extends SosBlocEvent {
  const ReadinessRequested();
}

/// The hold completed. Send it.
class SosRaised extends SosBlocEvent {
  const SosRaised();
}

class SosReloaded extends SosBlocEvent {
  const SosReloaded(this.incidentId);
  final String incidentId;
  @override
  List<Object?> get props => [incidentId];
}

class SosStoodDown extends SosBlocEvent {
  const SosStoodDown({this.reason});
  final String? reason;
  @override
  List<Object?> get props => [reason];
}

class SosReopened extends SosBlocEvent {
  const SosReopened();
}

class SosKindChosen extends SosBlocEvent {
  const SosKindChosen(this.kind);
  final e.SosKind kind;
  @override
  List<Object?> get props => [kind];
}

// ── State ────────────────────────────────────────────────────────────────────

/// What the trigger screen can honestly promise before anything is pressed.
///
/// This replaces four static green ticks — *Share live location · Alert trusted
/// contacts · Notify nearby FYC members · Works offline (SMS fallback)* — which
/// were decoration, were not state, and in the last case were simply false.
class SosReadiness extends Equatable {
  const SosReadiness({
    this.contacts = 0,
    this.isResponderRoster = false,
    this.place,
    this.accuracyM,
    this.locating = false,
  });

  final int contacts;
  final bool isResponderRoster;

  /// Where we think they are, and how sure. Null means we do not know, and the
  /// screen says so rather than showing a tick.
  final String? place;
  final double? accuracyM;
  final bool locating;

  bool get hasLocation => accuracyM != null;

  @override
  List<Object?> get props =>
      [contacts, isResponderRoster, place, accuracyM, locating];
}

class SosViewState extends Equatable {
  const SosViewState({
    this.readiness = const SosReadiness(),
    this.incident,
    this.sending = false,
    this.busy = false,
    this.failure,
    this.wentOffline = false,
  });

  final SosReadiness readiness;
  final e.SosIncident? incident;

  /// The raise call is in flight. Distinct from [busy] because the trigger
  /// screen must keep the siren and the Call 112 button working through it.
  final bool sending;
  final bool busy;
  final String? failure;

  /// The server could not be reached, so the alert fell to the phone: the SMS
  /// composer is open with the letter in it, and the incident is queued.
  ///
  /// A separate fact from [failure] because it is not a failure the member has
  /// to act on — it is the degradation ladder working, and it needs its own
  /// sentence rather than a red toast.
  final bool wentOffline;

  SosViewState copyWith({
    SosReadiness? readiness,
    e.SosIncident? incident,
    bool? sending,
    bool? busy,
    String? failure,
    bool? wentOffline,
    bool clearFailure = false,
  }) =>
      SosViewState(
        readiness: readiness ?? this.readiness,
        incident: incident ?? this.incident,
        sending: sending ?? this.sending,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
        wentOffline: wentOffline ?? this.wentOffline,
      );

  @override
  List<Object?> get props =>
      [readiness, incident, sending, busy, failure, wentOffline];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

/// Raising an SOS, and watching what happens next.
///
/// Two rules shape every handler. **Nothing here refuses**: a missing location
/// degrades the alert rather than blocking it, and a failed send leaves the
/// siren sounding and 112 one tap away. And **nothing here invents state**:
/// "somebody is coming" only ever arrives from the server, written there by
/// the responder it belongs to.
class SosBloc extends Bloc<SosBlocEvent, SosViewState> {
  SosBloc(this._repo, {LocationProbe? probe})
      : _probe = probe ?? const LocationProbe(),
        super(const SosViewState()) {
    on<ReadinessRequested>(_onReadiness);
    on<SosRaised>(_onRaise);
    on<SosReloaded>(_onReload);
    on<SosStoodDown>(_onStandDown);
    on<SosReopened>(_onReopen);
    on<SosKindChosen>(_onKind);
  }

  final SafetyRepository _repo;
  final LocationProbe _probe;

  Timer? _poll;

  /// Held for the life of one press, so a double-tap cannot raise two
  /// incidents. Cleared once the incident is over.
  String? _key;

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }

  String _reason(Object err) => err is Failure
      ? err.message
      : 'Something went wrong. Please try again.';

  Future<void> _onReadiness(
      ReadinessRequested ev, Emitter<SosViewState> emit) async {
    emit(state.copyWith(
        readiness: SosReadiness(
            contacts: state.readiness.contacts,
            isResponderRoster: state.readiness.isResponderRoster,
            locating: true)));

    // Everything below is best-effort and independent. A member whose contacts
    // fail to load must still see their location, and vice versa — this screen
    // is opened by somebody in a hurry and a single failed request must not
    // blank it.
    var contacts = 0;
    var roster = false;
    try {
      final list = await _repo.contacts();
      contacts = list.length;
      // Kept on the device for one purpose: sending from the handset when
      // there is no network to raise an incident with. Never the source of
      // truth — that moved to the server so a lost phone cannot silence it.
      await SosService.cacheContacts([
        for (final c in list) CachedContact(name: c.name, phone: c.phone)
      ]);
    } catch (_) {}
    try {
      roster = (await _repo.availability()).isAvailable;
    } catch (_) {}

    final fix = await _probe.current();
    // Anything raised while offline goes out now, before the member decides
    // whether to press again.
    unawaited(_flushPending());

    if (isClosed) return;
    emit(state.copyWith(
      readiness: SosReadiness(
        contacts: contacts,
        isResponderRoster: roster,
        place: fix?.placeName,
        accuracyM: fix?.accuracyM,
        locating: false,
      ),
    ));
  }

  Future<void> _onRaise(SosRaised ev, Emitter<SosViewState> emit) async {
    emit(state.copyWith(sending: true, clearFailure: true));

    // One key per press. A second press while the first is in flight — the
    // ordinary behaviour of a frightened thumb — resolves to the same incident
    // on the server instead of raising a duplicate.
    _key ??= 'sos-${DateTime.now().microsecondsSinceEpoch}';

    // Location is attempted but never waited on beyond its own cap, and never
    // required. "We do not know where they are" is a worse alert than a
    // located one and an infinitely better one than none.
    final fix = await _probe.current();

    try {
      final incident = await _repo.raise(
        latitude: fix?.latitude,
        longitude: fix?.longitude,
        accuracyM: fix?.accuracyM,
        placeName: fix?.placeName,
        idempotencyKey: _key!,
      );
      emit(state.copyWith(incident: incident, sending: false));
      _startPolling(incident.id);
    } on Failure catch (err) {
      // Rung three of the degradation ladder. The server is unreachable, so
      // the phone sends what it can: the SMS composer opens pre-filled to the
      // cached trusted contacts, and the incident is kept until there is a
      // network to post it on. Nothing here claims to have *sent* anything —
      // the member still has to press send in the SMS app, and the screen
      // says so.
      final handled = await _fallBackToSms(fix);
      if (isClosed) return;
      emit(state.copyWith(
        sending: false,
        wentOffline: handled,
        failure: handled ? null : _reason(err),
      ));
    } catch (err) {
      if (isClosed) return;
      emit(state.copyWith(sending: false, failure: _reason(err)));
    }
  }

  /// Returns true when the phone managed to do something useful.
  Future<bool> _fallBackToSms(LocationFix? fix) async {
    try {
      await SosService.queuePending({
        'latitude': fix?.latitude,
        'longitude': fix?.longitude,
        'accuracy_m': fix?.accuracyM,
        'place_name': fix?.placeName,
        'idempotency_key': _key,
        'at': DateTime.now().toIso8601String(),
      });

      final contacts = await SosService.cachedContacts();
      if (contacts.isEmpty) return false;

      return SosService.composeSms(
        [for (final c in contacts) c.phone],
        SosService.offlineMessage(
            latitude: fix?.latitude, longitude: fix?.longitude),
      );
    } catch (_) {
      return false;
    }
  }

  /// Post an SOS that was raised with no network.
  ///
  /// Called when the trigger screen next opens. A queued incident that is
  /// never retried is a member who pressed the button, watched it fail, and
  /// has no record that they ever tried.
  Future<void> _flushPending() async {
    final pending = await SosService.takePending();
    if (pending == null) return;
    try {
      await _repo.raise(
        latitude: (pending['latitude'] as num?)?.toDouble(),
        longitude: (pending['longitude'] as num?)?.toDouble(),
        accuracyM: (pending['accuracy_m'] as num?)?.toDouble(),
        placeName: pending['place_name'] as String?,
        idempotencyKey: (pending['idempotency_key'] as String?) ??
            'sos-queued-${pending['at']}',
      );
    } catch (_) {
      // Still no network. Put it back rather than losing it.
      await SosService.queuePending(pending);
    }
  }

  /// Refresh while it is live.
  ///
  /// Polling rather than a socket: this runs for a few minutes at most, on a
  /// phone that may be on a bad connection, and a dropped socket that silently
  /// stops updating is worse here than anywhere else in the app.
  void _startPolling(String incidentId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isClosed) return;
      add(SosReloaded(incidentId));
    });
  }

  Future<void> _onReload(SosReloaded ev, Emitter<SosViewState> emit) async {
    try {
      final incident = await _repo.load(ev.incidentId);
      emit(state.copyWith(incident: incident));
      if (!incident.isOpen) {
        _poll?.cancel();
        _poll = null;
      }
    } catch (_) {
      // A failed refresh is not worth a message. The screen keeps showing what
      // it last knew, which is still true, and the next tick tries again.
    }
  }

  Future<void> _guard(
    Emitter<SosViewState> emit,
    Future<e.SosIncident> Function() action,
  ) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      emit(state.copyWith(incident: await action(), busy: false));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    }
  }

  Future<void> _onStandDown(SosStoodDown ev, Emitter<SosViewState> emit) async {
    final id = state.incident?.id;
    if (id == null) return;
    _poll?.cancel();
    _poll = null;
    _key = null;
    await _guard(emit, () => _repo.standDown(id, reason: ev.reason));
  }

  Future<void> _onReopen(SosReopened ev, Emitter<SosViewState> emit) async {
    final id = state.incident?.id;
    if (id == null) return;
    await _guard(emit, () => _repo.reopen(id));
    _startPolling(id);
  }

  Future<void> _onKind(SosKindChosen ev, Emitter<SosViewState> emit) async {
    final id = state.incident?.id;
    if (id == null) return;
    await _guard(emit, () => _repo.setKind(id, ev.kind));
  }
}
