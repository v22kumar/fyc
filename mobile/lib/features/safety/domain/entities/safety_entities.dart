/// What the safety feature is made of.
///
/// The shape to notice is [SosIncident.responders]: every person who was told,
/// with what each of them did — not a single "help is coming" flag. Published
/// response rates for volunteer first responders run 17–47%, so *told, no
/// answer yet* is the normal case, and a screen that cannot say it will tell
/// somebody in trouble that help is on the way when nobody is.
library;

import 'package:equatable/equatable.dart';

/// Where an incident stands.
///
/// The three dispatch rings are separate states because a member watching the
/// screen should be able to see the ring widening. It is the only thing
/// happening while nobody answers.
enum SosStatus { raised, widening, escalated, acknowledged, stoodDown }

enum SosKind { medical, threat, accident, fire, other }

/// Who said so. There is no `inferred`, and there will not be.
enum SosAuthor { member, responder, club, system }

/// One person who was told, and what they did about it.
class SosResponder extends Equatable {
  const SosResponder({
    required this.userId,
    required this.name,
    required this.wave,
    this.distanceM,
    this.notifiedAt,
    this.acknowledgedAt,
    this.arrivedAt,
    this.declinedAt,
    this.phone,
  });

  final String userId;
  final String name;
  final int wave;

  /// Frozen at dispatch. The single most useful number on the screen: 300 m
  /// and 3 km are different answers to "is anybody actually coming".
  final int? distanceM;

  final DateTime? notifiedAt;
  final DateTime? acknowledgedAt;
  final DateTime? arrivedAt;
  final DateTime? declinedAt;

  /// Only present once they have said they are coming.
  final String? phone;

  bool get isComing => acknowledgedAt != null;
  bool get hasArrived => arrivedAt != null;
  bool get hasDeclined => declinedAt != null;

  /// Told, and has not answered. Not a failure — the ordinary case.
  bool get isSilent => acknowledgedAt == null && declinedAt == null;

  @override
  List<Object?> get props =>
      [userId, wave, acknowledgedAt, arrivedAt, declinedAt];
}

/// One thing that happened, and who says so.
class SosEvent extends Equatable {
  const SosEvent({
    required this.id,
    required this.author,
    required this.type,
    required this.at,
    this.authorName,
    this.detail,
  });

  final String id;
  final SosAuthor author;
  final String type;
  final DateTime at;
  final String? authorName;
  final String? detail;

  @override
  List<Object?> get props => [id, type, at];
}

/// One SOS, from the press to the stand-down.
class SosIncident extends Equatable {
  const SosIncident({
    required this.id,
    required this.status,
    required this.raisedByName,
    required this.createdAt,
    required this.responders,
    required this.events,
    this.kind,
    this.raisedByUserId,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locatedAt,
    this.placeName,
    this.wave = 0,
    this.radiusM,
    this.alertedCount = 0,
    this.contactsNotified = 0,
    this.acknowledgedCount = 0,
    this.isThrottled = false,
    this.isOpen = true,
    this.stoodDownAt,
    this.stoodDownReason,
  });

  final String id;
  final SosStatus status;
  final SosKind? kind;
  final String? raisedByUserId;
  final String raisedByName;
  final DateTime createdAt;

  final double? latitude;
  final double? longitude;

  /// Metres. Shown, because a responder must be able to tell a 12 m fix from
  /// a 2 km one before they set off.
  final double? accuracyM;
  final DateTime? locatedAt;
  final String? placeName;

  final int wave;
  final int? radiusM;

  /// How many were told. An observed number, not a reassurance — the screen
  /// this replaces said "FYC members have been alerted" after the server had
  /// merely queued a job.
  final int alertedCount;
  final int contactsNotified;
  final int acknowledgedCount;

  final bool isThrottled;
  final bool isOpen;
  final DateTime? stoodDownAt;
  final String? stoodDownReason;

  final List<SosResponder> responders;
  final List<SosEvent> events;

  bool get hasLocation => latitude != null && longitude != null;

  /// Told and silent. Rendered as its own line rather than folded into the
  /// alerted count, because "six people know" and "nobody has answered" are
  /// both true and the second one is what makes somebody press Call 112.
  int get silentCount => responders.where((r) => r.isSilent).length;

