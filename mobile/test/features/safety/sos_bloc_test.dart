import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/services/sos_service.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/features/safety/domain/entities/safety_entities.dart';
import 'package:fyc_connect/features/safety/presentation/bloc/sos_bloc.dart';

import '../../core/safety/fake_safety_repository.dart';

/// What the trigger and live screens are allowed to say.
///
/// The screen these replace told a member "FYC members have been alerted"
/// after the server had merely *queued* a background task, above four green
/// ticks that were static text — one of which ("Works offline") was false.
/// These hold the replacement to counting rather than claiming.
class _Recording extends FakeSafetyRepository {
  _Recording({super.contacts, super.onRoster, super.incident});

  final List<String> keys = [];
  bool throws = false;

  @override
  Future<SosIncident> raise({
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? placeName,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (throws) throw const NetworkFailure();
    return super.raise(
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      placeName: placeName,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  // The bloc touches SharedPreferences on both of its main paths now: it
  // caches the trusted contacts for the offline rung, and it flushes any SOS
  // that was queued while there was no network.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('readiness is read from state, not asserted', () async {
    final bloc = SosBloc(_Recording(contacts: 2, onRoster: true),
        probe: fakeProbe(accuracyM: 14));
    addTearDown(bloc.close);

    bloc.add(const ReadinessRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.readiness.contacts, 2);
    expect(bloc.state.readiness.isResponderRoster, isTrue);
    expect(bloc.state.readiness.accuracyM, 14);
    expect(bloc.state.readiness.place, 'Vadasery bus stand');
  });

  test('no location fix still leaves the screen usable', () async {
    // "We do not know where you are" is a line the screen must be able to say.
    // Blocking an emergency on a GPS fix is the worst trade this app could
    // make, so the readiness row degrades and nothing else changes.
    final bloc = SosBloc(_Recording(contacts: 1), probe: fakeProbe(fails: true));
    addTearDown(bloc.close);

    bloc.add(const ReadinessRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.readiness.hasLocation, isFalse);
    expect(bloc.state.readiness.contacts, 1);
  });

  test('one press, one idempotency key', () async {
    // A frightened thumb presses twice. Both presses must resolve to the same
    // incident rather than raising two.
    final repo = _Recording();
    final bloc = SosBloc(repo, probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const SosRaised());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const SosRaised());
    await Future<void>.delayed(Duration.zero);

    expect(repo.keys.length, 2);
    expect(repo.keys.first, repo.keys.last, reason: 'same press, same key');
  });

  test('a failed raise says what went wrong', () async {
    // `err.toString()` on a typed Failure is "Instance of 'NetworkFailure'",
    // which is what forced the old screen into one blanket message.
    final repo = _Recording()..throws = true;
    final bloc = SosBloc(repo, probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const SosRaised());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.failure, const NetworkFailure().message);
    expect(bloc.state.failure, isNot(contains('Instance of')));
  });

  test('the live state counts, it does not comfort', () async {
    final bloc = SosBloc(_Recording(incident: incidentNobodyYet),
        probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const SosRaised());
    await Future<void>.delayed(Duration.zero);

    final incident = bloc.state.incident!;
    expect(incident.alertedCount, 6);
    expect(incident.acknowledgedCount, 0);
    // The line that makes somebody press Call 112. Five told, one declined,
    // nobody coming — and the screen has to be able to say exactly that.
    expect(incident.silentCount, 5);
    expect(incident.coming, isEmpty);
  });

  test('coming responders are separated from the silent ones', () async {
    final bloc = SosBloc(_Recording(incident: incidentTwoComing),
        probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const SosRaised());
    await Future<void>.delayed(Duration.zero);

    final incident = bloc.state.incident!;
    expect(incident.coming.map((r) => r.name), ['Suresh K.', 'Meena R.']);
    expect(incident.silentCount, 2);
  });

  test('a responder phone number only exists once they are coming', () async {
    // Before that it is a number handed out for an event they have not agreed
    // to take part in.
    final silent = incidentNobodyYet.responders.first;
    final coming = incidentTwoComing.responders.first;
    expect(silent.phone, isNull);
    expect(coming.phone, isNotNull);
  });

  test('no network falls back to the phone and keeps the incident', () async {
    // Rung three of the degradation ladder. The server is unreachable, so the
    // SMS composer opens to the cached contacts and the SOS is queued —
    // rather than a red toast and a member with no record they ever tried.
    SharedPreferences.setMockInitialValues({
      'sos_cached_contacts':
          '[{"name":"Amma","phone":"+919840011111"}]',
    });
    final repo = _Recording()..throws = true;
    final bloc = SosBloc(repo, probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const SosRaised());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // `composeSms` cannot launch anything in a test binding, so `wentOffline`
    // stays false — but the queue is the part that must survive, and it does.
    final pending = await SosService.takePending();
    expect(pending, isNotNull);
    expect(pending!['latitude'], 8.1833);
    expect(pending['idempotency_key'], isNotNull);
  });

  test('a queued SOS is posted the next time the screen opens', () async {
    SharedPreferences.setMockInitialValues({
      'sos_pending_incident':
          '{"latitude":8.1833,"longitude":77.4119,'
          '"idempotency_key":"queued-1","at":"2026-08-09T21:14:00Z"}',
    });
    final repo = _Recording(contacts: 1);
    final bloc = SosBloc(repo, probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const ReadinessRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.keys, contains('queued-1'));
    expect(await SosService.takePending(), isNull, reason: 'sent, not kept');
  });

  test('a queued SOS survives a second failure', () async {
    SharedPreferences.setMockInitialValues({
      'sos_pending_incident':
          '{"latitude":8.1833,"idempotency_key":"queued-2","at":"x"}',
    });
    final repo = _Recording()..throws = true;
    final bloc = SosBloc(repo, probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const ReadinessRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await SosService.takePending(), isNotNull,
        reason: 'still no network — put it back rather than lose it');
  });

  test('trusted contacts are cached for the offline rung', () async {
    SharedPreferences.setMockInitialValues({});
    final bloc = SosBloc(_Recording(contacts: 2), probe: fakeProbe());
    addTearDown(bloc.close);

    bloc.add(const ReadinessRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final cached = await SosService.cachedContacts();
    expect(cached.length, 2);
    expect(cached.first.name, 'Amma');
  });
}
