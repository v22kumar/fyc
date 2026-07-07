import '../../domain/entities/weekly_game_entity.dart';

class WeeklyGamePlayerModel extends WeeklyGamePlayerEntity {
  const WeeklyGamePlayerModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.status,
    super.teamAssigned,
  });

  factory WeeklyGamePlayerModel.fromJson(Map<String, dynamic> json) {
    return WeeklyGamePlayerModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      status: json['status'] as String,
      teamAssigned: json['team_assigned'] as String?,
    );
  }
}

class WeeklyGameModel extends WeeklyGameEntity {
  const WeeklyGameModel({
    required super.id,
    required super.title,
    required super.sport,
    required super.scheduledAt,
    super.venue,
    required super.status,
    super.createdById,
    super.fixtureId,
    required super.players,
  });

  factory WeeklyGameModel.fromJson(Map<String, dynamic> json) {
    return WeeklyGameModel(
      id: json['id'] as String,
      title: json['title'] as String,
      sport: json['sport'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      venue: json['venue'] as String?,
      status: json['status'] as String,
      createdById: json['created_by_id'] as String?,
      fixtureId: json['fixture_id'] as String?,
      players: (json['players'] as List<dynamic>?)
              ?.map((e) => WeeklyGamePlayerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
