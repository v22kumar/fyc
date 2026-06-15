import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../entities/fixture_entity.dart';
import '../entities/team_entity.dart';
import '../entities/challenge_entity.dart';

abstract class SportsRepository {
  Future<Either<Failure, List<TournamentEntity>>> fetchTournaments({
    String? sport,
  });
  Future<Either<Failure, List<FixtureEntity>>> fetchFixtures(
    String tournamentId,
  );
  Future<Either<Failure, List<TeamEntity>>> fetchStandings(
    String tournamentId,
  );
  Future<Either<Failure, ChallengeEntity>> submitChallenge({
    required String challengerTeamName,
    required String challengerCaptain,
    required String challengerPhone,
    required String sport,
    DateTime? proposedDate,
    String? venue,
    String? message,
  });
}
