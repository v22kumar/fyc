import 'package:equatable/equatable.dart';

class PlayerEntity extends Equatable {
  final String id;
  final String teamId;
  final String? userId;
  final String name;
  final String? photoUrl;
  final String? jerseyNumber;
  final String? role;
  final String? battingStyle;
  final String? bowlingStyle;
  final int matchesPlayed;
  final int runsScored;
  final int wicketsTaken;
  final int mvpCount;
  final int sportsmanshipScore;

  const PlayerEntity({
    required this.id,
    required this.teamId,
    this.userId,
    required this.name,
    this.photoUrl,
    this.jerseyNumber,
    this.role,
    this.battingStyle,
    this.bowlingStyle,
    required this.matchesPlayed,
    required this.runsScored,
    required this.wicketsTaken,
    required this.mvpCount,
    required this.sportsmanshipScore,
  });

  @override
  List<Object?> get props => [
        id,
        teamId,
        userId,
        name,
        photoUrl,
        jerseyNumber,
        role,
        battingStyle,
        bowlingStyle,
        matchesPlayed,
        runsScored,
        wicketsTaken,
        mvpCount,
        sportsmanshipScore,
      ];
}
