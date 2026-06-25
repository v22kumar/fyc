import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/issue_entity.dart';
import '../repositories/issue_list_repository.dart';

class MarkIssueResolvedUseCase {
  final IssueListRepository repository;
  MarkIssueResolvedUseCase(this.repository);

  Future<Either<Failure, IssueEntity>> call(String id) {
    return repository.markIssueResolved(id);
  }
}
