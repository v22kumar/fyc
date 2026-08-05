import '../../domain/entities/blood_donor_entity.dart';

class BloodDonorModel extends BloodDonorEntity {
  const BloodDonorModel({
    required super.id,
    required super.bloodGroup,
    required super.isAvailable,
    super.geographyId,
    super.geographyNameEn,
    super.geographyNameTa,
    super.fullNameEn,
    super.fullNameTa,
    super.age,
    super.phoneNumber,
    super.isImported,
    super.tier,
    super.isEligible,
    super.eligibleOn,
    super.distanceKm,
    super.hasLocation,
    super.approxLat,
    super.approxLng,
  });

  factory BloodDonorModel.fromJson(Map<String, dynamic> json) =>
      BloodDonorModel(
        id: json['id'] as String,
        bloodGroup: json['blood_group'] as String,
        isAvailable: json['is_available'] as bool? ?? true,
        geographyId: json['geography_id'] as String?,
        geographyNameEn: json['geography_name_en'] as String?,
        geographyNameTa: json['geography_name_ta'] as String?,
        fullNameEn: json['full_name_en'] as String?,
        fullNameTa: json['full_name_ta'] as String?,
        age: (json['age'] as num?)?.toInt(),
        phoneNumber: json['phone_number'] as String?,
        isImported: json['is_imported'] as bool? ?? false,
        tier: json['tier'] as String? ?? 'fyc',
        isEligible: json['is_eligible'] as bool? ?? true,
        eligibleOn: json['eligible_on'] as String?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        hasLocation: json['has_location'] as bool? ?? false,
        approxLat: (json['approx_latitude'] as num?)?.toDouble(),
        approxLng: (json['approx_longitude'] as num?)?.toDouble(),
      );
}
