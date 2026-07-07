import '../../domain/entities/tournament_entity.dart';

class TournamentModel extends TournamentEntity {
  const TournamentModel({
    required super.id,
    required super.nameTa,
    required super.nameEn,
    required super.sport,
    required super.year,
    required super.format,
    required super.status,
    super.phase,
    super.descriptionTa,
    super.descriptionEn,
    super.registrationCloseDate,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'] as String,
      nameTa: (json['name_ta'] as String?) ?? '',
      nameEn: (json['name_en'] as String?) ?? '',
      sport: (json['sport'] as String?) ?? 'other',
      year: (json['year'] as num?)?.toInt() ?? 0,
      format: (json['format'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      phase: json['phase'] as String?,
      descriptionTa: json['description_ta'] as String?,
      descriptionEn: json['description_en'] as String?,
      registrationCloseDate: json['registration_close_date'] != null
          ? DateTime.tryParse(json['registration_close_date'] as String)
          : null,
    );
  }
}
