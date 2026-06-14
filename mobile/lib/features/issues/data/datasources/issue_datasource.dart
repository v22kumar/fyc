import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/issue_model.dart';

abstract class IssueDataSource {
  Future<IssueModel> submitIssue({
    required String category,
    required String descriptionTa,
    required String descriptionEn,
    required double latitude,
    required double longitude,
    String? photoUrl,
  });
}

class IssueDataSourceImpl implements IssueDataSource {
  final ApiClient _client;
  IssueDataSourceImpl(this._client);

  @override
  Future<IssueModel> submitIssue({
    required String category,
    required String descriptionTa,
    required String descriptionEn,
    required double latitude,
    required double longitude,
    String? photoUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category,
        'description_ta': descriptionTa,
        'description_en': descriptionEn,
        'latitude': latitude,
        'longitude': longitude,
      };
      if (photoUrl != null) body['photo_url'] = photoUrl;
      final response = await _client.dio.post(
        ApiConstants.issues,
        data: body,
      );
      return IssueModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Failure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError) return const NetworkFailure();
    final detail = (e.response?.data as Map?)?['detail'] as String? ?? 'Error';
    if (e.response?.statusCode == 401) return AuthFailure(detail);
    return ServerFailure(detail);
  }
}
