import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/issue_entity.dart';

abstract class IssueListRepository {
  Future<Either<Failure, List<IssueEntity>>> fetchIssues({
    String? status,
    String? category,
  });
  Future<Either<Failure, IssueEntity>> getIssue(String id);
  Future<Either<Failure, IssueEntity>> markIssueResolved(String id);
  Future<Either<Failure, void>> logEmailSent(String id);
}
