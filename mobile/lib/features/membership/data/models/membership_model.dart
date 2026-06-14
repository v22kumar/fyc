import '../../domain/entities/membership_entity.dart';

class MembershipModel extends MembershipEntity {
  const MembershipModel({
    required super.id,
    required super.userId,
    required super.membershipNumber,
    required super.qrCodePayload,
    required super.status,
    required super.designationTa,
    required super.designationEn,
    super.issuedAt,
    required super.expiresAt,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) =>
      MembershipModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        membershipNumber: json['membership_number'] as String,
        qrCodePayload: json['qr_code_payload'] as String,
        status: json['status'] as String,
        designationTa: json['designation_ta'] as String,
        designationEn: json['designation_en'] as String,
        issuedAt: json['issued_at'] != null
            ? DateTime.parse(json['issued_at'] as String)
            : null,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}
