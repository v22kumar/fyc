import '../../domain/entities/photo_entity.dart';

class PhotoModel extends PhotoEntity {
  const PhotoModel({
    required super.id,
    required super.eventId,
    super.uploadedByUserId,
    required super.photoUrl,
    super.captionTa,
    super.captionEn,
    super.takenAt,
    required super.organizationId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      uploadedByUserId: json['uploaded_by_user_id'] as String?,
      photoUrl: (json['photo_url'] as String?) ?? '',
      captionTa: json['caption_ta'] as String?,
      captionEn: json['caption_en'] as String?,
      takenAt: json['taken_at'] != null
          ? DateTime.parse(json['taken_at'] as String)
          : null,
      organizationId: json['organization_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
