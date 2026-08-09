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
    bool isEmergency = false,
  });

  /// Uploads the report photo and returns its URL.
  Future<String?> uploadPhoto(List<int> bytes, {String filename = 'issue.jpg'});

  /// The v2 civic report: category, severity, words in their own language.
  /// Returns the created complaint id (null if the server sent no body).
  Future<String?> submitCivicReport(Map<String, dynamic> data);
}
