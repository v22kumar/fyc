import 'package:equatable/equatable.dart';

class PublicIssueEntity extends Equatable {
  final String id;
  final String category;
  final String descriptionTa;
  final String descriptionEn;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;

  const PublicIssueEntity({
    required this.id,
    required this.category,
    required this.descriptionTa,
    required this.descriptionEn,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, category, status, createdAt];
}
