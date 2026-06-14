import '../../domain/entities/public_issue_entity.dart';

class IssueModel extends PublicIssueEntity {
  const IssueModel({
    required super.id,
    required super.category,
    required super.descriptionTa,
    required super.descriptionEn,
    required super.latitude,
    required super.longitude,
    required super.status,
    required super.createdAt,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] as String,
      category: json['category'] as String,
      descriptionTa: (json['description_ta'] as String?) ?? '',
      descriptionEn: (json['description_en'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
