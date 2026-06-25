import 'package:equatable/equatable.dart';

class CricketMatchStateEntity extends Equatable {
  final int innings;
  final String? battingTeamId;
  final String? bowlingTeamId;
  final int score;
  final int wickets;
  final int overs;
  final int balls;
  final int? target;

  const CricketMatchStateEntity({
    required this.innings,
    this.battingTeamId,
    this.bowlingTeamId,
    required this.score,
    required this.wickets,
    required this.overs,
    required this.balls,
    this.target,
  });

  @override
  List<Object?> get props => [
        innings,
        battingTeamId,
        bowlingTeamId,
        score,
        wickets,
        overs,
        balls,
        target,
      ];
}
