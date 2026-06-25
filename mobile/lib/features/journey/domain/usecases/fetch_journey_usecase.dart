import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/journey_entity.dart';
import '../repositories/journey_repository.dart';

class FetchJourneyUseCase {
  final JourneyRepository repository;
  FetchJourneyUseCase(this.repository);

  Future<Either<Failure, JourneyEntity>> call() {
    return repository.fetchJourney();
  }
}
