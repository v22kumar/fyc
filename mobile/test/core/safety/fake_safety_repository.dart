import 'package:fyc_connect/core/services/location_probe.dart';
import 'package:fyc_connect/features/safety/domain/entities/safety_entities.dart';
import 'package:fyc_connect/features/safety/domain/repositories/safety_repository.dart';

/// A location probe that answers instantly, so a screen test never waits on a
/// GPS fix that will never arrive in a headless container.
LocationProbe fakeProbe({double accuracyM = 12, bool fails = false}) =>
    _FakeProbe(accuracyM: accuracyM, fails: fails);

class _FakeProbe implements LocationProbe {
  const _FakeProbe({required this.accuracyM, required this.fails});

  final double accuracyM;
  final bool fails;

  @override
  Duration get timeout => const Duration(seconds: 1);

  @override
  Future<LocationFix?> current() async => fails
      ? null
      : LocationFix(
          latitude: 8.1833,
          longitude: 77.4119,
          accuracyM: accuracyM,
          at: DateTime(2026, 8, 9, 21, 14),
          placeName: 'Vadasery bus stand',
        );
}

final _base = DateTime(2026, 8, 9, 21, 14);

SosResponder _r(String name, int metres,
        {bool coming = false, bool declined = false}) =>
    SosResponder(
      userId: name,
      name: name,
      wave: 1,
      distanceM: metres,
      notifiedAt: _base,
      acknowledgedAt: coming ? _base.add(const Duration(seconds: 20)) : null,
      declinedAt: declined ? _base.add(const Duration(seconds: 15)) : null,
      phone: coming ? '+919840000001' : null,
    );

/// The ordinary case. Response rates run 17–47%, so this is what most members
/// will actually be looking at, and it has to read honestly.
final incidentNobodyYet = SosIncident(
  id: 'i1',
  status: SosStatus.widening,
  raisedByName: 'Arun Kumar',
  createdAt: _base,
  placeName: 'Vadasery bus stand, Nagercoil',
  latitude: 8.1833,
  longitude: 77.4119,
  accuracyM: 12,
  wave: 2,
  radiusM: 3000,
  alertedCount: 6,
  contactsNotified: 2,
  responders: [
    _r('Suresh K.', 300),
    _r('Meena R.', 800),
    _r('Vijay S.', 1200),
    _r('Latha M.', 1900, declined: true),
    _r('Prakash N.', 2400),
    _r('Devi A.', 2800),
  ],
  events: const [],
);

final incidentTwoComing = SosIncident(
  id: 'i1',
  status: SosStatus.acknowledged,
  raisedByName: 'Arun Kumar',
  createdAt: _base,
  placeName: 'Vadasery bus stand, Nagercoil',
  latitude: 8.1833,
  longitude: 77.4119,
  accuracyM: 12,
  wave: 1,
  radiusM: 1000,
  alertedCount: 5,
  contactsNotified: 2,
  acknowledgedCount: 2,
  responders: [
    _r('Suresh K.', 300, coming: true),
    _r('Meena R.', 800, coming: true),
    _r('Vijay S.', 950),
    _r('Latha M.', 990),
  ],
  events: const [],
);

final alertAsked = ResponderAlert(
  incidentId: 'i1',
  raisedByName: 'Arun Kumar',
  raisedAt: _base,
  status: SosStatus.raised,
  distanceM: 300,
  placeName: 'Vadasery bus stand',
  latitude: 8.1833,
  longitude: 77.4119,
  accuracyM: 12,
);

/// Answers from fixed data, so the screens can be driven without a server.
class FakeSafetyRepository implements SafetyRepository {
  FakeSafetyRepository({
    this.onRoster = false,
    SosIncident? incident,
    ResponderAlert? alert,
    int contacts = 0,
  })  : _incident = incident ?? incidentNobodyYet,
        _alert = alert ?? alertAsked,
        _contacts = List.generate(
          contacts,
          (i) => SafetyContact(
            id: 'c$i',
            name: i == 0 ? 'Amma' : 'Appa',
            phone: '+9198400${i}1111',
            relationship: i == 0 ? 'Mother' : 'Father',
            verifiedAt: i == 0 ? _base : null,
            position: i,
          ),
        );

  final bool onRoster;
  final SosIncident _incident;
  final ResponderAlert _alert;
  final List<SafetyContact> _contacts;

  @override
  Future<SosIncident> raise({
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? placeName,
    required String idempotencyKey,
  }) async =>
      _incident;

  @override
  Future<SosIncident> load(String incidentId) async => _incident;

  @override
  Future<SosIncident> updateLocation(String incidentId,
          {required double latitude,
          required double longitude,
          double? accuracyM,
          String? placeName}) async =>
      _incident;

  @override
  Future<SosIncident> setKind(String incidentId, SosKind kind) async => _incident;

  @override
  Future<SosIncident> standDown(String incidentId,
          {String? reason, bool spokeToThem = false}) async =>
      _incident;

  @override
  Future<SosIncident> reopen(String incidentId) async => _incident;

  @override
  Future<List<SosSummary>> mine() async => const [];

  @override
  Future<List<SosSummary>> live() async => const [];

  @override
  Future<ResponderAlert> alert(String incidentId) async => _alert;

  @override
  Future<SosIncident> acknowledge(String incidentId) async => _incident;

  @override
  Future<SosIncident> arrived(String incidentId) async => _incident;

  @override
  Future<SosIncident> decline(String incidentId) async => _incident;

  @override
  Future<List<SafetyContact>> contacts() async => _contacts;

  @override
  Future<SafetyContact> addContact(
          {required String name,
          required String phone,
          String? relationship}) async =>
      SafetyContact(id: 'new', name: name, phone: phone);

  @override
  Future<void> removeContact(String contactId) async {}

  @override
  Future<SafetyContact> testContact(String contactId) async =>
      SafetyContact(id: contactId, name: 'Amma', phone: '+919840011111',
          verifiedAt: DateTime(2026, 8, 9));

  @override
  Future<ResponderSettings> availability() async =>
      ResponderSettings(isAvailable: onRoster, maxDistanceM: 2000);

  @override
  Future<ResponderSettings> setAvailability(ResponderSettings settings,
          {double? latitude, double? longitude}) async =>
      settings;
}
