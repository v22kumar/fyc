import 'package:equatable/equatable.dart';

class BloodDonorEntity extends Equatable {
  final String id;
  final String bloodGroup;
  final bool isAvailable;
  final String? geographyId;
  final String? fullNameEn;
  final String? fullNameTa;
  final String? phoneNumber; // only available after authenticated contact request

  const BloodDonorEntity({
    required this.id,
    required this.bloodGroup,
    required this.isAvailable,
    this.geographyId,
    this.fullNameEn,
    this.fullNameTa,
    this.phoneNumber,
  });

  String displayName(String lang) =>
      lang == 'ta'
          ? (fullNameTa ?? fullNameEn ?? '—')
          : (fullNameEn ?? fullNameTa ?? '—');

  @override
  List<Object?> get props =>
      [id, bloodGroup, isAvailable, geographyId, fullNameEn, fullNameTa];
}
