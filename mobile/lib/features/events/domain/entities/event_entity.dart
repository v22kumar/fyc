import 'package:equatable/equatable.dart';

class EventEntity extends Equatable {
  final String id;
  final String titleTa;
  final String titleEn;
  final String descriptionTa;
  final String descriptionEn;
  final DateTime eventStart;
  final DateTime eventEnd;
  final String? bannerUrl;
  final String? geographyId;
  final int registrationCount;
  final bool registrationEnabled;
  final String? registrationType;
  final int? maxParticipants;
  final DateTime? registrationDeadline;
  final String status;

  const EventEntity({
    required this.id,
    required this.titleTa,
    required this.titleEn,
    required this.descriptionTa,
    required this.descriptionEn,
    required this.eventStart,
    required this.eventEnd,
    this.bannerUrl,
    this.geographyId,
    this.registrationCount = 0,
    this.registrationEnabled = true,
    this.registrationType,
    this.maxParticipants,
    this.registrationDeadline,
    this.status = 'active',
  });

  bool get isUpcoming => eventStart.isAfter(DateTime.now());
  bool get isOngoing =>
      eventStart.isBefore(DateTime.now()) && eventEnd.isAfter(DateTime.now());

  String displayTitle(String lang) => lang == 'ta' ? titleTa : titleEn;
  String displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;

  @override
  List<Object?> get props =>
      [id, titleTa, titleEn, eventStart, eventEnd, geographyId];
}
