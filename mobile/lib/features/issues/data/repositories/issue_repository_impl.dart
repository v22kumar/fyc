import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/public_issue_entity.dart';
import '../../domain/repositories/issue_repository.dart';
import '../datasources/issue_datasource.dart';

class IssueRepositoryImpl implements IssueRepository {
  final IssueDataSource _remote;
  IssueRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, PublicIssueEntity>> submitIssue({
    required String category,
    required String descriptionTa,
    required String descriptionEn,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final issue = await _remote.submitIssue(
        category: category,
        descriptionTa: descriptionTa,
        descriptionEn: descriptionEn,
        latitude: latitude,
        longitude: longitude,
      );
      return Right(issue);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
