import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../entities/fixture_entity.dart';
import '../entities/team_entity.dart';
import '../entities/challenge_entity.dart';
import '../entities/player_entity.dart';
import '../entities/cricket_match_state_entity.dart';

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
  Future<Either<Failure, List<PlayerEntity>>> fetchTeamPlayers(String teamId);
  Future<Either<Failure, PlayerEntity>> registerPlayer(String teamId, Map<String, dynamic> data);
  Future<Either<Failure, CricketMatchStateEntity>> fetchCricketMatchState(String fixtureId);
  Future<Either<Failure, CricketMatchStateEntity>> scoreCricketBall(String fixtureId, Map<String, dynamic> data);
  Future<Either<Failure, CricketMatchStateEntity>> undoCricketBall(String fixtureId);
}
