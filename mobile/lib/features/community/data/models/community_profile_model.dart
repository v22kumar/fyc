import '../../domain/entities/community_profile_entity.dart';

class CommunityProfileModel extends CommunityProfileEntity {
  const CommunityProfileModel({
    required super.id,
    required super.userId,
    required super.category,
    super.businessNameTa,
    super.businessNameEn,
    super.descriptionTa,
    super.descriptionEn,
    super.contactPhone,
    super.contactWhatsapp,
    super.serviceArea,
    super.yearsExperience,
    required super.isAvailable,
    required super.isVerified,
    super.fullNameEn,
    super.fullNameTa,
  });

  factory CommunityProfileModel.fromJson(Map<String, dynamic> json) {
    return CommunityProfileModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      category: json['category'] as String,
      businessNameTa: json['business_name_ta'] as String?,
      businessNameEn: json['business_name_en'] as String?,
      descriptionTa: json['description_ta'] as String?,
      descriptionEn: json['description_en'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactWhatsapp: json['contact_whatsapp'] as String?,
      serviceArea: json['service_area'] as String?,
      yearsExperience: json['years_experience'] as int?,
      isAvailable: json['is_available'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      fullNameEn: json['full_name_en'] as String?,
      fullNameTa: json['full_name_ta'] as String?,
    );
  }
}
