import 'package:equatable/equatable.dart';

class FixtureEntity extends Equatable {
  final String id;
  final String tournamentId;
  final String teamAId;
  final String teamBId;
  final String? teamAName;
  final String? teamBName;
  final int? matchNumber;
  final DateTime? scheduledAt;
  final String? venue;
  final String status;
  final String? teamAScore;
  final String? teamBScore;
  final String? winnerId;
  final String? resultNotes;

  const FixtureEntity({
    required this.id,
    required this.tournamentId,
    required this.teamAId,
    required this.teamBId,
    this.teamAName,
    this.teamBName,
    this.matchNumber,
    this.scheduledAt,
    this.venue,
    required this.status,
    this.teamAScore,
    this.teamBScore,
    this.winnerId,
    this.resultNotes,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isLive => status.toLowerCase() == 'live';

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        teamAId,
        teamBId,
        matchNumber,
        scheduledAt,
        status,
        teamAScore,
        teamBScore,
        winnerId,
      ];
}
