import '../../domain/entities/event_entity.dart';

class EventModel extends EventEntity {
  const EventModel({
    required super.id,
    required super.titleTa,
    required super.titleEn,
    required super.descriptionTa,
    required super.descriptionEn,
    required super.eventStart,
    required super.eventEnd,
    super.bannerUrl,
    super.geographyId,
    super.registrationCount,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      titleTa: (json['title_ta'] as String?) ?? '',
      titleEn: (json['title_en'] as String?) ?? '',
      descriptionTa: (json['description_ta'] as String?) ?? '',
      descriptionEn: (json['description_en'] as String?) ?? '',
      eventStart: DateTime.parse(json['event_start'] as String),
      eventEnd: DateTime.parse(json['event_end'] as String),
      bannerUrl: json['banner_url'] as String?,
      geographyId: json['geography_id'] as String?,
      registrationCount: (json['registration_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title_ta': titleTa,
      'title_en': titleEn,
      'description_ta': descriptionTa,
      'description_en': descriptionEn,
      'event_start': eventStart.toIso8601String(),
      'event_end': eventEnd.toIso8601String(),
      'banner_url': bannerUrl,
      'geography_id': geographyId,
      'registration_count': registrationCount,
    };
  }
}
