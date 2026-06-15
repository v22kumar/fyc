import '../../domain/entities/announcement_entity.dart';

class AnnouncementModel extends AnnouncementEntity {
  const AnnouncementModel({
    required super.id,
    required super.titleTa,
    required super.titleEn,
    required super.bodyTa,
    required super.bodyEn,
    required super.category,
    required super.isPinned,
    super.expiresAt,
    super.bannerUrl,
    super.createdByUserId,
    super.geographyId,
    required super.organizationId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      titleTa: (json['title_ta'] as String?) ?? '',
      titleEn: (json['title_en'] as String?) ?? '',
      bodyTa: (json['body_ta'] as String?) ?? '',
      bodyEn: (json['body_en'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'GENERAL',
      isPinned: (json['is_pinned'] as bool?) ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      bannerUrl: json['banner_url'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      geographyId: json['geography_id'] as String?,
      organizationId: (json['organization_id'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
