import 'package:equatable/equatable.dart';

class OpportunityEntity extends Equatable {
  final String id;
  final String type;
  final String titleTa;
  final String titleEn;
  final String organizerTa;
  final String organizerEn;
  final String hours;
  final String categoryTa;
  final String categoryEn;
  final String locationTa;
  final String locationEn;
  final String descriptionTa;
  final String descriptionEn;
  final bool isActive;

  const OpportunityEntity({
    required this.id,
    required this.type,
    required this.titleTa,
    required this.titleEn,
    required this.organizerTa,
    required this.organizerEn,
    required this.hours,
    required this.categoryTa,
    required this.categoryEn,
    required this.locationTa,
    required this.locationEn,
    required this.descriptionTa,
    required this.descriptionEn,
    required this.isActive,
  });

  String displayTitle(String lang) => lang == 'ta' ? titleTa : titleEn;
  String displayOrganizer(String lang) =>
      lang == 'ta' ? organizerTa : organizerEn;
  String displayCategory(String lang) =>
      lang == 'ta' ? categoryTa : categoryEn;
  String displayLocation(String lang) =>
      lang == 'ta' ? locationTa : locationEn;
  String displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;

  @override
  List<Object?> get props => [
        id,
        type,
        titleTa,
        titleEn,
        organizerTa,
        organizerEn,
        hours,
        categoryTa,
        categoryEn,
        locationTa,
        locationEn,
        descriptionTa,
        descriptionEn,
        isActive,
      ];
}
