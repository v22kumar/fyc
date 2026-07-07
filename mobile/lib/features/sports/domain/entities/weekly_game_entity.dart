import 'package:equatable/equatable.dart';

class WeeklyGamePlayerEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String status;
  final String? teamAssigned;

  const WeeklyGamePlayerEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.status,
    this.teamAssigned,
  });

  @override
  List<Object?> get props => [id, userId, userName, status, teamAssigned];
}

class WeeklyGameEntity extends Equatable {
  final String id;
  final String title;
  final String sport;
  final DateTime scheduledAt;
  final String? venue;
  final String status;
  final String? createdById;
  final String? fixtureId;
  final List<WeeklyGamePlayerEntity> players;

  const WeeklyGameEntity({
    required this.id,
    required this.title,
    required this.sport,
    required this.scheduledAt,
    this.venue,
    required this.status,
    this.createdById,
    this.fixtureId,
    required this.players,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        sport,
        scheduledAt,
        venue,
        status,
        createdById,
        fixtureId,
        players,
      ];
}
