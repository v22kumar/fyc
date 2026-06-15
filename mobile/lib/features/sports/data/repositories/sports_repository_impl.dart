import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/tournament_entity.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/team_entity.dart';
import '../../domain/entities/challenge_entity.dart';
import '../../domain/repositories/sports_repository.dart';
import '../datasources/sports_datasource.dart';

class SportsRepositoryImpl implements SportsRepository {
  final SportsDataSource _remote;
  SportsRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<TournamentEntity>>> fetchTournaments({
    String? sport,
  }) async {
    try {
      final tournaments = await _remote.fetchTournaments(sport: sport);
      return Right(tournaments);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FixtureEntity>>> fetchFixtures(
    String tournamentId,
  ) async {
    try {
      final fixtures = await _remote.fetchFixtures(tournamentId);
      return Right(fixtures);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TeamEntity>>> fetchStandings(
    String tournamentId,
  ) async {
    try {
      final standings = await _remote.fetchStandings(tournamentId);
      return Right(standings);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChallengeEntity>> submitChallenge({
    required String challengerTeamName,
    required String challengerCaptain,
    required String challengerPhone,
    required String sport,
    DateTime? proposedDate,
    String? venue,
    String? message,
  }) async {
    try {
      final challenge = await _remote.submitChallenge(
        challengerTeamName: challengerTeamName,
        challengerCaptain: challengerCaptain,
        challengerPhone: challengerPhone,
        sport: sport,
        proposedDate: proposedDate,
        venue: venue,
        message: message,
      );
      return Right(challenge);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
