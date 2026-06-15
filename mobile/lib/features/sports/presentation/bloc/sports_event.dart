import 'package:equatable/equatable.dart';

abstract class SportsEvent extends Equatable {
  const SportsEvent();
  @override
  List<Object?> get props => [];
}

class SportsFetchRequested extends SportsEvent {
  final String? sport;
  const SportsFetchRequested({this.sport});
  @override
  List<Object?> get props => [sport];
}

class SportsTournamentSelected extends SportsEvent {
  final String tournamentId;
  const SportsTournamentSelected(this.tournamentId);
  @override
  List<Object?> get props => [tournamentId];
}

class SportsChallengeSubmitted extends SportsEvent {
  final String challengerTeamName;
  final String challengerCaptain;
  final String challengerPhone;
  final String sport;
  final DateTime? proposedDate;
  final String? venue;
  final String? message;

  const SportsChallengeSubmitted({
    required this.challengerTeamName,
    required this.challengerCaptain,
    required this.challengerPhone,
    required this.sport,
    this.proposedDate,
    this.venue,
    this.message,
  });

  @override
  List<Object?> get props => [
        challengerTeamName,
        challengerCaptain,
        challengerPhone,
        sport,
        proposedDate,
        venue,
        message,
      ];
}