  List<SosResponder> get coming =>
      responders.where((r) => r.isComing).toList(growable: false);

  @override
  List<Object?> get props =>
      [id, status, wave, alertedCount, acknowledgedCount, isOpen, responders];
}

/// One row in a history or an organiser's board.
class SosSummary extends Equatable {
  const SosSummary({
    required this.id,
    required this.status,
    required this.raisedByName,
    required this.createdAt,
    this.kind,
    this.raisedByUserId,
    this.placeName,
    this.alertedCount = 0,
    this.acknowledgedCount = 0,
    this.isOpen = true,
    this.isThrottled = false,
    this.stoodDownAt,
  });

  final String id;
  final SosStatus status;
  final SosKind? kind;
  final String? raisedByUserId;
  final String raisedByName;
  final String? placeName;
  final int alertedCount;
  final int acknowledgedCount;
  final bool isOpen;
  final bool isThrottled;
  final DateTime createdAt;
  final DateTime? stoodDownAt;

  @override
  List<Object?> get props => [id, status, isOpen, acknowledgedCount];
}

/// What a responder is shown when they tap the push.
///
/// Three facts and two buttons. Distance and how long ago are what decide
/// whether somebody goes, and neither survives being buried in a notification.
class ResponderAlert extends Equatable {
  const ResponderAlert({
    required this.incidentId,
    required this.raisedByName,
    required this.raisedAt,
    required this.status,
    this.distanceM,
    this.placeName,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.myAcknowledgedAt,
    this.myDeclinedAt,
    this.myArrivedAt,
    this.raiserPhone,
  });

  final String incidentId;
  final String raisedByName;
  final DateTime raisedAt;
  final SosStatus status;
  final int? distanceM;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;

  final DateTime? myAcknowledgedAt;
  final DateTime? myDeclinedAt;
  final DateTime? myArrivedAt;
  final String? raiserPhone;

  bool get answered => myAcknowledgedAt != null || myDeclinedAt != null;
  bool get isComing => myAcknowledgedAt != null;
  bool get hasLocation => latitude != null && longitude != null;

  @override
  List<Object?> get props =>
      [incidentId, status, myAcknowledgedAt, myDeclinedAt, myArrivedAt];
}

/// One of the people who love you.
class SafetyContact extends Equatable {
  const SafetyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship,
    this.notifySms = true,
    this.notifyPush = true,
    this.verifiedAt,
    this.position = 0,
    this.isMember = false,
  });

  final String id;

  /// "Amma", not "+919840011111". A list of bare digits cannot be read under
  /// stress and cannot be safely deleted from — which is what it was.
  final String name;
  final String phone;
  final String? relationship;
  final bool notifySms;
  final bool notifyPush;

  /// Null until a test message has actually gone. The screen says "not tested
  /// yet" rather than showing a tick nobody earned.
  final DateTime? verifiedAt;
  final int position;

  /// Whether this number belongs to a member of the club, which decides what
  /// the screen may promise: a phone that rings through a silenced ringer, or
  /// an SMS that lands silently.
  final bool isMember;

  bool get isTested => verifiedAt != null;

  @override
  List<Object?> get props =>
      [id, name, phone, verifiedAt, position, isMember];
}

/// Whether this member has agreed to be told when somebody near them needs
/// help — and on what terms.
class ResponderSettings extends Equatable {
  const ResponderSettings({
    this.isAvailable = false,
    this.maxDistanceM = 2000,
    this.quietFromHour,
    this.quietToHour,
    this.hasPosition = false,
  });

  /// Off by default, and deliberately so. Being on the roster means a
  /// stranger's emergency can wake you at two in the morning.
  final bool isAvailable;
  final int maxDistanceM;
  final int? quietFromHour;
  final int? quietToHour;

  /// Whether the server has any idea where this member is. Never the position
  /// itself — nothing in this API hands a responder's location back.
  final bool hasPosition;

  @override
  List<Object?> get props =>
      [isAvailable, maxDistanceM, quietFromHour, quietToHour, hasPosition];
}
