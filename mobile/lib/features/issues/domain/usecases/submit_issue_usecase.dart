import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/public_issue_entity.dart';
import '../repositories/issue_repository.dart';

class SubmitIssueUseCase {
  final IssueRepository repository;
  SubmitIssueUseCase(this.repository);

  Future<Either<Failure, PublicIssueEntity>> call({
    required String category,
    required String descriptionTa,
    required String descriptionEn,
    required double latitude,
    required double longitude,
    String? photoUrl,
    bool isEmergency = false,
  }) {
    if (descriptionTa.trim().isEmpty && descriptionEn.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Please provide a description')),
      );
    }
    return repository.submitIssue(
      category: category,
      descriptionTa: descriptionTa.trim(),
      descriptionEn: descriptionEn.trim(),
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
      isEmergency: isEmergency,
    );
  }
}
