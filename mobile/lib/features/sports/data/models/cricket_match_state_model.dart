import '../../domain/entities/cricket_match_state_entity.dart';

class CricketMatchStateModel extends CricketMatchStateEntity {
  const CricketMatchStateModel({
    required super.innings,
    super.battingTeamId,
    super.bowlingTeamId,
    required super.score,
    required super.wickets,
    required super.overs,
    required super.balls,
    super.target,
  });

  factory CricketMatchStateModel.fromJson(Map<String, dynamic> json) {
    return CricketMatchStateModel(
      innings: (json['innings'] as num?)?.toInt() ?? 1,
      battingTeamId: json['batting_team_id'] as String?,
      bowlingTeamId: json['bowling_team_id'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      wickets: (json['wickets'] as num?)?.toInt() ?? 0,
      overs: (json['overs'] as num?)?.toInt() ?? 0,
      balls: (json['balls'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt(),
    );
  }
}
