import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/opportunity_entity.dart';
import '../../domain/repositories/opportunity_repository.dart';
import '../datasources/opportunity_datasource.dart';

class OpportunityRepositoryImpl implements OpportunityRepository {
  final OpportunityDataSource _remote;
  OpportunityRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<OpportunityEntity>>> fetchOpportunities() async {
    try {
      final opportunities = await _remote.fetchOpportunities();
      return Right(opportunities);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> applyForOpportunity(String id) async {
    try {
      await _remote.applyForOpportunity(id);
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
