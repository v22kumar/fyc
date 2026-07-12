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
    super.venue,
    super.prizeDetails,
    super.numTeams,
    super.matchConfig,
    super.registrationMode,
    super.startDate,
    super.endDate,
    super.showPointsTable,
    super.showLiveScores,
    super.showPrizeDetails,
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
      venue: json['venue'] as String?,
      prizeDetails: json['prize_details'] as String?,
      numTeams: (json['num_teams'] as num?)?.toInt(),
      matchConfig: json['match_config'] as String?,
      registrationMode: (json['registration_mode'] as String?) ?? 'MANUAL_APPROVAL',
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      showPointsTable: (json['show_points_table'] as bool?) ?? true,
      showLiveScores: (json['show_live_scores'] as bool?) ?? true,
      showPrizeDetails: (json['show_prize_details'] as bool?) ?? false,
    );
  }
}
