import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/opportunity_entity.dart';

abstract class OpportunityRepository {
  Future<Either<Failure, List<OpportunityEntity>>> fetchOpportunities();
  Future<Either<Failure, void>> applyForOpportunity(String id);
}
