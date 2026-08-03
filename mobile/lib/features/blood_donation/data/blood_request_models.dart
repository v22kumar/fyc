class BloodPledge {
  final String id;
  final String donorUserId;
  final String? donorName;
  final String status; // ACCEPTED / DECLINED / DONATED
  const BloodPledge({
    required this.id,
    required this.donorUserId,
    this.donorName,
    required this.status,
  });

  factory BloodPledge.fromJson(Map<String, dynamic> j) => BloodPledge(
        id: (j['id'] ?? '').toString(),
        donorUserId: (j['donor_user_id'] ?? '').toString(),
        donorName: j['donor_name'] as String?,
        status: (j['status'] as String?) ?? 'ACCEPTED',
      );
}

class BloodRequest {
  final String id;
  final String patientBloodGroup;
  final int unitsNeeded;
  final String? hospitalName;
  final double? latitude;
  final double? longitude;
  final String urgency; // CRITICAL / URGENT / ROUTINE
  final String? note;
  final String? contactPhone;
  final String status; // OPEN / FULFILLED / CLOSED / EXPIRED
  final int notifiedCount;
  final int acceptedCount;
  final String? requesterName;
  final List<BloodPledge> pledges;
  final String? myPledge; // caller's own pledge status, if any

  const BloodRequest({
    required this.id,
    required this.patientBloodGroup,
    this.unitsNeeded = 1,
    this.hospitalName,
    this.latitude,
    this.longitude,
    this.urgency = 'URGENT',
    this.note,
    this.contactPhone,
    this.status = 'OPEN',
    this.notifiedCount = 0,
    this.acceptedCount = 0,
    this.requesterName,
    this.pledges = const [],
    this.myPledge,
  });

  bool get isOpen => status == 'OPEN';

  factory BloodRequest.fromJson(Map<String, dynamic> j) => BloodRequest(
        id: (j['id'] ?? '').toString(),
        patientBloodGroup: (j['patient_blood_group'] as String?) ?? '',
        unitsNeeded: (j['units_needed'] as num?)?.toInt() ?? 1,
        hospitalName: j['hospital_name'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        urgency: (j['urgency'] as String?) ?? 'URGENT',
        note: j['note'] as String?,
        contactPhone: j['contact_phone'] as String?,
        status: (j['status'] as String?) ?? 'OPEN',
        notifiedCount: (j['notified_count'] as num?)?.toInt() ?? 0,
        acceptedCount: (j['accepted_count'] as num?)?.toInt() ?? 0,
        requesterName: j['requester_name'] as String?,
        pledges: ((j['pledges'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BloodPledge.fromJson(e.cast<String, dynamic>()))
            .toList(),
        myPledge: j['my_pledge'] as String?,
      );
}
