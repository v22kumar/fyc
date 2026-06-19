import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/opportunity_entity.dart';
import '../repositories/opportunity_repository.dart';

class FetchOpportunitiesUseCase {
  final OpportunityRepository repository;
  FetchOpportunitiesUseCase(this.repository);

  Future<Either<Failure, List<OpportunityEntity>>> call() =>
      repository.fetchOpportunities();
}
