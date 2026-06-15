import 'package:equatable/equatable.dart';

class TeamEntity extends Equatable {
  final String id;
  final String tournamentId;
  final String name;
  final String? captainName;
  final String? contactPhone;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final bool isFycTeam;

  const TeamEntity({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.captainName,
    this.contactPhone,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.points,
    required this.isFycTeam,
  });

  int get played => wins + losses + draws;

  @override
  List<Object?> get props => [
        id,
        tournamentId,
        name,
        wins,
        losses,
        draws,
        points,
        isFycTeam,
      ];
}
