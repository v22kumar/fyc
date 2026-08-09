import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/location_probe.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../../domain/repositories/safety_repository.dart';

abstract class SetupEvent extends Equatable {
  const SetupEvent();
  @override
  List<Object?> get props => [];
}

class SetupRequested extends SetupEvent {
  const SetupRequested();
}

class ContactAdded extends SetupEvent {
  const ContactAdded({required this.name, required this.phone, this.relationship});
  final String name;
  final String phone;
  final String? relationship;
  @override
  List<Object?> get props => [name, phone];
}

class ContactRemoved extends SetupEvent {
  const ContactRemoved(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ContactTested extends SetupEvent {
  const ContactTested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class AvailabilityChanged extends SetupEvent {
  const AvailabilityChanged(this.settings);
  final e.ResponderSettings settings;
  @override
  List<Object?> get props => [settings];
}

class SetupState extends Equatable {
  const SetupState({
    this.loading = false,
    this.contacts = const [],
    this.settings = const e.ResponderSettings(),
    this.busy = false,
    this.failure,
    this.testSent = false,
  });

  final bool loading;
  final List<e.SafetyContact> contacts;
  final e.ResponderSettings settings;
  final bool busy;
  final String? failure;

  /// A test message just went. Drives one acknowledgement, then clears.
  final bool testSent;

  SetupState copyWith({
    bool? loading,
    List<e.SafetyContact>? contacts,
    e.ResponderSettings? settings,
    bool? busy,
    String? failure,
    bool clearFailure = false,
    bool testSent = false,
  }) =>
      SetupState(
        loading: loading ?? this.loading,
        contacts: contacts ?? this.contacts,
        settings: settings ?? this.settings,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
        testSent: testSent,
      );

  @override
  List<Object?> get props =>
      [loading, contacts, settings, busy, failure, testSent];
}

/// Setting up, in advance, the things an emergency has no time for.
class SafetySetupBloc extends Bloc<SetupEvent, SetupState> {
  SafetySetupBloc(this._repo, {LocationProbe? probe})
      : _probe = probe ?? const LocationProbe(),
        super(const SetupState()) {
    on<SetupRequested>(_onLoad);
    on<ContactAdded>(_onAdd);
    on<ContactRemoved>(_onRemove);
    on<ContactTested>(_onTest);
    on<AvailabilityChanged>(_onAvailability);
  }

  final SafetyRepository _repo;
  final LocationProbe _probe;

  String _reason(Object err) => err is Failure
      ? err.message
      : 'Something went wrong. Please try again.';

  Future<void> _onLoad(SetupRequested ev, Emitter<SetupState> emit) async {
    emit(state.copyWith(loading: true, clearFailure: true));
    try {
      final contacts = await _repo.contacts();
      final settings = await _repo.availability();
      emit(state.copyWith(
          loading: false, contacts: contacts, settings: settings));
    } catch (err) {
      emit(state.copyWith(loading: false, failure: _reason(err)));
    }
  }

  Future<void> _onAdd(ContactAdded ev, Emitter<SetupState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      await _repo.addContact(
          name: ev.name, phone: ev.phone, relationship: ev.relationship);
      emit(state.copyWith(busy: false, contacts: await _repo.contacts()));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    }
  }

  Future<void> _onRemove(ContactRemoved ev, Emitter<SetupState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      await _repo.removeContact(ev.id);
      emit(state.copyWith(busy: false, contacts: await _repo.contacts()));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    }
  }

  Future<void> _onTest(ContactTested ev, Emitter<SetupState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      final updated = await _repo.testContact(ev.id);
      final contacts = await _repo.contacts();
      // `verified_at` stays null when the deployment cannot send. Saying "sent"
      // anyway would be the same lie as the four green ticks this replaced.
      emit(state.copyWith(
          busy: false, contacts: contacts, testSent: updated.isTested));
      if (!updated.isTested) {
        emit(state.copyWith(
            failure: 'Could not send a test message from here.'));
      }
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    }
  }

  Future<void> _onAvailability(
      AvailabilityChanged ev, Emitter<SetupState> emit) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      // Joining the roster needs a rough position to rank against; leaving it
      // sends none, and the server deletes what it had.
      final fix = ev.settings.isAvailable ? await _probe.current() : null;
      final saved = await _repo.setAvailability(
        ev.settings,
        latitude: fix?.latitude,
        longitude: fix?.longitude,
      );
      emit(state.copyWith(busy: false, settings: saved));
    } catch (err) {
      emit(state.copyWith(busy: false, failure: _reason(err)));
    }
  }
}
