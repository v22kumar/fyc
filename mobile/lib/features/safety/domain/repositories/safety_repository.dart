import '../entities/safety_entities.dart';

/// What the safety feature can do.
///
/// Note what is absent, as in the Complaint Box: there is no `setStatus` and
/// no `markSafe(userId)`. Every state change here is somebody *stating*
/// something about themselves — [acknowledge] is a responder saying they are
/// coming, [standDown] is the member saying they are safe. Nothing lets one
/// person assert another's state, and no timer asserts anybody's.
abstract class SafetyRepository {
  /// Press the button.
  ///
  /// [idempotencyKey] exists because a panicking thumb presses twice. Same
  /// key, same incident.
  Future<SosIncident> raise({
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? placeName,
    required String idempotencyKey,
  });

  Future<SosIncident> load(String incidentId);

  /// A fresher fix while it is still live.
  Future<SosIncident> updateLocation(
    String incidentId, {
    required double latitude,
    required double longitude,
    double? accuracyM,
    String? placeName,
  });

  /// Say what it is, after the alert has already gone. Never before.
  Future<SosIncident> setKind(String incidentId, SosKind kind);

  /// "I'm safe." [spokeToThem] is only for organisers ending somebody else's.
  Future<SosIncident> standDown(String incidentId,
      {String? reason, bool spokeToThem = false});

  Future<SosIncident> reopen(String incidentId);

  Future<List<SosSummary>> mine();

  /// Organisers only: what is happening right now.
  Future<List<SosSummary>> live();

  // ── Answering somebody else's ──────────────────────────────────────────
  Future<ResponderAlert> alert(String incidentId);
  Future<SosIncident> acknowledge(String incidentId);
  Future<SosIncident> arrived(String incidentId);

  /// "Can't." Worth as much as "I'm coming": once everybody in a wave has
  /// declined, the ring widens immediately instead of waiting out the timer.
  Future<SosIncident> decline(String incidentId);

  // ── Setup ──────────────────────────────────────────────────────────────
  Future<List<SafetyContact>> contacts();
  Future<SafetyContact> addContact(
      {required String name, required String phone, String? relationship});
  Future<void> removeContact(String contactId);

  /// Send a test message, so nobody discovers a wrong number in an emergency.
  Future<SafetyContact> testContact(String contactId);

  Future<ResponderSettings> availability();
  Future<ResponderSettings> setAvailability(
    ResponderSettings settings, {
    double? latitude,
    double? longitude,
  });
}
