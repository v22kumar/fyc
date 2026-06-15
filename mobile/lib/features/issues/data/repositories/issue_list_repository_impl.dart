import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/issue_entity.dart';
import '../../domain/repositories/issue_list_repository.dart';
import '../datasources/issue_list_datasource.dart';

class IssueListRepositoryImpl implements IssueListRepository {
  final IssueListDataSource _remote;
  IssueListRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<IssueEntity>>> fetchIssues({
    String? status,
    String? category,
  }) async {
    try {
      final issues = await _remote.fetchIssues(status: status, category: category);
      return Right(issues);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, IssueEntity>> getIssue(String id) async {
    try {
      final issue = await _remote.getIssue(id);
      return Right(issue);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
