import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/challenge_entity.dart';
import '../repositories/sports_repository.dart';

class SubmitChallengeUseCase {
  final SportsRepository repository;
  SubmitChallengeUseCase(this.repository);

  Future<Either<Failure, ChallengeEntity>> call({
    required String challengerTeamName,
    required String challengerCaptain,
    required String challengerPhone,
    required String sport,
    DateTime? proposedDate,
    String? venue,
    String? message,
  }) =>
      repository.submitChallenge(
        challengerTeamName: challengerTeamName,
        challengerCaptain: challengerCaptain,
        challengerPhone: challengerPhone,
        sport: sport,
        proposedDate: proposedDate,
        venue: venue,
        message: message,
      );
}
