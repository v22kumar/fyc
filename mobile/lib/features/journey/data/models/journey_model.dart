import '../../domain/entities/journey_entity.dart';

class JourneyModel extends JourneyEntity {
  const JourneyModel({
    required super.eventsAttended,
    required super.issuesHelped,
    required super.bloodDonations,
    required super.treesPlanted,
    required super.sportsMatchesPlayed,
    required super.volunteerHours,
  });

  factory JourneyModel.fromJson(Map<String, dynamic> json) {
    return JourneyModel(
      eventsAttended: json['events_attended'] as int? ?? 0,
      issuesHelped: json['issues_helped'] as int? ?? 0,
      bloodDonations: json['blood_donations'] as int? ?? 0,
      treesPlanted: json['trees_planted'] as int? ?? 0,
      sportsMatchesPlayed: json['sports_matches_played'] as int? ?? 0,
      volunteerHours: (json['volunteer_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
