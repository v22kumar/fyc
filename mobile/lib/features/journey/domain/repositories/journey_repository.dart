import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/journey_entity.dart';

abstract class JourneyRepository {
  Future<Either<Failure, JourneyEntity>> fetchJourney();
}
