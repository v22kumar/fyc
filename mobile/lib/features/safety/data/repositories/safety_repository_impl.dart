import '../../domain/entities/safety_entities.dart';
import '../../domain/repositories/safety_repository.dart';
import '../datasources/safety_datasource.dart';
import '../models/safety_models.dart';

class SafetyRepositoryImpl implements SafetyRepository {
  SafetyRepositoryImpl(this._source);

  final SafetyDataSource _source;

  @override
  Future<SosIncident> raise({
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? placeName,
    required String idempotencyKey,
  }) =>
      _source.raise({
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (placeName != null) 'place_name': placeName,
        'idempotency_key': idempotencyKey,
      });

  @override
  Future<SosIncident> load(String incidentId) => _source.load(incidentId);

  @override
  Future<SosIncident> updateLocation(
    String incidentId, {
    required double latitude,
    required double longitude,
    double? accuracyM,
    String? placeName,
  }) =>
      _source.post(incidentId, 'location', {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (placeName != null) 'place_name': placeName,
      });

  @override
  Future<SosIncident> setKind(String incidentId, SosKind kind) =>
      _source.post(incidentId, 'kind', {'kind': kindWire(kind)});

  @override
  Future<SosIncident> standDown(String incidentId,
          {String? reason, bool spokeToThem = false}) =>
      _source.post(incidentId, 'stand-down', {
        if (reason != null) 'reason': reason,
        'spoke_to_them': spokeToThem,
      });

  @override
  Future<SosIncident> reopen(String incidentId) =>
      _source.post(incidentId, 'reopen');

  @override
  Future<List<SosSummary>> mine() => _source.mine();

  @override
  Future<List<SosSummary>> live() => _source.live();

  @override
  Future<ResponderAlert> alert(String incidentId) => _source.alert(incidentId);

  @override
  Future<SosIncident> acknowledge(String incidentId) =>
      _source.post(incidentId, 'ack');

  @override
  Future<SosIncident> arrived(String incidentId) =>
      _source.post(incidentId, 'arrived');

  @override
  Future<SosIncident> decline(String incidentId) =>
      _source.post(incidentId, 'decline');

  @override
  Future<List<SafetyContact>> contacts() => _source.contacts();

  @override
  Future<SafetyContact> addContact(
          {required String name, required String phone, String? relationship}) =>
      _source.addContact({
        'name': name,
        'phone': phone,
        if (relationship != null && relationship.isNotEmpty)
          'relationship_label': relationship,
      });

  @override
  Future<void> removeContact(String contactId) =>
      _source.removeContact(contactId);

  @override
  Future<SafetyContact> testContact(String contactId) =>
      _source.testContact(contactId);

  @override
  Future<ResponderSettings> availability() => _source.availability();

  @override
  Future<ResponderSettings> setAvailability(
    ResponderSettings settings, {
    double? latitude,
    double? longitude,
  }) =>
      _source.setAvailability({
        'is_available': settings.isAvailable,
        'max_distance_m': settings.maxDistanceM,
        if (settings.quietFromHour != null)
          'quiet_from_hour': settings.quietFromHour,
        if (settings.quietToHour != null) 'quiet_to_hour': settings.quietToHour,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
}
