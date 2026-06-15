import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../repositories/sports_repository.dart';

class FetchTournamentsUseCase {
  final SportsRepository repository;
  FetchTournamentsUseCase(this.repository);

  Future<Either<Failure, List<TournamentEntity>>> call({String? sport}) =>
      repository.fetchTournaments(sport: sport);
}
