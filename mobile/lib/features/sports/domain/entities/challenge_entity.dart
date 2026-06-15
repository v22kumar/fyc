import 'package:equatable/equatable.dart';

class ChallengeEntity extends Equatable {
  final String id;
  final String challengerTeamName;
  final String challengerCaptain;
  final String challengerPhone;
  final String sport;
  final DateTime? proposedDate;
  final String? venue;
  final String? message;
  final String status;
  final String? adminResponse;

  const ChallengeEntity({
    required this.id,
    required this.challengerTeamName,
    required this.challengerCaptain,
    required this.challengerPhone,
    required this.sport,
    this.proposedDate,
    this.venue,
    this.message,
    required this.status,
    this.adminResponse,
  });

  @override
  List<Object?> get props => [id, challengerTeamName, sport, status];
}
