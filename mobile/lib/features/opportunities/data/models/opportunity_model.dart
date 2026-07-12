import '../../domain/entities/opportunity_entity.dart';

class OpportunityModel extends OpportunityEntity {
  const OpportunityModel({
    required super.id,
    required super.type,
    required super.titleTa,
    required super.titleEn,
    required super.organizerTa,
    required super.organizerEn,
    required super.hours,
    required super.categoryTa,
    required super.categoryEn,
    required super.locationTa,
    required super.locationEn,
    required super.descriptionTa,
    required super.descriptionEn,
    super.budget,
    super.contactPhone,
    super.postedBy,
    required super.isActive,
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id'] as String,
      type: (json['type'] as String?) ?? '',
      titleTa: (json['title_ta'] as String?) ?? '',
      titleEn: (json['title_en'] as String?) ?? '',
      organizerTa: (json['organizer_ta'] as String?) ?? '',
      organizerEn: (json['organizer_en'] as String?) ?? '',
      hours: (json['hours'] as String?) ?? '',
      categoryTa: (json['category_ta'] as String?) ?? '',
      categoryEn: (json['category_en'] as String?) ?? '',
      locationTa: (json['location_ta'] as String?) ?? '',
      locationEn: (json['location_en'] as String?) ?? '',
      descriptionTa: (json['description_ta'] as String?) ?? '',
      descriptionEn: (json['description_en'] as String?) ?? '',
      budget: (json['budget'] as String?) ?? '',
      // contact_phone is only present on the authenticated detail response.
      contactPhone: (json['contact_phone'] as String?) ?? '',
      postedBy: (json['posted_by'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
