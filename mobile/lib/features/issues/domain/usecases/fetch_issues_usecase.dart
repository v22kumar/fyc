import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/issue_entity.dart';
import '../repositories/issue_list_repository.dart';

class FetchIssuesUseCase {
  final IssueListRepository repository;
  FetchIssuesUseCase(this.repository);

  Future<Either<Failure, List<IssueEntity>>> call({
    String? status,
    String? category,
  }) {
    return repository.fetchIssues(status: status, category: category);
  }
}
