import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/opportunity_repository.dart';

class ApplyOpportunityUseCase {
  final OpportunityRepository repository;
  ApplyOpportunityUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) =>
      repository.applyForOpportunity(id);
}
