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
  final double? netRunRate;
  final bool eliminated;

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
    this.netRunRate,
    this.eliminated = false,
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
        netRunRate,
        eliminated,
      ];
}
