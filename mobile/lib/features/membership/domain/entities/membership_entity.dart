import 'package:equatable/equatable.dart';

class MembershipEntity extends Equatable {
  final String id;
  final String userId;
  final String membershipNumber;
  final String qrCodePayload;
  final String status;
  final String designationTa;
  final String designationEn;
  final DateTime? issuedAt;
  final DateTime expiresAt;

  const MembershipEntity({
    required this.id,
    required this.userId,
    required this.membershipNumber,
    required this.qrCodePayload,
    required this.status,
    required this.designationTa,
    required this.designationEn,
    this.issuedAt,
    required this.expiresAt,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => expiresAt.isBefore(DateTime.now());

  String displayDesignation(String lang) =>
      lang == 'ta' ? designationTa : designationEn;

  @override
  List<Object?> get props => [id, membershipNumber, status, expiresAt];
}
