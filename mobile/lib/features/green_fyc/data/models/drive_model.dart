import '../../domain/entities/drive_entity.dart';

class DriveModel extends DriveEntity {
  const DriveModel({
    required super.id,
    required super.organizationId,
    required super.titleTa,
    required super.titleEn,
    required super.descriptionTa,
    required super.descriptionEn,
    required super.driveDate,
    super.locationTa,
    super.locationEn,
    super.geographyId,
    required super.targetCount,
    super.bannerUrl,
    required super.isActive,
    required super.treeCount,
  });

  factory DriveModel.fromJson(Map<String, dynamic> json) {
    return DriveModel(
      id: json['id'] as String,
      organizationId: (json['organization_id'] as String?) ?? '',
      titleTa: (json['title_ta'] as String?) ?? '',
      titleEn: (json['title_en'] as String?) ?? '',
      descriptionTa: (json['description_ta'] as String?) ?? '',
      descriptionEn: (json['description_en'] as String?) ?? '',
      driveDate: DateTime.parse(json['drive_date'] as String),
      locationTa: json['location_ta'] as String?,
      locationEn: json['location_en'] as String?,
      geographyId: json['geography_id'] as String?,
      targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
      bannerUrl: json['banner_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      treeCount: (json['tree_count'] as num?)?.toInt() ?? 0,
    );
  }
}
