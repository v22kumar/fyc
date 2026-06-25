import 'package:equatable/equatable.dart';

class JourneyEntity extends Equatable {
  final int eventsAttended;
  final int issuesHelped;
  final int bloodDonations;
  final int treesPlanted;
  final int sportsMatchesPlayed;
  final double volunteerHours;

  const JourneyEntity({
    required this.eventsAttended,
    required this.issuesHelped,
    required this.bloodDonations,
    required this.treesPlanted,
    required this.sportsMatchesPlayed,
    required this.volunteerHours,
  });

  @override
  List<Object?> get props => [
        eventsAttended,
        issuesHelped,
        bloodDonations,
        treesPlanted,
        sportsMatchesPlayed,
        volunteerHours,
      ];
}
