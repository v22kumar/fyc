import '../../domain/entities/team_entity.dart';

class TeamModel extends TeamEntity {
  const TeamModel({
    required super.id,
    required super.tournamentId,
    required super.name,
    super.captainName,
    super.contactPhone,
    required super.wins,
    required super.losses,
    required super.draws,
    required super.points,
    required super.isFycTeam,
    super.netRunRate,
    super.eliminated,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'] as String,
      tournamentId: (json['tournament_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      captainName: json['captain_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      isFycTeam: (json['is_fyc_team'] as bool?) ?? false,
      netRunRate: (json['net_run_rate'] as num?)?.toDouble(),
      eliminated: (json['eliminated'] as bool?) ?? false,
    );
  }
}
