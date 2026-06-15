import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/public_issue_entity.dart';

abstract class IssueRepository {
  Future<Either<Failure, PublicIssueEntity>> submitIssue({
    required String category,
    required String descriptionTa,
    required String descriptionEn,
    required double latitude,
    required double longitude,
    String? photoUrl,
  });
}
