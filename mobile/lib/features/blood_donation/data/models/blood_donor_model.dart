import '../../domain/entities/blood_donor_entity.dart';

class BloodDonorModel extends BloodDonorEntity {
  const BloodDonorModel({
    required super.id,
    required super.bloodGroup,
    required super.isAvailable,
    super.geographyId,
    super.fullNameEn,
    super.fullNameTa,
    super.phoneNumber,
  });

  factory BloodDonorModel.fromJson(Map<String, dynamic> json) =>
      BloodDonorModel(
        id: json['id'] as String,
        bloodGroup: json['blood_group'] as String,
        isAvailable: json['is_available'] as bool? ?? true,
        geographyId: json['geography_id'] as String?,
        fullNameEn: json['full_name_en'] as String?,
        fullNameTa: json['full_name_ta'] as String?,
        phoneNumber: json['phone_number'] as String?,
      );
}
