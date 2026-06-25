import '../../domain/entities/player_entity.dart';

class PlayerModel extends PlayerEntity {
  const PlayerModel({
    required super.id,
    required super.teamId,
    super.userId,
    required super.name,
    super.photoUrl,
    super.jerseyNumber,
    super.role,
    super.battingStyle,
    super.bowlingStyle,
    required super.matchesPlayed,
    required super.runsScored,
    required super.wicketsTaken,
    required super.mvpCount,
    required super.sportsmanshipScore,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      photoUrl: json['photo_url'] as String?,
      jerseyNumber: json['jersey_number'] as String?,
      role: json['role'] as String?,
      battingStyle: json['batting_style'] as String?,
      bowlingStyle: json['bowling_style'] as String?,
      matchesPlayed: (json['matches_played'] as num?)?.toInt() ?? 0,
      runsScored: (json['runs_scored'] as num?)?.toInt() ?? 0,
      wicketsTaken: (json['wickets_taken'] as num?)?.toInt() ?? 0,
      mvpCount: (json['mvp_count'] as num?)?.toInt() ?? 0,
      sportsmanshipScore: (json['sportsmanship_score'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'user_id': userId,
      'name': name,
      'photo_url': photoUrl,
      'jersey_number': jerseyNumber,
      'role': role,
      'batting_style': battingStyle,
      'bowling_style': bowlingStyle,
      'matches_played': matchesPlayed,
      'runs_scored': runsScored,
      'wickets_taken': wicketsTaken,
      'mvp_count': mvpCount,
      'sportsmanship_score': sportsmanshipScore,
    };
  }
}
