import '../../domain/entities/safety_entities.dart';

SosStatus _status(String? v) => switch (v) {
      'WIDENING' => SosStatus.widening,
      'ESCALATED' => SosStatus.escalated,
      'ACKNOWLEDGED' => SosStatus.acknowledged,
      'STOOD_DOWN' => SosStatus.stoodDown,
      _ => SosStatus.raised,
    };

SosKind? _kind(String? v) => switch (v) {
      'MEDICAL' => SosKind.medical,
      'THREAT' => SosKind.threat,
      'ACCIDENT' => SosKind.accident,
      'FIRE' => SosKind.fire,
      'OTHER' => SosKind.other,
      _ => null,
    };

String kindWire(SosKind k) => switch (k) {
      SosKind.medical => 'MEDICAL',
      SosKind.threat => 'THREAT',
      SosKind.accident => 'ACCIDENT',
      SosKind.fire => 'FIRE',
      SosKind.other => 'OTHER',
    };

SosAuthor _author(String? v) => switch (v) {
      'RESPONDER' => SosAuthor.responder,
      'FYC' => SosAuthor.club,
      'SYSTEM' => SosAuthor.system,
      _ => SosAuthor.member,
    };

DateTime? _at(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

double? _num(Object? v) => (v as num?)?.toDouble();

SosResponder responderFromJson(Map<String, dynamic> j) => SosResponder(
      userId: j['user_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      wave: (j['wave'] as num?)?.toInt() ?? 1,
      distanceM: (j['distance_m'] as num?)?.toInt(),
      notifiedAt: _at(j['notified_at']),
      acknowledgedAt: _at(j['acknowledged_at']),
      arrivedAt: _at(j['arrived_at']),
      declinedAt: _at(j['declined_at']),
      phone: j['phone'] as String?,
    );

SosEvent eventFromJson(Map<String, dynamic> j) => SosEvent(
      id: j['id'] as String? ?? '',
      author: _author(j['author'] as String?),
      authorName: j['author_name'] as String?,
      type: j['event_type'] as String? ?? '',
      detail: j['detail'] as String?,
      at: _at(j['created_at']) ?? DateTime.now(),
    );

SosIncident incidentFromJson(Map<String, dynamic> j) => SosIncident(
      id: j['id'] as String? ?? '',
      status: _status(j['status'] as String?),
      kind: _kind(j['kind'] as String?),
      raisedByUserId: j['raised_by_user_id'] as String?,
      raisedByName: j['raised_by_name'] as String? ?? '',
      latitude: _num(j['latitude']),
      longitude: _num(j['longitude']),
      accuracyM: _num(j['accuracy_m']),
      locatedAt: _at(j['located_at']),
      placeName: j['place_name'] as String?,
      wave: (j['wave'] as num?)?.toInt() ?? 0,
      radiusM: (j['radius_m'] as num?)?.toInt(),
      alertedCount: (j['alerted_count'] as num?)?.toInt() ?? 0,
      contactsNotified: (j['contacts_notified'] as num?)?.toInt() ?? 0,
      acknowledgedCount: (j['acknowledged_count'] as num?)?.toInt() ?? 0,
      isThrottled: j['is_throttled'] as bool? ?? false,
      isOpen: j['is_open'] as bool? ?? true,
      stoodDownAt: _at(j['stood_down_at']),
      stoodDownReason: j['stood_down_reason'] as String?,
      createdAt: _at(j['created_at']) ?? DateTime.now(),
      responders: [
        for (final r in (j['responders'] as List? ?? []))
          responderFromJson((r as Map).cast<String, dynamic>())
      ],
      events: [
        for (final e in (j['events'] as List? ?? []))
          eventFromJson((e as Map).cast<String, dynamic>())
      ],
    );

SosSummary summaryFromJson(Map<String, dynamic> j) => SosSummary(
      id: j['id'] as String? ?? '',
      status: _status(j['status'] as String?),
      kind: _kind(j['kind'] as String?),
      raisedByUserId: j['raised_by_user_id'] as String?,
      raisedByName: j['raised_by_name'] as String? ?? '',
      placeName: j['place_name'] as String?,
      alertedCount: (j['alerted_count'] as num?)?.toInt() ?? 0,
      acknowledgedCount: (j['acknowledged_count'] as num?)?.toInt() ?? 0,
      isOpen: j['is_open'] as bool? ?? true,
      isThrottled: j['is_throttled'] as bool? ?? false,
      createdAt: _at(j['created_at']) ?? DateTime.now(),
      stoodDownAt: _at(j['stood_down_at']),
    );

ResponderAlert alertFromJson(Map<String, dynamic> j) => ResponderAlert(
      incidentId: j['incident_id'] as String? ?? '',
      raisedByName: j['raised_by_name'] as String? ?? '',
      distanceM: (j['distance_m'] as num?)?.toInt(),
      placeName: j['place_name'] as String?,
      latitude: _num(j['latitude']),
      longitude: _num(j['longitude']),
      accuracyM: _num(j['accuracy_m']),
      raisedAt: _at(j['raised_at']) ?? DateTime.now(),
      status: _status(j['status'] as String?),
      myAcknowledgedAt: _at(j['my_acknowledged_at']),
      myDeclinedAt: _at(j['my_declined_at']),
      myArrivedAt: _at(j['my_arrived_at']),
      raiserPhone: j['raiser_phone'] as String?,
    );

SafetyContact contactFromJson(Map<String, dynamic> j) => SafetyContact(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      relationship: j['relationship_label'] as String?,
      notifySms: j['notify_sms'] as bool? ?? true,
      notifyPush: j['notify_push'] as bool? ?? true,
      verifiedAt: _at(j['verified_at']),
      position: (j['position'] as num?)?.toInt() ?? 0,
      isMember: j['is_member'] as bool? ?? false,
    );

ResponderSettings settingsFromJson(Map<String, dynamic> j) => ResponderSettings(
      isAvailable: j['is_available'] as bool? ?? false,
      maxDistanceM: (j['max_distance_m'] as num?)?.toInt() ?? 2000,
      quietFromHour: (j['quiet_from_hour'] as num?)?.toInt(),
      quietToHour: (j['quiet_to_hour'] as num?)?.toInt(),
      hasPosition: j['has_position'] as bool? ?? false,
    );
