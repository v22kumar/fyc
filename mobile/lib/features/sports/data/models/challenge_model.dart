import '../../domain/entities/challenge_entity.dart';

class ChallengeModel extends ChallengeEntity {
  const ChallengeModel({
    required super.id,
    required super.challengerTeamName,
    required super.challengerCaptain,
    required super.challengerPhone,
    required super.sport,
    super.proposedDate,
    super.venue,
    super.message,
    required super.status,
    super.adminResponse,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as String,
      challengerTeamName: (json['challenger_team_name'] as String?) ?? '',
      challengerCaptain: (json['challenger_captain'] as String?) ?? '',
      challengerPhone: (json['challenger_phone'] as String?) ?? '',
      sport: (json['sport'] as String?) ?? '',
      proposedDate: json['proposed_date'] != null
          ? DateTime.parse(json['proposed_date'] as String)
          : null,
      venue: json['venue'] as String?,
      message: json['message'] as String?,
      status: (json['status'] as String?) ?? '',
      adminResponse: json['admin_response'] as String?,
    );
  }
}
