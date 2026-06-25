import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/issue_list_repository.dart';

class LogEmailSentUseCase {
  final IssueListRepository repository;
  LogEmailSentUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.logEmailSent(id);
  }
}
