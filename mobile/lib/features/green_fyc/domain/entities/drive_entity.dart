import 'package:equatable/equatable.dart';

class DriveEntity extends Equatable {
  final String id;
  final String organizationId;
  final String titleTa;
  final String titleEn;
  final String descriptionTa;
  final String descriptionEn;
  final DateTime driveDate;
  final String? locationTa;
  final String? locationEn;
  final String? geographyId;
  final int targetCount;
  final String? bannerUrl;
  final bool isActive;
  final int treeCount;

  const DriveEntity({
    required this.id,
    required this.organizationId,
    required this.titleTa,
    required this.titleEn,
    required this.descriptionTa,
    required this.descriptionEn,
    required this.driveDate,
    this.locationTa,
    this.locationEn,
    this.geographyId,
    required this.targetCount,
    this.bannerUrl,
    required this.isActive,
    required this.treeCount,
  });

  String displayTitle(String lang) => lang == 'ta' ? titleTa : titleEn;
  String displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;
  String? displayLocation(String lang) => lang == 'ta' ? locationTa : locationEn;

  double get progress =>
      targetCount > 0 ? (treeCount / targetCount).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props =>
      [id, titleTa, titleEn, driveDate, targetCount, treeCount, isActive];
}
