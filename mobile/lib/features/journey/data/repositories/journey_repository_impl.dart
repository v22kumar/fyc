import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/journey_entity.dart';
import '../../domain/repositories/journey_repository.dart';
import '../datasources/journey_datasource.dart';

class JourneyRepositoryImpl implements JourneyRepository {
  final JourneyDataSource _remote;
  JourneyRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, JourneyEntity>> fetchJourney() async {
    try {
      final journey = await _remote.fetchJourney();
      return Right(journey);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
