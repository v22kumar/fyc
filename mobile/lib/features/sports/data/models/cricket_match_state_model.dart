import '../../domain/entities/cricket_match_state_entity.dart';

class CricketPlayersModel extends CricketPlayersEntity {
  const CricketPlayersModel({
    required super.strikerId,
    required super.nonStrikerId,
    required super.bowlerId,
    required super.strikerName,
    required super.nonStrikerName,
    required super.bowlerName,
  });

  factory CricketPlayersModel.fromJson(Map<String, dynamic> json) {
    return CricketPlayersModel(
      strikerId: json['striker_id'] as String? ?? '',
      nonStrikerId: json['non_striker_id'] as String? ?? '',
      bowlerId: json['bowler_id'] as String? ?? '',
      strikerName: json['striker_name'] as String? ?? '',
      nonStrikerName: json['non_striker_name'] as String? ?? '',
      bowlerName: json['bowler_name'] as String? ?? '',
    );
  }
}

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
    super.status,
    super.batters,
    super.bowlers,
    super.extras,
    super.recentBalls,
    super.oversHistory,
  });

  factory CricketMatchStateModel.fromJson(Map<String, dynamic> json) {
    final battersJson = json['batters'] as Map<String, dynamic>? ?? {};
    final bowlersJson = json['bowlers'] as Map<String, dynamic>? ?? {};
    final extrasJson = json['extras'] as Map<String, dynamic>? ?? {};
    final recentBallsJson = json['recent_balls'] as List<dynamic>? ?? [];
    final oversHistoryJson = json['overs_history'] as List<dynamic>? ?? [];

    return CricketMatchStateModel(
      innings: (json['innings'] as num?)?.toInt() ?? 1,
      battingTeamId: json['batting_team_id'] as String?,
      bowlingTeamId: json['bowling_team_id'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      wickets: (json['wickets'] as num?)?.toInt() ?? 0,
      overs: (json['overs'] as num?)?.toInt() ?? 0,
      balls: (json['balls'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'FIRST_INNINGS',
      batters: battersJson.entries.map((e) {
        final b = e.value as Map<String, dynamic>;
        return CricketBatterEntity(
          id: e.key,
          name: b['name'] as String? ?? '',
          runs: (b['runs'] as num?)?.toInt() ?? 0,
          balls: (b['balls'] as num?)?.toInt() ?? 0,
          fours: (b['fours'] as num?)?.toInt() ?? 0,
          sixes: (b['sixes'] as num?)?.toInt() ?? 0,
          out: b['out'] as bool? ?? false,
        );
      }).toList(),
      bowlers: bowlersJson.entries.map((e) {
        final b = e.value as Map<String, dynamic>;
        return CricketBowlerEntity(
          id: e.key,
          name: b['name'] as String? ?? '',
          legalBalls: (b['legal_balls'] as num?)?.toInt() ?? 0,
          runs: (b['runs'] as num?)?.toInt() ?? 0,
          wickets: (b['wickets'] as num?)?.toInt() ?? 0,
        );
      }).toList(),
      extras: extrasJson.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      recentBalls: recentBallsJson.map((e) => e.toString()).toList(),
      oversHistory: oversHistoryJson.map((o) {
        final over = o as Map<String, dynamic>;
        final balls = over['balls'] as List<dynamic>? ?? [];
        return CricketOverHistoryEntity(
          overIndex: (over['over_index'] as num?)?.toInt() ?? 0,
          balls: balls.map((b) {
            final ball = b as Map<String, dynamic>;
            return CricketBallEntity(
              id: ball['id'] as String? ?? '',
              ballIndex: (ball['ball_index'] as num?)?.toInt() ?? 0,
              strikerId: ball['striker_id'] as String? ?? '',
              strikerName: ball['striker_name'] as String? ?? '',
              nonStrikerId: ball['non_striker_id'] as String? ?? '',
              nonStrikerName: ball['non_striker_name'] as String? ?? '',
              bowlerId: ball['bowler_id'] as String? ?? '',
              bowlerName: ball['bowler_name'] as String? ?? '',
              runsBatter: (ball['runs_batter'] as num?)?.toInt() ?? 0,
              extrasType: ball['extras_type'] as String?,
              extrasRuns: (ball['extras_runs'] as num?)?.toInt() ?? 0,
              isWicket: ball['is_wicket'] as bool? ?? false,
              wicketType: ball['wicket_type'] as String?,
              playerDismissedId: ball['player_dismissed_id'] as String?,
              ballStr: ball['ball_str'] as String? ?? '',
              isLegal: ball['is_legal'] as bool? ?? true,
              notes: ball['notes'] as String?,
              hasEditHistory: (ball['edit_history'] as List<dynamic>? ?? []).isNotEmpty,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
