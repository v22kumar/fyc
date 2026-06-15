import '../../domain/entities/issue_entity.dart';

class IssueDetailModel extends IssueEntity {
  const IssueDetailModel({
    required super.id,
    required super.category,
    required super.descriptionTa,
    required super.descriptionEn,
    required super.latitude,
    required super.longitude,
    super.geographyId,
    super.photoUrl,
    super.verificationPhotoUrl,
    required super.status,
    super.assignedVolunteerId,
    super.reportedByUserId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory IssueDetailModel.fromJson(Map<String, dynamic> json) {
    return IssueDetailModel(
      id: json['id'] as String,
      category: json['category'] as String,
      descriptionTa: (json['description_ta'] as String?) ?? '',
      descriptionEn: (json['description_en'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      geographyId: json['geography_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      verificationPhotoUrl: json['verification_photo_url'] as String?,
      status: json['status'] as String,
      assignedVolunteerId: json['assigned_volunteer_id'] as String?,
      reportedByUserId: json['reported_by_user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
