import '../../domain/entities/fixture_entity.dart';

class FixtureModel extends FixtureEntity {
  const FixtureModel({
    required super.id,
    required super.tournamentId,
    required super.teamAId,
    required super.teamBId,
    super.teamAName,
    super.teamBName,
    super.matchNumber,
    super.scheduledAt,
    super.venue,
    required super.status,
    super.teamAScore,
    super.teamBScore,
    super.winnerId,
    super.resultNotes,
  });

  factory FixtureModel.fromJson(Map<String, dynamic> json) {
    return FixtureModel(
      id: json['id'] as String,
      tournamentId: (json['tournament_id'] as String?) ?? '',
      teamAId: (json['team_a_id'] as String?) ?? '',
      teamBId: (json['team_b_id'] as String?) ?? '',
      teamAName: json['team_a_name'] as String?,
      teamBName: json['team_b_name'] as String?,
      matchNumber: (json['match_number'] as num?)?.toInt(),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      venue: json['venue'] as String?,
      status: (json['status'] as String?) ?? '',
      teamAScore: json['team_a_score'] as String?,
      teamBScore: json['team_b_score'] as String?,
      winnerId: json['winner_id'] as String?,
      resultNotes: json['result_notes'] as String?,
    );
  }
}
